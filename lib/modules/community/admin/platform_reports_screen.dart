import 'package:flutter/material.dart';

import '../../../widgets/gubify_swipe_back.dart';
import 'platform_admin_service.dart';
import 'platform_moderation_model.dart';
import 'platform_moderation_service.dart';

class PlatformReportsScreen extends StatefulWidget {
  const PlatformReportsScreen({super.key, required this.role, this.service});

  final PlatformAdminService role;
  final PlatformModerationService? service;

  @override
  State<PlatformReportsScreen> createState() => _PlatformReportsScreenState();
}

class _PlatformReportsScreenState extends State<PlatformReportsScreen> {
  late final PlatformModerationService service =
      widget.service ?? PlatformModerationService(role: widget.role);

  int _limit = 100;
  String _filter = 'all';
  final _busy = <String>{};
  late Stream<List<PlatformReportItem>> _reports = service.reports(_limit);

  static const _labels = <String, String>{
    'all': 'All',
    'open': 'Open',
    'reviewed': 'Reviewed',
    'action_taken': 'Action taken',
    'escalated': 'Escalated',
    'closed': 'Closed',
  };

  String _label(String value) => _labels[value] ?? value;

  Future<void> _changeStatus(PlatformReportItem report) async {
    if (_busy.contains(report.id)) return;
    final result = await showDialog<_StatusUpdate>(
      context: context,
      builder: (_) => _ReportStatusDialog(
        currentStatus: report.status,
        currentActionNote: report.actionNote,
        statusLabel: _label,
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _busy.add(report.id));
    try {
      await service.updateReportStatus(
        reportId: report.id,
        status: result.status,
        actionNote: result.actionNote,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report updated.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update report.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(report.id));
    }
  }

  void _showHistory(PlatformReportItem report) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Moderation history'),
        content: SizedBox(
          width: 420,
          height: 340,
          child: StreamBuilder<List<PlatformReportEvent>>(
            stream: service.reportEvents(report.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Unable to read the audit history.');
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.isEmpty) {
                return const Text('No recorded transitions. Older decisions may predate the audit log.');
              }
              return ListView(
                children: [
                  for (final event in snapshot.data!)
                    ListTile(
                      isThreeLine: true,
                      title: Text('${_label(event.previousStatus)} → ${_label(event.status)}'),
                      subtitle: Text(
                        'By ${event.actorId} · ${event.createdAt?.toDate().toLocal().toString() ?? 'Pending'}'
                        '\n${event.actionNote}',
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => GubifySwipeBack(
    child: Scaffold(
      appBar: AppBar(title: const Text('Reports inbox')),
      body: StreamBuilder<List<PlatformReportItem>>(
        stream: _reports,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load reports.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final reports = snapshot.data!;
          final visible = _filter == 'all'
              ? reports
              : reports.where((item) => item.status == _filter).toList();
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _filter,
                decoration: const InputDecoration(
                  labelText: 'Filter',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final entry in _labels.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _filter = value);
                },
              ),
              const SizedBox(height: 12),
              if (visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('No reports in this view.')),
                ),
              for (final report in visible)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (report.isCritical)
                          const Text(
                            'HIGH PRIORITY · CHILD SAFETY',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        if (report.isCritical) const SizedBox(height: 8),
                        Text(
                          report.reasonLabel,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text('${report.sourceKind}: ${report.sourceName}'),
                        Text(
                          'Target: ${report.targetName ?? report.targetId} · ${report.targetType}',
                        ),
                        Text('Status: ${_label(report.status)}'),
                        if (report.contentSnapshot?.trim().isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Reported content snapshot',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(report.contentSnapshot!),
                        ],
                        if (report.details.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Reporter details',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(report.details),
                        ],
                        if (report.actionNote.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Admin action note',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(report.actionNote),
                        ],
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _showHistory(report),
                            icon: const Icon(Icons.history),
                            label: const Text('History'),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.tonalIcon(
                            onPressed: _busy.contains(report.id)
                                ? null
                                : () => _changeStatus(report),
                            icon: const Icon(Icons.fact_check_outlined),
                            label: Text(
                              _busy.contains(report.id)
                                  ? 'Updating…'
                                  : 'Update status',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (reports.length == _limit)
                TextButton(
                  onPressed: () => setState(() {
                    _limit += 100;
                    _reports = service.reports(_limit);
                  }),
                  child: const Text('Load more'),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _ReportStatusDialog extends StatefulWidget {
  const _ReportStatusDialog({
    required this.currentStatus,
    required this.currentActionNote,
    required this.statusLabel,
  });

  final String currentStatus;
  final String currentActionNote;
  final String Function(String) statusLabel;

  @override
  State<_ReportStatusDialog> createState() => _ReportStatusDialogState();
}

class _ReportStatusDialogState extends State<_ReportStatusDialog> {
  late String _status;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _status = PlatformModerationService.reportStatuses.contains(
      widget.currentStatus,
    )
        ? widget.currentStatus
        : 'open';
    _note = TextEditingController(text: widget.currentActionNote);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Update report'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: [
              for (final item in PlatformModerationService.reportStatuses)
                DropdownMenuItem(
                  value: item,
                  child: Text(widget.statusLabel(item)),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _status = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLength: 500,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Action note (optional)',
            ),
          ),
          if (_status == 'escalated')
            const Text(
              'Escalated is an internal tracking status. No external report is sent automatically.',
              style: TextStyle(fontSize: 12),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _status == widget.currentStatus
            ? null
            : () => Navigator.pop(
                context,
                _StatusUpdate(
                  status: _status,
                  actionNote: _note.text,
                ),
              ),
        child: const Text('Save'),
      ),
    ],
  );
}

class _StatusUpdate {
  const _StatusUpdate({required this.status, required this.actionNote});

  final String status;
  final String actionNote;
}
