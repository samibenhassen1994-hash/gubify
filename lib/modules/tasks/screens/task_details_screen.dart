import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/task_model.dart';
import '../services/task_service.dart';
import '../widgets/task_status_chip.dart';

class TaskDetailsScreen extends StatefulWidget {
  final String hubId;
  final String taskId;

  const TaskDetailsScreen({
    super.key,
    required this.hubId,
    required this.taskId,
  });

  @override
  State<TaskDetailsScreen> createState() =>
      _TaskDetailsScreenState();
}

class _TaskDetailsScreenState
    extends State<TaskDetailsScreen> {

  bool _loading = false;

  Future<void> _completeTask(
    TaskModel task,
  ) async {

    final user =
        FirebaseAuth.instance.currentUser;

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

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
          ),
        ),
      );

    } finally {

      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  bool _canComplete(TaskModel task) {

    final uid =
        FirebaseAuth.instance.currentUser?.uid;

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

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Task Details",
        ),
      ),

      body: StreamBuilder<TaskModel?>(
        stream: TaskService.instance.taskStream(
          hubId: widget.hubId,
          taskId: widget.taskId,
        ),

        builder: (context, snapshot) {

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final task = snapshot.data;

          if (task == null) {
            return const Center(
              child: Text(
                "Task not found",
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [                 Text(
                  task.title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall,
                ),

                const SizedBox(height: 16),

                if (task.description.isNotEmpty) ...[
                  Text(
                    task.description,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge,
                  ),

                  const SizedBox(height: 20),
                ],


                TaskStatusChip(
                  status: task.status,
                ),


                const SizedBox(height: 20),


                _InfoRow(
                  title: "Created by",
                  value: task.creatorName,
                ),


                const SizedBox(height: 12),


                _InfoRow(
                  title: "Assigned to",
                  value:
                      task.assignedUserName ??
                      "Nobody",
                ),


                const SizedBox(height: 12),


                _InfoRow(
                  title: "Priority",
                  value: task.priority,
                ),


                const SizedBox(height: 12),


                if (task.dueDate != null)
                  _InfoRow(
                    title: "Due date",
                    value: _formatDate(
                      task.dueDate!,
                    ),
                  ),


                const Spacer(),


                if (_canComplete(task))
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loading
                          ? null
                          : () {
                              _completeTask(task);
                            },
                      icon: const Icon(
                        Icons.task_alt,
                      ),
                      label: Text(
                        _loading
                            ? "Completing..."
                            : "I've completed it",
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }


  String _formatDate(
    dynamic timestamp,
  ) {
    final date =
        timestamp.toDate();

    return "${date.day}/${date.month}/${date.year}";
  }
}


class _InfoRow extends StatelessWidget {

  final String title;
  final String value;


  const _InfoRow({
    required this.title,
    required this.value,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
      children: [

        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}