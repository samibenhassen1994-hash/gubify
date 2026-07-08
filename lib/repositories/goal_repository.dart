import 'package:cloud_firestore/cloud_firestore.dart';

import '../modules/goals/models/goal_model.dart';

class GoalRepository {
  GoalRepository._();

  static final GoalRepository instance = GoalRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> goalsCollection(
    String hubId,
  ) {
    return _firestore
        .collection("hubs")
        .doc(hubId)
        .collection("goals");
  }

  /// Crea un nuovo obiettivo
  Future<void> createGoal(
    String hubId,
    GoalModel goal,
  ) async {
    await goalsCollection(hubId)
        .doc(goal.goalId)
        .set(goal.toFirestore());
  }

  /// Crea tutti i membri del Goal
  Future<void> createGoalMembers({
    required String hubId,
    required String goalId,
    required List<Map<String, dynamic>> members,
  }) async {
    final batch = _firestore.batch();

    for (final member in members) {
      final doc = goalsCollection(hubId)
          .doc(goalId)
          .collection("members")
          .doc(member["uid"]);

      batch.set(doc, {
        "uid": member["uid"],
        "displayName": member["displayName"],
        "photoUrl": member["photoUrl"],
        "active": true,
        "paid": false,
        "paidAmount": 0,
        "paidAt": null,
      });
    }

    await batch.commit();
  }

  /// Restituisce tutti gli obiettivi
  Future<List<GoalModel>> getGoals(
    String hubId,
  ) async {
    final snapshot = await goalsCollection(hubId)
        .orderBy(
          "createdAt",
          descending: true,
        )
        .get();

    return snapshot.docs
        .map(
          (doc) => GoalModel.fromFirestore(
            doc.data(),
          ),
        )
        .toList();
  }

  /// Stream degli obiettivi
  Stream<List<GoalModel>> goalsStream(
    String hubId,
  ) {
    return goalsCollection(hubId)
        .orderBy(
          "createdAt",
          descending: true,
        )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => GoalModel.fromFirestore(
                  doc.data(),
                ),
              )
              .toList(),
        );
  }

  /// Restituisce un singolo obiettivo
  Future<GoalModel?> getGoal(
    String hubId,
    String goalId,
  ) async {
    final doc = await goalsCollection(hubId)
        .doc(goalId)
        .get();

    if (!doc.exists) {
      return null;
    }

    return GoalModel.fromFirestore(
      doc.data()!,
    );
  }

  /// Aggiorna un obiettivo
  Future<void> updateGoal(
    String hubId,
    GoalModel goal,
  ) async {
    await goalsCollection(hubId)
        .doc(goal.goalId)
        .update(goal.toFirestore());
  }

  /// Elimina un obiettivo
  Future<void> deleteGoal(
    String hubId,
    String goalId,
  ) async {
    await goalsCollection(hubId)
        .doc(goalId)
        .delete();
  }
}