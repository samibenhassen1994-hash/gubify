import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/task_model.dart';
import 'task_assignee_tile.dart';
import 'task_status_chip.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final String currentUserId;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;

  const TaskCard({
    super.key,
    required this.task,
    required this.currentUserId,
    this.onTap,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final bool canComplete =
        task.status == "active" &&
        (
          task.assignedUserId == null ||
          task.assignedUserId!.isEmpty ||
          task.assignedUserId == currentUserId
        );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Title
              Text(
                task.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),

              if (task.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  task.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],

              const SizedBox(height: 12),

              TaskAssigneeTile(
                assignedUserName: task.assignedUserName,
              ),

              if (task.dueDate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(task.dueDate!),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  TaskStatusChip(
                    status: task.status,
                  ),
                  Text(
                    task.sourceType.toUpperCase(),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall,
                  ),
                ],
              ),

              if (canComplete) ...[
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(Icons.task_alt),
                    label: const Text(
                      "I've completed it",
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();

    return "${date.day}/${date.month}/${date.year}";
  }
}