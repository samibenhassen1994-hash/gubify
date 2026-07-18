import 'package:flutter/material.dart';

import '../models/task_model.dart';
import '../screens/tasks_screen.dart';
import '../services/task_service.dart';

class TaskHomeCard extends StatelessWidget {
  final String gubId;

  const TaskHomeCard({
    super.key,
    required this.gubId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TaskModel>>(
      stream: TaskService.instance.tasksStream(gubId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final tasks = snapshot.data!;

        final activeTasks = tasks
            .where((task) => task.status == "active" && !task.archived)
            .length;

        final completedTasks = tasks
            .where((task) => task.status == "completed" && !task.archived)
            .length;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.task_alt),
                    const SizedBox(width: 8),
                    Text(
                      "Tasks",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text("Active: $activeTasks"),
                Text("Completed: $completedTasks"),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TasksScreen(
                            gubId: gubId,
                          ),
                        ),
                      );
                    },
                    child: const Text("Open"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}