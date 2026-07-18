import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/task_model.dart';

class TaskRepository {
  TaskRepository._();

  static final TaskRepository instance = TaskRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> tasksCollection(String hubId) {
    return _firestore
        .collection("gubs")
        .doc(hubId)
        .collection("tasks");
  }

  /// Generates a unique Task ID without creating any document.
  String generateTaskId() {
    return _firestore.collection("_").doc().id;
  }

  Future<void> createTask(TaskModel task) async {
    await tasksCollection(task.hubId)
        .doc(task.taskId)
        .set(task.toFirestore());
  }

  Future<void> updateTask(TaskModel task) async {
    await tasksCollection(task.hubId)
        .doc(task.taskId)
        .update(task.toFirestore());
  }

  Future<void> deleteTask({
    required String hubId,
    required String taskId,
  }) async {
    await tasksCollection(hubId).doc(taskId).delete();
  }

  Future<TaskModel?> getTask({
    required String hubId,
    required String taskId,
  }) async {
    final doc = await tasksCollection(hubId)
        .doc(taskId)
        .get();

    if (!doc.exists) return null;

    return TaskModel.fromFirestore(doc.data()!);
  }

  Stream<TaskModel?> taskStream({
    required String hubId,
    required String taskId,
  }) {
    return tasksCollection(hubId)
        .doc(taskId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;

      return TaskModel.fromFirestore(doc.data()!);
    });
  }

  Stream<List<TaskModel>> tasksStream(String hubId) {
    return tasksCollection(hubId)
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TaskModel.fromFirestore(doc.data()))
              .toList(),
        );
  }
}