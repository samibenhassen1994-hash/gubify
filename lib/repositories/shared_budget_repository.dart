import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../modules/shared_budget/models/shared_budget_member_model.dart';
import '../modules/shared_budget/models/shared_budget_model.dart';

class SharedBudgetRepository {
  SharedBudgetRepository._();

  static final SharedBudgetRepository instance = SharedBudgetRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int _deleteBatchSize = 400;

  /// Legacy Firestore path retained to read existing Shared Budget documents.
  CollectionReference<Map<String, dynamic>> sharedBudgetsCollection(
    String gubId,
  ) {
    return _firestore.collection("gubs").doc(gubId).collection("goals");
  }

  /// Crea un nuovo obiettivo
  Future<void> createSharedBudget(
    String gubId,
    SharedBudgetModel sharedBudget,
  ) async {
    await sharedBudgetsCollection(
      gubId,
    ).doc(sharedBudget.sharedBudgetId).set(sharedBudget.toFirestore());
  }

  /// Crea automaticamente tutti i membri dello Shared Budget
  Future<void> createSharedBudgetMembers({
    required String gubId,
    required String sharedBudgetId,
    required List<SharedBudgetMemberModel> members,
  }) async {
    final batch = _firestore.batch();

    for (final member in members) {
      final doc = sharedBudgetsCollection(
        gubId,
      ).doc(sharedBudgetId).collection("members").doc(member.uid);

      batch.set(doc, member.toFirestore());
    }

    await batch.commit();
  }

  /// Rimuove un membro da tutti gli Shared Budget
  Future<void> removeMemberFromAllSharedBudgets({
    required String gubId,
    required String uid,
  }) async {
    final sharedBudgets = await sharedBudgetsCollection(gubId).get();

    for (final sharedBudget in sharedBudgets.docs) {
      final sharedBudgetId = sharedBudget.id;

      final memberRef = sharedBudgetsCollection(
        gubId,
      ).doc(sharedBudgetId).collection("members").doc(uid);

      final memberDoc = await memberRef.get();

      if (memberDoc.exists) {
        await memberRef.delete();

        await recalculateSharedBudgetProgress(
          gubId: gubId,
          sharedBudgetId: sharedBudgetId,
        );
      }
    }
  }

