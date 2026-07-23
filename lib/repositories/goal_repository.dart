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
    final goalRef = goalsCollection(gubId).doc(goalId);
    final membersSnapshot = await goalRef.collection("members").get();

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

    await _firestore.runTransaction((transaction) async {
      final goalSnapshot = await transaction.get(goalRef);

      if (!goalSnapshot.exists) {
        throw StateError("Shared Budget not found.");
      }

      final goalData = goalSnapshot.data()!;
      final targetAmount = (goalData["targetAmount"] ?? 0).toDouble();
      final status = goalData["status"] ?? "active";
      final hasReachedTarget =
          targetAmount > 0 && currentAmount >= targetAmount;

      final updates = <String, dynamic>{
        "currentAmount": currentAmount,
        "completedMembers": completedMembers,
        "totalMembers": totalMembers,
      };

      if (status == "active" && hasReachedTarget) {
        updates.addAll({
          "status": "completed",
          "archived": false,
          "completedAt": FieldValue.serverTimestamp(),
        });
      }

      transaction.update(goalRef, updates);
    });
  }

  /// Restituisce tutti gli obiettivi
  Future<List<GoalModel>> getGoals(String gubId) async {
    final snapshot = await goalsCollection(gubId).get();

    return _goalsFromDocs(snapshot.docs);
  }

  /// Stream degli Shared Budget non archiviati
  Stream<List<GoalModel>> goalsStream(String gubId) {
    return goalsCollection(gubId).snapshots().map(
      (snapshot) => _goalsFromDocs(
        snapshot.docs,
      ).where((goal) => !goal.archived).toList(growable: false),
    );
  }

  /// Restituisce il Goal attivo (Future)
  Future<GoalModel?> getActiveGoal(String gubId) async {
    final snapshot = await goalsCollection(gubId).get();
    final goals = _goalsFromDocs(
      snapshot.docs,
    ).where((goal) => !goal.archived && !goal.isCompleted).toList();

    if (goals.isEmpty) {
      return null;
    }

    return goals[0];
  }

  /// Stream degli Shared Budget attivi
  Stream<List<GoalModel>> activeGoalsStream(String gubId) {
    return goalsStream(gubId).map(
      (goals) =>
          goals.where((goal) => !goal.isCompleted).toList(growable: false),
    );
  }

  Stream<List<GoalModel>> completedGoalsStream(String gubId) {
    return goalsStream(gubId).map(
      (goals) =>
          goals.where((goal) => goal.isCompleted).toList(growable: false),
    );
  }

  List<GoalModel> _goalsFromDocs(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final goals = docs.map((doc) {
      final data = doc.data();
      final createdAt = data["createdAt"];

      return (
        goal: GoalModel.fromFirestore(data),
        createdAt: createdAt is Timestamp ? createdAt : null,
      );
    }).toList();

    goals.sort((a, b) {
      final aCreatedAt = a.createdAt?.toDate().millisecondsSinceEpoch ?? 0;
      final bCreatedAt = b.createdAt?.toDate().millisecondsSinceEpoch ?? 0;
      final dateComparison = bCreatedAt.compareTo(aCreatedAt);

      if (dateComparison != 0) {
        return dateComparison;
      }

      return b.goal.goalId.compareTo(a.goal.goalId);
    });

    return goals.map((entry) => entry.goal).toList(growable: false);
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
