import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../widgets/gub_screen_background.dart';
import '../../../widgets/delete_item_dialog.dart';
import '../../../core/models/deletion_context.dart';
import '../../chat/widgets/gub_chat_overlay.dart';
import '../models/gub_event_model.dart';
import '../services/gub_event_service.dart';

class GubEventDetailsScreen extends StatefulWidget {
  final String gubId;
  final String eventId;

  const GubEventDetailsScreen({
    super.key,
    required this.gubId,
    required this.eventId,
  });

  @override
  State<GubEventDetailsScreen> createState() => _GubEventDetailsScreenState();
}

class _GubEventDetailsScreenState extends State<GubEventDetailsScreen> {
  bool _openingOriginalMessage = false;
  late final Future<DeletionContext> _deletionContextFuture;

  @override
  void initState() {
    super.initState();
    _deletionContextFuture = GubEventService.instance.deletionContext(
      gubId: widget.gubId,
      eventId: widget.eventId,
    );
  }

  Future<void> _deleteEvent() async {
    final deletionContext = await _deletionContextFuture;
    if (!mounted || !deletionContext.canDelete) return;
    final deleted = await showDeleteItemDialog(
      context: context,
      title: 'Delete event?',
      moduleName: 'event',
      deletionContext: deletionContext,
      successMessage: 'Event deleted.',
      onDelete: () => GubEventService.instance.delete(
        gubId: widget.gubId,
        eventId: widget.eventId,
      ),
    );
    if (deleted && mounted) Navigator.pop(context);
  }

