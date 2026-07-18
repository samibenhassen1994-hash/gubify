import 'package:cloud_firestore/cloud_firestore.dart';

import '../modules/goals/models/goal_member_model.dart';
import '../modules/goals/models/goal_model.dart';

class GoalRepository {
  GoalRepository._();

  static final GoalRepository instance = GoalRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> goalsCollection(String gubId) {
    return _firestore.collection("gubs").doc(gubId).collection("goals");
  }

  /// Crea un nuovo obiettivo
  Future<void> createGoal(String gubId, GoalModel goal) async {
    await goalsCollection(gubId).doc(goal.goalId).set(goal.toFirestore());
  }

  /// Crea automaticamente tutti i membri dello Shared Budget
  Future<void> createGoalMembers({
    required String gubId,
    required String goalId,
    required List<GoalMemberModel> members,
  }) async {
    final batch = _firestore.batch();

    for (final member in members) {
      final doc = goalsCollection(
        gubId,
      ).doc(goalId).collection("members").doc(member.uid);

      batch.set(doc, member.toFirestore());
    }

    await batch.commit();
  }

  /// Rimuove un membro da tutti gli Shared Budget
  Future<void> removeMemberFromAllGoals({
    required String gubId,
    required String uid,
  }) async {
    final goals = await goalsCollection(gubId).get();

    for (final goal in goals.docs) {
      final goalId = goal.id;

      final memberRef = goalsCollection(
        gubId,
      ).doc(goalId).collection("members").doc(uid);

      final memberDoc = await memberRef.get();

      if (memberDoc.exists) {
        await memberRef.delete();

        await recalculateGoalProgress(gubId: gubId, goalId: goalId);
      }
    }
  }

  /// Ricalcola il progresso dello Shared Budget
  Future<void> recalculateGoalProgress({
    required String gubId,
    required String goalId,
  }) async {
    final membersSnapshot = await goalsCollection(
      gubId,
    ).doc(goalId).collection("members").get();

    double currentAmount = 0;
    int completedMembers = 0;
    final totalMembers = membersSnapshot.docs.length;

    for (final doc in membersSnapshot.docs) {
      final data = doc.data();

      final confirmed = data["confirmed"] ?? false;

      if (!confirmed) continue;

      completedMembers++;

      currentAmount += (data["amount"] ?? 0).toDouble();
    }

    await goalsCollection(gubId).doc(goalId).update({
      "currentAmount": currentAmount,
      "completedMembers": completedMembers,
      "totalMembers": totalMembers,
    });
  }

  /// Restituisce tutti gli obiettivi
  Future<List<GoalModel>> getGoals(String gubId) async {
    final snapshot = await goalsCollection(
      gubId,
    ).orderBy("createdAt", descending: true).get();

    return snapshot.docs
        .map((doc) => GoalModel.fromFirestore(doc.data()))
        .toList();
  }

  /// Stream degli obiettivi
  Stream<List<GoalModel>> goalsStream(String gubId) {
    return goalsCollection(gubId)
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => GoalModel.fromFirestore(doc.data()))
              .toList(),
        );
  }

  /// Restituisce il Goal attivo (Future)
  Future<GoalModel?> getActiveGoal(String gubId) async {
    final snapshot = await goalsCollection(
      gubId,
    ).where("status", isEqualTo: "active").limit(1).get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return GoalModel.fromFirestore(snapshot.docs.first.data());
  }

  /// Stream del Goal attivo
  Stream<GoalModel?> activeGoalStream(String gubId) {
    return goalsCollection(
      gubId,
    ).where("status", isEqualTo: "active").limit(1).snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return null;
      }

      return GoalModel.fromFirestore(snapshot.docs.first.data());
    });
  }

  /// Restituisce un singolo obiettivo
  Future<GoalModel?> getGoal(String gubId, String goalId) async {
    final doc = await goalsCollection(gubId).doc(goalId).get();

    if (!doc.exists) {
      return null;
    }

    return GoalModel.fromFirestore(doc.data()!);
  }

  /// Aggiorna un obiettivo
  Future<void> updateGoal(String gubId, GoalModel goal) async {
    await goalsCollection(gubId).doc(goal.goalId).update(goal.toFirestore());
  }

  /// Elimina un obiettivo
  Future<void> deleteGoal(String gubId, String goalId) async {
    await goalsCollection(gubId).doc(goalId).delete();
  }
}
