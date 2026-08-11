import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/models/creation_availability.dart';
import '../../../core/models/deletion_context.dart';
import '../../../repositories/creation_cooldown_repository.dart';
import '../models/task_model.dart';

class TaskRepository {
  TaskRepository._();

  static final TaskRepository instance = TaskRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> tasksCollection(String gubId) {
    return _firestore.collection("gubs").doc(gubId).collection("tasks");
  }

  /// Generates a unique Task ID without creating any document.
  String generateTaskId() {
    return _firestore.collection("_").doc().id;
  }

  Future<void> createTask(TaskModel task) async {
    await tasksCollection(task.gubId).doc(task.taskId).set(task.toFirestore());
  }

  Future<bool> hasActiveTaskCreatedBy({
    required String gubId,
    required String creatorId,
  }) async =>
      await getActiveTaskCreatedBy(gubId: gubId, creatorId: creatorId) != null;

  Future<TaskModel?> getActiveTaskCreatedBy({
    required String gubId,
    required String creatorId,
  }) async {
    final snapshot = await tasksCollection(gubId)
        .where("creatorId", isEqualTo: creatorId)
        .where("status", isEqualTo: "active")
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final document = snapshot.docs.first;
    return TaskModel.fromFirestore({
      ...document.data(),
      "taskId": document.data()["taskId"] ?? document.id,
      "gubId": document.data()["gubId"] ?? gubId,
    });
  }

  Future<void> updateTask(TaskModel task) async {
    await tasksCollection(
      task.gubId,
    ).doc(task.taskId).update(task.toFirestore());
  }

  Future<void> deleteTask({
    required String gubId,
    required String taskId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError("You must be signed in to delete a task.");
    }

    final taskReference = tasksCollection(gubId).doc(taskId);
    final gubReference = _firestore.collection("gubs").doc(gubId);
    final availableAt = Timestamp.fromDate(
      DateTime.now().add(CreationCooldownRepository.cooldownDuration),
    );

    await _firestore.runTransaction((transaction) async {
      final taskSnapshot = await transaction.get(taskReference);
      final gubSnapshot = await transaction.get(gubReference);
      if (!taskSnapshot.exists) throw StateError("Task not found.");
      if (!gubSnapshot.exists) throw StateError("Gub not found.");

      final creatorId = taskSnapshot.data()?["creatorId"] as String? ?? "";
      final gubOwnerId = gubSnapshot.data()?["ownerId"] as String? ?? "";
      if (user.uid != creatorId && user.uid != gubOwnerId) {
        throw StateError("You don't have permission to delete this task.");
      }

      transaction.delete(taskReference);
      if (creatorId.isNotEmpty && creatorId != gubOwnerId) {
        CreationCooldownRepository.instance.setInTransaction(
          transaction: transaction,
          gubId: gubId,
          creatorId: creatorId,
          moduleType: CreationModuleType.task,
          deletedItemId: taskId,
          deletedBy: user.uid,
          availableAt: availableAt,
        );
      }
    });
  }

  Future<bool> canDeleteTask({
    required String gubId,
    required String taskId,
  }) async {
    return (await deletionContext(gubId: gubId, taskId: taskId)).canDelete;
  }

  Future<DeletionContext> deletionContext({
    required String gubId,
    required String taskId,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return const DeletionContext(
        canDelete: false,
        currentUserIsOwner: false,
        creatorId: null,
        ownerId: '',
      );
    }

    final documents = await Future.wait([
      tasksCollection(gubId).doc(taskId).get(),
      _firestore.collection("gubs").doc(gubId).get(),
    ]);
    final task = documents[0];
    final gub = documents[1];
    final creatorId = _nonEmptyString(task.data()?["creatorId"]);
    final ownerId = _nonEmptyString(gub.data()?["ownerId"]) ?? "";
    return DeletionContext(
      canDelete:
          task.exists &&
          gub.exists &&
          (userId == creatorId || userId == ownerId),
      currentUserIsOwner: userId == ownerId,
      creatorId: creatorId,
      ownerId: ownerId,
    );
  }

  Future<TaskModel?> getTask({
    required String gubId,
    required String taskId,
  }) async {
    final doc = await tasksCollection(gubId).doc(taskId).get();

    if (!doc.exists) return null;

    return TaskModel.fromFirestore(doc.data()!);
  }

  Stream<TaskModel?> taskStream({
    required String gubId,
    required String taskId,
  }) {
    return tasksCollection(gubId).doc(taskId).snapshots().map((doc) {
      if (!doc.exists) return null;

      return TaskModel.fromFirestore(doc.data()!);
    });
  }

  Stream<List<TaskModel>> tasksStream(
    String gubId, {
    required Timestamp membershipBoundary,
  }) {
    return tasksCollection(gubId)
        .where(
          Filter.or(
            Filter('status', isEqualTo: 'active'),
            Filter.and(
              Filter('status', isEqualTo: 'completed'),
              Filter('completedAt', isGreaterThanOrEqualTo: membershipBoundary),
            ),
          ),
        )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TaskModel.fromFirestore(doc.data()))
              .toList(),
        );
  }

  Stream<List<TaskModel>> profileActivityCandidatesStream(
    String gubId, {
    required Timestamp membershipBoundary,
  }) => tasksStream(gubId, membershipBoundary: membershipBoundary);

  Future<void> unassignActiveTasksForMember({
    required String gubId,
    required String uid,
  }) async {
    final snapshot = await tasksCollection(
      gubId,
    ).where('assignedUserId', isEqualTo: uid).get();
    final activeTasks = snapshot.docs.where(
      (document) => document.data()['status'] == 'active',
    );
    final batch = _firestore.batch();
    var count = 0;
    for (final task in activeTasks) {
      batch.update(task.reference, {
        'assignedUserId': null,
        'assignedUserName': null,
      });
      count++;
      if (count == 400) {
        await batch.commit();
        return unassignActiveTasksForMember(gubId: gubId, uid: uid);
      }
    }
    if (count > 0) await batch.commit();
  }

  String? _nonEmptyString(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value;
  }
}