  Future<void> _openOriginalMessage(GubEventModel event) async {
    final messageId = event.sourceId;
    if (_openingOriginalMessage || messageId == null || messageId.isEmpty) {
      return;
    }

    setState(() => _openingOriginalMessage = true);
    final opened = await GubChatOverlay.openChat(
      gubId: event.gubId,
      initialMessageId: messageId,
    );
    if (!mounted) return;
    setState(() => _openingOriginalMessage = false);

    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open the original message.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => GubScreenBackground(
    variant: GubBackgroundAssignments.events,
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Event'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          FutureBuilder<DeletionContext>(
            future: _deletionContextFuture,
            builder: (context, snapshot) => snapshot.data?.canDelete == true
                ? IconButton(
                    tooltip: 'Delete event',
                    onPressed: _deleteEvent,
                    icon: const Icon(Icons.delete_outline_rounded),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<GubEventModel?>(
          stream: GubEventService.instance.eventStream(
            widget.gubId,
            widget.eventId,
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Unable to load this event.'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final event = snapshot.data;
            if (event == null) {
              return const Center(
                child: Text('This event is no longer available.'),
              );
            }

            final uid = FirebaseAuth.instance.currentUser?.uid;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 128),
              children: [
                _EventSummaryCard(
                  event: event,
                  openingOriginalMessage: _openingOriginalMessage,
                  onOpenOriginalMessage: event.sourceId?.isNotEmpty == true
                      ? () => _openOriginalMessage(event)
                      : null,
                ),
                const SizedBox(height: 18),
                const _TasksHeader(),
                const SizedBox(height: 10),
                ...event.assignments.map(
                  (assignment) => _AssignmentCard(
                    assignment: assignment,
                    isCurrentUser: assignment.userId == uid,
                    eventIsActive: event.status == 'active',
                    onComplete: () => GubEventService.instance.setOwnCompletion(
                      event: event,
                      completed: true,
                    ),
                    onUndo: () => GubEventService.instance.setOwnCompletion(
                      event: event,
                      completed: false,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _EventSummaryCard extends StatelessWidget {
  final GubEventModel event;
  final bool openingOriginalMessage;
  final VoidCallback? onOpenOriginalMessage;

  const _EventSummaryCard({
    required this.event,
    required this.openingOriginalMessage,
    this.onOpenOriginalMessage,
  });

  @override
  Widget build(BuildContext context) {
    final completed = event.status == 'completed';
    final statusColor = completed
        ? const Color(0xFF16A34A)
        : const Color(0xFF2563EB);
    final progress = event.assignments.isEmpty
        ? 0.0
        : event.completedCount / event.assignments.length;
    final percentage = (progress * 100).round();
    final scheduledAt = event.scheduledAt?.toDate();

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.event_available_rounded,
                    color: Color(0xFF15803D),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    event.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    completed ? 'Completed' : 'Active',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (event.description?.isNotEmpty == true) ...[
              const SizedBox(height: 16),
              Text(event.description!, style: const TextStyle(height: 1.45)),
            ],
            if (event.location?.isNotEmpty == true) ...[
              const SizedBox(height: 14),
              _InfoRow(icon: Icons.location_on_outlined, text: event.location!),
            ],
            if (scheduledAt != null) ...[
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.schedule_rounded,
                text:
                    '${MaterialLocalizations.of(context).formatMediumDate(scheduledAt)} · '
                    '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(scheduledAt))}',
              ),
            ],
            if (event.sourceType == 'chat' &&
                event.sourcePreview?.isNotEmpty == true) ...[
              const SizedBox(height: 18),
              _EventChatSourceCard(
                message: event.sourcePreview!,
                authorName: event.sourceAuthorName,
                opening: openingOriginalMessage,
                onTap: onOpenOriginalMessage,
              ),
            ],
            const SizedBox(height: 20),
            Text(
              '${event.completedCount} / ${event.assignments.length} completed · $percentage%',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: const Color(0xFFE2E8F0),
                color: statusColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TasksHeader extends StatelessWidget {
  const _TasksHeader();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.05),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.groups_2_outlined, color: Color(0xFF2563EB)),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Event tasks',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Complete every assignment to finish the event',
                style: TextStyle(color: Color(0xFF475569), height: 1.3),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AssignmentCard extends StatelessWidget {
  final GubEventAssignment assignment;
  final bool isCurrentUser;
  final bool eventIsActive;
  final VoidCallback onComplete;
  final VoidCallback onUndo;

  const _AssignmentCard({
    required this.assignment,
    required this.isCurrentUser,
    required this.eventIsActive,
    required this.onComplete,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    elevation: 0.5,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFDBEAFE),
                child: Text(
                  _initial(assignment.userName),
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  assignment.userName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color:
                      (assignment.isCompleted
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF64748B))
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      assignment.isCompleted
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 16,
                      color: assignment.isCompleted
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      assignment.isCompleted ? 'Completed' : 'Pending',
                      style: TextStyle(
                        color: assignment.isCompleted
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(assignment.taskText, style: const TextStyle(height: 1.4)),
          if (isCurrentUser && eventIsActive) ...[
            const SizedBox(height: 14),
            if (assignment.isCompleted)
              OutlinedButton.icon(
                onPressed: onUndo,
                icon: const Icon(Icons.undo_rounded),
                label: const Text('Undo completion'),
              )
            else
              FilledButton.icon(
                onPressed: onComplete,
                icon: const Icon(Icons.check_rounded),
                label: const Text("I've done my task"),
              ),
          ],
        ],
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: const Color(0xFF64748B)),
      const SizedBox(width: 9),
      Expanded(child: Text(text)),
    ],
  );
}

class _EventChatSourceCard extends StatelessWidget {
  final String message;
  final String? authorName;
  final bool opening;
  final VoidCallback? onTap;

  const _EventChatSourceCard({
    required this.message,
    required this.opening,
    this.authorName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFBFDBFE)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text(
              'From chat',
              style: TextStyle(
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (authorName?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(
            authorName!.trim(),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 8),
        Text('“$message”', maxLines: 4, overflow: TextOverflow.ellipsis),
        if (onTap != null) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: opening ? null : onTap,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(
                opening ? 'Opening chat...' : 'View original message',
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

String _initial(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
}
