import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/task_model.dart';

class TaskRepository {
  TaskRepository._();

  static final TaskRepository instance = TaskRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  Future<void> updateTask(TaskModel task) async {
    await tasksCollection(
      task.gubId,
    ).doc(task.taskId).update(task.toFirestore());
  }

  Future<void> deleteTask({
    required String gubId,
    required String taskId,
  }) async {
    await tasksCollection(gubId).doc(taskId).delete();
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

  Stream<List<TaskModel>> tasksStream(String gubId) {
    return tasksCollection(gubId)
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TaskModel.fromFirestore(doc.data()))
              .toList(),
        );
  }

  Stream<List<TaskModel>> profileActivityCandidatesStream(String gubId) {
    return tasksCollection(gubId).snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => TaskModel.fromFirestore(doc.data()))
          .toList(growable: false),
    );
  }
}
