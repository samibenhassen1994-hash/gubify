import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/models/creation_availability.dart';
import '../../../core/navigation/creation_gate.dart';
import '../../../widgets/gub_content_card.dart';
import '../../../widgets/gub_screen_background.dart';
import '../../chat/widgets/gub_chat_overlay.dart';
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

    return ChatFloatingActionButtonRouteScope(
      additionalBottomOffset: kFloatingActionButtonMargin,
      child: DefaultTabController(
        length: 2,
        child: GubScreenBackground(
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
              onPressed: () async {
                final allowed = await CreationGate.ensureAvailable(
                  context: context,
                  gubId: gubId,
                  moduleType: CreationModuleType.task,
                );
                if (!allowed || !context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateTaskScreen(gubId: gubId),
                  ),
                );
              },
              child: const Icon(Icons.add),
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    clipBehavior: Clip.antiAlias,
                    child: const TabBar(
                      tabs: [
                        Tab(text: "Active"),
                        Tab(text: "Completed"),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<TaskModel>>(
                    stream: TaskService.instance.tasksStream(gubId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final tasks = snapshot.data ?? const <TaskModel>[];
                      final myTasks = tasks
                          .where(
                            (task) =>
                                task.status == "active" &&
                                !task.archived &&
                                task.assignedUserId == currentUserId,
                          )
                          .toList(growable: false);
                      final activeTasks = tasks
                          .where(
                            (task) =>
                                task.status == "active" &&
                                !task.archived &&
                                task.assignedUserId != currentUserId,
                          )
                          .toList(growable: false);
                      final completedTasks = tasks
                          .where(
                            (task) =>
                                task.status == "completed" && !task.archived,
                          )
                          .toList(growable: false);

                      return TabBarView(
                        children: [
                          _activeTasksList(
                            context,
                            currentUserId: currentUserId,
                            myTasks: myTasks,
                            activeTasks: activeTasks,
                          ),
                          _completedTasksList(
                            context,
                            currentUserId: currentUserId,
                            tasks: completedTasks,
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
      ),
    );
  }

  Widget _activeTasksList(
    BuildContext context, {
    required String currentUserId,
    required List<TaskModel> myTasks,
    required List<TaskModel> activeTasks,
  }) {
    if (myTasks.isEmpty && activeTasks.isEmpty) {
      return _emptyState("No active tasks");
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        if (myTasks.isNotEmpty) ...[
          _sectionHeader(
            context,
            icon: Icons.person_outline,
            title: "My Tasks",
            subtitle: "Assigned to you",
          ),
          for (final task in myTasks)
            TaskCard(
              task: task,
              currentUserId: currentUserId,
              onTap: () => _openTaskDetails(context, task),
              onComplete: () => TaskService.instance.completeTask(
                task: task,
                completedBy: currentUserId,
              ),
            ),
          if (activeTasks.isNotEmpty) const SizedBox(height: 26),
        ],
        if (activeTasks.isNotEmpty) ...[
          _sectionHeader(
            context,
            icon: Icons.pending_actions,
            title: "Active",
            subtitle: "Open tasks",
          ),
          for (final task in activeTasks)
            TaskCard(
              task: task,
              currentUserId: currentUserId,
              onTap: () => _openTaskDetails(context, task),
              onComplete: () => TaskService.instance.completeTask(
                task: task,
                completedBy: currentUserId,
              ),
            ),
        ],
      ],
    );
  }

  Widget _completedTasksList(
    BuildContext context, {
    required String currentUserId,
    required List<TaskModel> tasks,
  }) {
    if (tasks.isEmpty) return _emptyState("No completed tasks");

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        for (final task in tasks)
          TaskCard(
            task: task,
            currentUserId: currentUserId,
            onTap: () => _openTaskDetails(context, task),
          ),
      ],
    );
  }

  Widget _emptyState(String message) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        GubContentCard(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
        ),
      ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GubContentCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, size: 30, color: Colors.blue),
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
          ],
        ),
      ),
    );
  }
}
