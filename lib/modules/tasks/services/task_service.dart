import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/task_model.dart';
import '../repositories/task_repository.dart';
import 'task_notification_service.dart';

class TaskService {
  TaskService._();

  static final TaskService instance = TaskService._();

  Stream<List<TaskModel>> tasksStream(String hubId) {
    return TaskRepository.instance.tasksStream(hubId);
  }

  Stream<TaskModel?> taskStream({
    required String hubId,
    required String taskId,
  }) {
    return TaskRepository.instance.taskStream(
      hubId: hubId,
      taskId: taskId,
    );
  }

  Future<void> createTask(TaskModel task) async {
    await TaskRepository.instance.createTask(task);

    await TaskNotificationService.instance
        .sendTaskCreated(task);
  }

  Future<void> updateTask(TaskModel task) async {
    await TaskRepository.instance.updateTask(task);
  }

  Future<void> completeTask({
    required TaskModel task,
    required String completedBy,
  }) async {
    final completedTask = task.copyWith(
      status: "completed",
      completedAt: Timestamp.now(),
      completedBy: completedBy,
    );

    await TaskRepository.instance.updateTask(
      completedTask,
    );

    await TaskNotificationService.instance
        .sendTaskCompleted(completedTask);
  }

  Future<void> deleteTask({
    required String hubId,
    required String taskId,
  }) async {
    await TaskRepository.instance.deleteTask(
      hubId: hubId,
      taskId: taskId,
    );
  }
}