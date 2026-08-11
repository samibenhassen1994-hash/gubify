import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/errors/active_creation_limit_exception.dart';
import '../../../core/models/creation_availability.dart';
import '../../../core/models/deletion_context.dart';
import '../../../repositories/creation_cooldown_repository.dart';
import '../../../repositories/gub_repository.dart';
import '../../../services/gub_service.dart';
import '../../../services/app_sound_service.dart';
import '../models/task_model.dart';
import '../repositories/task_repository.dart';
import 'task_notification_service.dart';

class TaskService {
  TaskService._();

  static final TaskService instance = TaskService._();

  final Set<String> _creationsInProgress = {};

  Future<CreationAvailability> creationAvailability({
    required String gubId,
    String? creatorId,
  }) async {
    final effectiveCreatorId =
        creatorId ?? FirebaseAuth.instance.currentUser?.uid;
    if (effectiveCreatorId == null) {
      throw StateError("You must be signed in to create a task.");
    }
    if (await GubRepository.instance.isAuthoritativeOwner(
      gubId: gubId,
      userId: effectiveCreatorId,
    )) {
      return const CreationAvailability(isUnlimited: true);
    }

    final activeFuture = TaskRepository.instance.getActiveTaskCreatedBy(
      gubId: gubId,
      creatorId: effectiveCreatorId,
    );
    final cooldownFuture = CreationCooldownRepository.instance.get(
      gubId: gubId,
      creatorId: effectiveCreatorId,
      moduleType: CreationModuleType.task,
    );
    final results = await Future.wait<Object?>([activeFuture, cooldownFuture]);
    final activeTask = results[0] as TaskModel?;
    final cooldown = results[1] as CreationCooldown?;

    return CreationAvailability(
      activeItemId: activeTask?.taskId,
      activeItemTitle: activeTask?.title,
      activeItem: activeTask,
      cooldown: cooldown,
    );
  }

  Stream<List<TaskModel>> tasksStream(String gubId) {
    return Stream.fromFuture(
      GubService().currentMembershipHistoryBoundary(gubId),
    ).asyncExpand((boundary) {
      if (boundary?.membershipStartedAt case final timestamp?) {
        return TaskRepository.instance.tasksStream(
          gubId,
          membershipBoundary: timestamp,
        );
      }
      return Stream.value(const <TaskModel>[]);
    });
  }

  Stream<TaskModel?> taskStream({
    required String gubId,
    required String taskId,
  }) {
    return TaskRepository.instance.taskStream(gubId: gubId, taskId: taskId);
  }

  Future<void> createTask(TaskModel task) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || currentUserId != task.creatorId) {
      throw StateError("You must be signed in as the task creator.");
    }
    await GubRepository.instance.ensureActive(task.gubId);

    final creationKey = "${task.gubId}/${task.creatorId}";
    if (!_creationsInProgress.add(creationKey)) {
      throw StateError("A task creation is already in progress.");
    }

    try {
      final availability = await creationAvailability(
        gubId: task.gubId,
        creatorId: task.creatorId,
      );
      if (availability.hasActiveItem) {
        throw const ActiveCreationLimitException(
          "You already have an active task. Complete it before creating another one.",
        );
      }
      if (availability.isCoolingDown) {
        throw CreationCooldownException(
          "You can create another task in "
          "${formatCooldownRemaining(availability.cooldown!.remaining)}.",
        );
      }

      await TaskRepository.instance.createTask(task);

      await TaskNotificationService.instance.sendTaskCreated(task);
      await AppSoundService.instance.playCreated();
    } finally {
      _creationsInProgress.remove(creationKey);
    }
  }

  Future<void> updateTask(TaskModel task) async {
    await GubRepository.instance.ensureActive(task.gubId);
    await TaskRepository.instance.updateTask(task);
  }

  Future<void> completeTask({
    required TaskModel task,
    required String completedBy,
  }) async {
    await GubRepository.instance.ensureActive(task.gubId);
    final completedTask = task.copyWith(
      status: "completed",
      completedAt: Timestamp.now(),
      completedBy: completedBy,
    );

    await TaskRepository.instance.updateTask(completedTask);

    await TaskNotificationService.instance.sendTaskCompleted(completedTask);
    await AppSoundService.instance.playCompleted();
  }

  Future<void> deleteTask({
    required String gubId,
    required String taskId,
  }) async {
    await GubRepository.instance.ensureActive(gubId);
    if (!await canDeleteTask(gubId: gubId, taskId: taskId)) {
      throw StateError("You don't have permission to delete this task.");
    }
    await TaskRepository.instance.deleteTask(gubId: gubId, taskId: taskId);
  }

  Future<bool> canDeleteTask({required String gubId, required String taskId}) {
    return TaskRepository.instance.canDeleteTask(gubId: gubId, taskId: taskId);
  }

  Future<DeletionContext> deletionContext({
    required String gubId,
    required String taskId,
  }) {
    return TaskRepository.instance.deletionContext(
      gubId: gubId,
      taskId: taskId,
    );
  }
}
