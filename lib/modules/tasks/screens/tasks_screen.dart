import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../widgets/gub_screen_background.dart';

import '../models/task_model.dart';
import '../services/task_service.dart';
import '../widgets/task_card.dart';
import 'create_task_screen.dart';
import 'task_details_screen.dart';

class TasksScreen extends StatelessWidget {
  final String gubId;

  const TasksScreen({super.key, required this.gubId});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return GubScreenBackground(
      variant: GubBackgroundAssignments.tasks,
      child: Scaffold(
        backgroundColor: Colors.transparent,

        appBar: AppBar(
          title: const Text("Tasks"),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),

        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CreateTaskScreen(gubId: gubId)),
            );
          },
          child: const Icon(Icons.add),
        ),

        body: StreamBuilder<List<TaskModel>>(
          stream: TaskService.instance.tasksStream(gubId),

          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text("No tasks yet"));
            }

            final tasks = snapshot.data!;

            final myTasks = tasks
                .where(
                  (task) =>
                      task.status == "active" &&
                      !task.archived &&
                      task.assignedUserId == currentUserId,
                )
                .toList();

            final activeTasks = tasks
                .where(
                  (task) =>
                      task.status == "active" &&
                      !task.archived &&
                      task.assignedUserId != currentUserId,
                )
                .toList();

            final completedTasks = tasks
                .where((task) => task.status == "completed" && !task.archived)
                .toList();

            return ListView(
              padding: const EdgeInsets.all(16),

              children: [
                if (myTasks.isNotEmpty) ...[
                  _sectionHeader(
                    context,
                    icon: Icons.person_outline,
                    title: "My Tasks",
                    subtitle: "Assigned to you",
                  ),

                  ...myTasks.map(
                    (task) => TaskCard(
                      task: task,
                      currentUserId: currentUserId,
                      onTap: () => _openTaskDetails(context, task),
                      onComplete: () async {
                        await TaskService.instance.completeTask(
                          task: task,
                          completedBy: currentUserId,
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 30),
                ],

                if (activeTasks.isNotEmpty) ...[
                  _sectionHeader(
                    context,
                    icon: Icons.pending_actions,
                    title: "Active",
                    subtitle: "Open tasks",
                  ),

                  ...activeTasks.map(
                    (task) => TaskCard(
                      task: task,
                      currentUserId: currentUserId,
                      onTap: () => _openTaskDetails(context, task),
                      onComplete: () async {
                        await TaskService.instance.completeTask(
                          task: task,
                          completedBy: currentUserId,
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 30),
                ],

                if (completedTasks.isNotEmpty) ...[
                  _sectionHeader(
                    context,
                    icon: Icons.task_alt,
                    title: "Completed",
                    subtitle: "Finished tasks",
                  ),

                  ...completedTasks.map(
                    (task) => TaskCard(
                      task: task,
                      currentUserId: currentUserId,
                      onTap: () => _openTaskDetails(context, task),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  void _openTaskDetails(BuildContext context, TaskModel task) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            TaskDetailsScreen(gubId: task.gubId, taskId: task.taskId),
      ),
    );
  }

  Widget _sectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Column(
      children: [
        Icon(icon, size: 34, color: Colors.blue),

        const SizedBox(height: 6),

        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 3),

        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}
