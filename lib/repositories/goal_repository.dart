import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../modules/goals/models/goal_member_model.dart';
import '../modules/goals/models/goal_model.dart';

class GoalRepository {
  GoalRepository._();

  static final GoalRepository instance = GoalRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int _deleteBatchSize = 400;

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

  Stream<List<GoalModel>> profileActivityCandidatesStream(String gubId) {
    return goalsCollection(
      gubId,
    ).snapshots().map((snapshot) => _goalsFromDocs(snapshot.docs));
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

  Stream<GoalModel?> goalStream(String gubId, String goalId) {
    return goalsCollection(gubId).doc(goalId).snapshots().map((document) {
      final data = document.data();
      return document.exists && data != null
          ? GoalModel.fromFirestore(data)
          : null;
    });
  }

  /// Aggiorna un obiettivo
  Future<void> updateGoal(String gubId, GoalModel goal) async {
    await goalsCollection(gubId).doc(goal.goalId).update(goal.toFirestore());
  }

  /// Elimina un obiettivo
  Future<void> deleteGoal(String gubId, String goalId) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError("You must be signed in to delete a Shared Budget.");
    }

    final goalReference = goalsCollection(gubId).doc(goalId);
    final goalSnapshot = await goalReference.get();

    if (!goalSnapshot.exists) {
      throw StateError("Shared Budget not found.");
    }

    final data = goalSnapshot.data()!;
    final ownerId = data["ownerId"] ?? "";

    if (ownerId != user.uid) {
      throw StateError(
        "Only the Shared Budget creator can delete this budget.",
      );
    }

    final status = data["status"] ?? "active";
    final archived = data["archived"] ?? false;
    final targetAmount = (data["targetAmount"] ?? 0).toDouble();
    final currentAmount = (data["currentAmount"] ?? 0).toDouble();
    final isCompleted =
        status == "completed" ||
        (targetAmount > 0 && currentAmount >= targetAmount);

    if (isCompleted || archived) {
      throw StateError("Only active Shared Budgets can be deleted.");
    }

    await _deleteDocumentsInBatches(goalReference.collection("members"));

    try {
      final notificationsQuery = _firestore
          .collection("gubs")
          .doc(gubId)
          .collection("notifications")
          .where("data.goalId", isEqualTo: goalId);

      await _deleteDocumentsInBatches(notificationsQuery);
    } catch (error, stackTrace) {
      developer.log(
        "Unable to delete notifications linked to Shared Budget $goalId.",
        name: "GoalRepository.deleteGoal",
        error: error,
        stackTrace: stackTrace,
      );
    }

    await goalReference.delete();
  }

  Future<void> _deleteDocumentsInBatches(
    Query<Map<String, dynamic>> query,
  ) async {
    while (true) {
      final snapshot = await query.limit(_deleteBatchSize).get();

      if (snapshot.docs.isEmpty) {
        return;
      }

      final batch = _firestore.batch();

      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }

      await batch.commit();

      if (snapshot.docs.length < _deleteBatchSize) {
        return;
      }
    }
  }
}
