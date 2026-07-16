import '../../notifications/services/notification_service.dart';
import '../models/task_model.dart';

class TaskNotificationService {
  TaskNotificationService._();

  static final TaskNotificationService instance =
      TaskNotificationService._();

  Future<void> sendTaskCreated(TaskModel task) async {
    if (!task.notificationsEnabled) return;

    await NotificationService.instance.send(
      hubId: task.hubId,
      title: "New task",
      body:
          "${task.creatorName} assigned a new task: ${task.title}",
      type: "task_created",
      senderId: task.creatorId,
      senderName: task.creatorName,
      markSenderAsRead: true,
      data: {
        "module": "tasks",
        "hubId": task.hubId,
        "taskId": task.taskId,
      },
    );
  }

  Future<void> sendTaskCompleted(TaskModel task) async {
    if (!task.notificationsEnabled) return;

    await NotificationService.instance.send(
      hubId: task.hubId,
      title: "Task completed",
      body: "${task.title} has been completed.",
      type: "task_completed",
      senderId: task.completedBy ?? task.creatorId,
      senderName: task.creatorName,
      data: {
        "module": "tasks",
        "hubId": task.hubId,
        "taskId": task.taskId,
      },
    );
  }
}