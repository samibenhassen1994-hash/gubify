import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'platform_moderation_model.dart';
import 'platform_moderation_service.dart';

/// Records a notification ALREADY sent externally by a human administrator.
/// It cannot notify police, NCMEC or other authorities.
class AuthorityReportingDialog extends StatefulWidget {
  const AuthorityReportingDialog({
    super.key,
    required this.report,
    required this.service,
  });

  final PlatformReportItem report;
  final PlatformModerationService service;

  @override
  State<AuthorityReportingDialog> createState() => _AuthorityReportingDialogState();
}

class _AuthorityReportingDialogState extends State<AuthorityReportingDialog> {
  String _channel = 'italian_police';
  final _authority = TextEditingController(text: 'Polizia Postale');
  final _reference = TextEditingController();
  final _note = TextEditingController();
  bool _completedExternally = false;
  bool _busy = false;

  static const channels = <String, String>{
    'italian_police': 'Italian Police (Polizia Postale)',
    'ncmec': 'NCMEC CyberTipline',
    'other_competent_authority': 'Other competent authority',
  };

  @override
  void dispose() {
    _authority.dispose();
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  void _chooseChannel(String? value) {
    if (value == null) return;
    setState(() {
      _channel = value;
      _authority.text = switch (value) {
        'italian_police' => 'Polizia Postale',
        'ncmec' => 'NCMEC',
        _ => '',
      };
      _completedExternally = false;
    });
  }

  Future<void> _openOfficialChannel() async {
    final url = switch (_channel) {
      'italian_police' => 'https://www.commissariatodips.it/',
      'ncmec' => 'https://report.cybertip.org/',
      _ => null,
    };
    if (url == null) return;
    try {
      final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open the official site.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open the official site.')),
        );
      }
    }
  }

  Future<void> _record() async {
    if (_busy || !_completedExternally || _authority.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.service.recordAuthorityReferral(
        report: widget.report,
        channel: _channel,
        authorityName: _authority.text,
        reference: _reference.text,
        note: _note.text,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to record the referral.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Authority reporting'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'If a child is in immediate danger, call emergency services. '
              'Gubify does not send reports to authorities from this screen.',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _channel,
              decoration: const InputDecoration(labelText: 'Reporting channel'),
              items: [
                for (final entry in channels.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: _busy ? null : _chooseChannel,
            ),
            if (_channel != 'other_competent_authority')
              TextButton.icon(
                onPressed: _openOfficialChannel,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open official website'),
              ),
            TextField(
              controller: _authority,
              maxLength: 100,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Authority contacted'),
            ),
            TextField(
              controller: _reference,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Reference number (if provided)',
              ),
            ),
            TextField(
              controller: _note,
              maxLength: 300,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Administrative note (never include illegal material)',
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'I already submitted this report through the official channel.',
              ),
              value: _completedExternally,
              onChanged: _busy ? null : (v) => setState(() => _completedExternally = v == true),
            ),
            const Divider(),
            const Text('Recorded referrals', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(
              height: 110,
              child: StreamBuilder<List<PlatformAuthorityReferral>>(
                stream: widget.service.authorityReferrals(widget.report.id),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const Text('Unable to load history.');
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.data!.isEmpty) return const Text('No referrals recorded.');
                  return ListView(
                    children: [
                      for (final item in snapshot.data!)
                        ListTile(
                          dense: true,
                          title: Text(item.authorityName),
                          subtitle: Text(
                            '${item.recordedAt?.toDate().toLocal().toString() ?? 'Pending'} '
                            '· ${item.reference.isEmpty ? 'No reference provided' : item.reference}',
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      FilledButton(
        onPressed: _busy || !_completedExternally || _authority.text.trim().isEmpty
            ? null : _record,
        child: const Text('Record completed referral'),
      ),
    ],
  );
}
