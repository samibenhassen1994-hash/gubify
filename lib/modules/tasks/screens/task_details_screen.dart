import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../widgets/gub_screen_background.dart';
import '../../chat/widgets/gub_chat_overlay.dart';
import '../models/task_model.dart';
import '../services/task_service.dart';
import '../widgets/task_status_chip.dart';

class TaskDetailsScreen extends StatefulWidget {
  final String gubId;
  final String taskId;

  const TaskDetailsScreen({
    super.key,
    required this.gubId,
    required this.taskId,
  });

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  bool _loading = false;
  bool _openingOriginalMessage = false;

  Future<void> _openOriginalMessage(TaskModel task) async {
    final messageId = task.sourceId;
    if (_openingOriginalMessage || messageId == null || messageId.isEmpty) {
      return;
    }

    setState(() => _openingOriginalMessage = true);

    final opened = await GubChatOverlay.openChat(
      gubId: task.gubId,
      initialMessageId: messageId,
    );

    if (!mounted) return;

    setState(() => _openingOriginalMessage = false);

    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to open the original message.")),
      );
    }
  }

  Future<void> _completeTask(TaskModel task) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    setState(() {
      _loading = true;
    });

    try {
      await TaskService.instance.completeTask(
        task: task,
        completedBy: user.uid,
      );

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  bool _canComplete(TaskModel task) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return false;

    if (task.status != "active") {
      return false;
    }

    return task.assignedUserId == null ||
        task.assignedUserId!.isEmpty ||
        task.assignedUserId == uid;
  }

  @override
  Widget build(BuildContext context) {
    return GubScreenBackground(
      variant: GubBackgroundAssignments.tasks,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Task Details"),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),

        body: StreamBuilder<TaskModel?>(
          stream: TaskService.instance.taskStream(
            gubId: widget.gubId,
            taskId: widget.taskId,
          ),

          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final task = snapshot.data;

            if (task == null) {
              return const Center(child: Text("Task not found"));
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  task.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),

                const SizedBox(height: 16),

                if (task.description.isNotEmpty) ...[
                  Text(
                    task.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),

                  const SizedBox(height: 20),
                ],

                if (task.sourceType == "chat" &&
                    task.sourcePreview?.isNotEmpty == true) ...[
                  _ChatSourceCard(
                    message: task.sourcePreview!,
                    authorName: task.sourceAuthorName,
                    onTap: task.sourceId != null && task.sourceId!.isNotEmpty
                        ? () => _openOriginalMessage(task)
                        : null,
                    opening: _openingOriginalMessage,
                  ),
                  const SizedBox(height: 20),
                ],

                if (task.additionalDetails?.trim().isNotEmpty == true) ...[
                  Text(
                    "Additional details",
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF2563EB),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(task.additionalDetails!.trim()),
                  const SizedBox(height: 20),
                ],

                TaskStatusChip(status: task.status),

                const SizedBox(height: 20),

                _InfoRow(title: "Created by", value: task.creatorName),

                const SizedBox(height: 12),

                _InfoRow(
                  title: "Assigned to",
                  value: task.assignedUserName ?? "Nobody",
                ),

                const SizedBox(height: 12),

                _InfoRow(title: "Priority", value: task.priority),

                const SizedBox(height: 12),

                if (task.dueDate != null)
                  _InfoRow(
                    title: "Due date",
                    value: _formatDate(task.dueDate!),
                  ),

                const SizedBox(height: 32),

                if (_canComplete(task))
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loading
                          ? null
                          : () {
                              _completeTask(task);
                            },
                      icon: const Icon(Icons.task_alt),
                      label: Text(
                        _loading ? "Completing..." : "I've completed it",
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    final date = timestamp.toDate();

    return "${date.day}/${date.month}/${date.year}";
  }
}

class _ChatSourceCard extends StatelessWidget {
  final String message;
  final String? authorName;
  final VoidCallback? onTap;
  final bool opening;

  const _ChatSourceCard({
    required this.message,
    this.authorName,
    this.onTap,
    required this.opening,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF2563EB)),
      ),
      child: InkWell(
        onTap: opening ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Color(0xFF2563EB),
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Created from chat",
                    style: TextStyle(
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (authorName != null && authorName!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  authorName!,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF2563EB),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                "“$message”",
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
              if (onTap != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      opening ? "Opening chat..." : "View original message",
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.open_in_new,
                      size: 17,
                      color: Color(0xFF2563EB),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String title;
  final String value;

  const _InfoRow({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),

        Flexible(child: Text(value, textAlign: TextAlign.right)),
      ],
    );
  }
}
