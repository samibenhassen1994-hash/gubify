import 'package:flutter/material.dart';

import '../models/community_report_model.dart';

typedef CommunityReportSubmit =
    Future<void> Function(String reason, String details);

Future<void> showCommunityReportDialog({
  required BuildContext context,
  required String title,
  required CommunityReportSubmit onSubmit,
}) async {
  final submitted = await showDialog<bool>(
    context: context,
    builder: (_) => CommunityReportDialog(title: title, onSubmit: onSubmit),
  );
  if (!context.mounted || submitted != true) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Report submitted')));
}

class CommunityReportDialog extends StatefulWidget {
  final String title;
  final CommunityReportSubmit onSubmit;

  const CommunityReportDialog({
    super.key,
    required this.title,
    required this.onSubmit,
  });

  @override
  State<CommunityReportDialog> createState() => _CommunityReportDialogState();
}

class _CommunityReportDialogState extends State<CommunityReportDialog> {
  final _detailsController = TextEditingController();
  String? _reason;
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    if (_submitting) return;
    if (_reason == null) {
      setState(() => _error = 'Select a reason.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_reason!, _detailsController.text);
      if (mounted) Navigator.pop(context, true);
    } on CommunityReportAlreadyExistsException {
      if (mounted) setState(() => _error = "You've already reported this.");
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to submit the report. Try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _reason,
              decoration: const InputDecoration(labelText: 'Reason'),
              items: [
                for (final reason in CommunityReportReason.values)
                  DropdownMenuItem(
                    value: reason.value,
                    child: Text(reason.label),
                  ),
              ],
              onChanged: _submitting
                  ? null
                  : (value) => setState(() {
                      _reason = value;
                      _error = null;
                    }),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _detailsController,
              enabled: !_submitting,
              maxLength: CommunityModerationReport.maxDetailsLength,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Additional details (optional)',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit report'),
        ),
      ],
    );
  }
}