  /// Ricalcola il progresso dello Shared Budget
  Future<void> recalculateSharedBudgetProgress({
    required String gubId,
    required String sharedBudgetId,
  }) async {
    final sharedBudgetRef = sharedBudgetsCollection(gubId).doc(sharedBudgetId);
    final membersSnapshot = await sharedBudgetRef.collection("members").get();

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
      final sharedBudgetSnapshot = await transaction.get(sharedBudgetRef);

      if (!sharedBudgetSnapshot.exists) {
        throw StateError("Shared Budget not found.");
      }

      final sharedBudgetData = sharedBudgetSnapshot.data()!;
      final targetAmount = (sharedBudgetData["targetAmount"] ?? 0).toDouble();
      final status = sharedBudgetData["status"] ?? "active";
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

      transaction.update(sharedBudgetRef, updates);
    });
  }

  /// Restituisce tutti gli obiettivi
  Future<List<SharedBudgetModel>> getSharedBudgets(String gubId) async {
    final snapshot = await sharedBudgetsCollection(gubId).get();

    return _sharedBudgetsFromDocs(snapshot.docs);
  }

  /// Stream degli Shared Budget non archiviati
  Stream<List<SharedBudgetModel>> sharedBudgetsStream(String gubId) {
    return sharedBudgetsCollection(gubId).snapshots().map(
      (snapshot) => _sharedBudgetsFromDocs(
        snapshot.docs,
      ).where((sharedBudget) => !sharedBudget.archived).toList(growable: false),
    );
  }

  Stream<List<SharedBudgetModel>> profileActivityCandidatesStream(
    String gubId,
  ) {
    return sharedBudgetsCollection(
      gubId,
    ).snapshots().map((snapshot) => _sharedBudgetsFromDocs(snapshot.docs));
  }

  /// Restituisce lo Shared Budget attivo (Future)
  Future<SharedBudgetModel?> getActiveSharedBudget(String gubId) async {
    final snapshot = await sharedBudgetsCollection(gubId).get();
    final sharedBudgets = _sharedBudgetsFromDocs(snapshot.docs)
        .where(
          (sharedBudget) => !sharedBudget.archived && !sharedBudget.isCompleted,
        )
        .toList();

    if (sharedBudgets.isEmpty) {
      return null;
    }

    return sharedBudgets[0];
  }

  /// Stream degli Shared Budget attivi
  Stream<List<SharedBudgetModel>> activeSharedBudgetsStream(String gubId) {
    return sharedBudgetsStream(gubId).map(
      (sharedBudgets) => sharedBudgets
          .where((sharedBudget) => !sharedBudget.isCompleted)
          .toList(growable: false),
    );
  }

  Stream<List<SharedBudgetModel>> completedSharedBudgetsStream(String gubId) {
    return sharedBudgetsStream(gubId).map(
      (sharedBudgets) => sharedBudgets
          .where((sharedBudget) => sharedBudget.isCompleted)
          .toList(growable: false),
    );
  }

  List<SharedBudgetModel> _sharedBudgetsFromDocs(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sharedBudgets = docs.map((doc) {
      final data = doc.data();
      final createdAt = data["createdAt"];

      return (
        sharedBudget: SharedBudgetModel.fromFirestore(data),
        createdAt: createdAt is Timestamp ? createdAt : null,
      );
    }).toList();

    sharedBudgets.sort((a, b) {
      final aCreatedAt = a.createdAt?.toDate().millisecondsSinceEpoch ?? 0;
      final bCreatedAt = b.createdAt?.toDate().millisecondsSinceEpoch ?? 0;
      final dateComparison = bCreatedAt.compareTo(aCreatedAt);

      if (dateComparison != 0) {
        return dateComparison;
      }

      return b.sharedBudget.sharedBudgetId.compareTo(
        a.sharedBudget.sharedBudgetId,
      );
    });

    return sharedBudgets
        .map((entry) => entry.sharedBudget)
        .toList(growable: false);
  }

  /// Restituisce un singolo obiettivo
  Future<SharedBudgetModel?> getSharedBudget(
    String gubId,
    String sharedBudgetId,
  ) async {
    final doc = await sharedBudgetsCollection(gubId).doc(sharedBudgetId).get();

    if (!doc.exists) {
      return null;
    }

    return SharedBudgetModel.fromFirestore(doc.data()!);
  }

  Stream<SharedBudgetModel?> sharedBudgetStream(
    String gubId,
    String sharedBudgetId,
  ) {
    return sharedBudgetsCollection(gubId).doc(sharedBudgetId).snapshots().map((
      document,
    ) {
      final data = document.data();
      return document.exists && data != null
          ? SharedBudgetModel.fromFirestore(data)
          : null;
    });
  }

  /// Aggiorna un obiettivo
  Future<void> updateSharedBudget(
    String gubId,
    SharedBudgetModel sharedBudget,
  ) async {
    await sharedBudgetsCollection(
      gubId,
    ).doc(sharedBudget.sharedBudgetId).update(sharedBudget.toFirestore());
  }

  /// Elimina un obiettivo
  Future<void> deleteSharedBudget(String gubId, String sharedBudgetId) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError("You must be signed in to delete a Shared Budget.");
    }

    final sharedBudgetReference = sharedBudgetsCollection(
      gubId,
    ).doc(sharedBudgetId);
    final sharedBudgetSnapshot = await sharedBudgetReference.get();

    if (!sharedBudgetSnapshot.exists) {
      throw StateError("Shared Budget not found.");
    }

    final data = sharedBudgetSnapshot.data()!;
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

    await _deleteDocumentsInBatches(
      sharedBudgetReference.collection("members"),
    );

    try {
      final notificationsQuery = _firestore
          .collection("gubs")
          .doc(gubId)
          .collection("notifications")
          .where("data.goalId", isEqualTo: sharedBudgetId);

      await _deleteDocumentsInBatches(notificationsQuery);
    } catch (error, stackTrace) {
      developer.log(
        "Unable to delete notifications linked to Shared Budget $sharedBudgetId.",
        name: "SharedBudgetRepository.deleteSharedBudget",
        error: error,
        stackTrace: stackTrace,
      );
    }

    await sharedBudgetReference.delete();
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
