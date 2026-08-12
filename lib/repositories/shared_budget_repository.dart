import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/models/creation_availability.dart';
import '../core/models/deletion_context.dart';
import '../modules/shared_budget/models/shared_budget_member_model.dart';
import '../modules/shared_budget/models/shared_budget_model.dart';
import 'creation_cooldown_repository.dart';
import 'gub_repository.dart';

class SharedBudgetRepository {
  SharedBudgetRepository._();

  static final SharedBudgetRepository instance = SharedBudgetRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
    await GubRepository.instance.ensureActive(gubId);
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
    await GubRepository.instance.ensureActive(gubId);
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
    await GubRepository.instance.ensureActive(gubId);
    final sharedBudgets = await sharedBudgetsCollection(gubId).get();

    for (final sharedBudget in sharedBudgets.docs) {
      final sharedBudgetId = sharedBudget.id;
      final sharedBudgetData = sharedBudget.data();
      if (sharedBudgetData['status'] != 'active' ||
          sharedBudgetData['archived'] == true ||
          _isDeleted(sharedBudgetData)) {
        continue;
      }

      final memberRef = sharedBudgetsCollection(
        gubId,
      ).doc(sharedBudgetId).collection("members").doc(uid);

      final memberDoc = await memberRef.get();

      if (memberDoc.exists && memberDoc.data()?['confirmed'] != true) {
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
      final gubSnapshot = await transaction.get(
        _firestore.collection('gubs').doc(gubId),
      );
      final sharedBudgetSnapshot = await transaction.get(sharedBudgetRef);

      if (!gubSnapshot.exists ||
          gubSnapshot.data()?['deletionStatus'] == 'deleting') {
        throw StateError('This Gub is no longer available.');
      }

      if (!sharedBudgetSnapshot.exists) {
        throw StateError("Shared Budget not found.");
      }

      final sharedBudgetData = sharedBudgetSnapshot.data()!;
      final targetAmount = (sharedBudgetData["targetAmount"] ?? 0).toDouble();
      final status = sharedBudgetData["status"] ?? "active";
      if (status == "deleted" || sharedBudgetData["deletedAt"] != null) {
        return;
      }
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
    final sharedBudgets = docs
        .map((doc) {
          final data = doc.data();
          if (_isDeleted(data)) return null;
          final createdAt = data["createdAt"];

          return (
            sharedBudget: SharedBudgetModel.fromFirestore(data),
            createdAt: createdAt is Timestamp ? createdAt : null,
          );
        })
        .whereType<({SharedBudgetModel sharedBudget, Timestamp? createdAt})>()
        .toList();

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
    await GubRepository.instance.ensureActive(gubId);
    final doc = await sharedBudgetsCollection(gubId).doc(sharedBudgetId).get();

    if (!doc.exists || _isDeleted(doc.data())) {
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
      return document.exists && data != null && !_isDeleted(data)
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
    final gubReference = _firestore.collection("gubs").doc(gubId);
    final availableAt = Timestamp.fromDate(
      DateTime.now().add(CreationCooldownRepository.cooldownDuration),
    );

    await _firestore.runTransaction((transaction) async {
      final sharedBudgetSnapshot = await transaction.get(sharedBudgetReference);
      final gubSnapshot = await transaction.get(gubReference);
      if (!sharedBudgetSnapshot.exists ||
          _isDeleted(sharedBudgetSnapshot.data())) {
        throw StateError("Shared Budget not found.");
      }
      if (!gubSnapshot.exists) throw StateError("Gub not found.");
      if (gubSnapshot.data()?['deletionStatus'] == 'deleting') {
        throw StateError('This Gub is no longer available.');
      }

      final data = sharedBudgetSnapshot.data()!;
      final creatorId = data["ownerId"] as String? ?? "";
      final gubOwnerId = gubSnapshot.data()?["ownerId"] as String? ?? "";
      if (user.uid != creatorId && user.uid != gubOwnerId) {
        throw StateError(
          "You don't have permission to delete this Shared Budget.",
        );
      }

      transaction.update(sharedBudgetReference, {
        "status": "deleted",
        "archived": true,
        "deletedAt": FieldValue.serverTimestamp(),
        "deletedBy": user.uid,
      });
      if (creatorId.isNotEmpty && creatorId != gubOwnerId) {
        CreationCooldownRepository.instance.setInTransaction(
          transaction: transaction,
          gubId: gubId,
          creatorId: creatorId,
          moduleType: CreationModuleType.sharedBudget,
          deletedItemId: sharedBudgetId,
          deletedBy: user.uid,
          availableAt: availableAt,
        );
      }
    });
  }

  Future<bool> canDeleteSharedBudget({
    required String gubId,
    required String sharedBudgetId,
  }) async {
    return (await deletionContext(
      gubId: gubId,
      sharedBudgetId: sharedBudgetId,
    )).canDelete;
  }

  Future<DeletionContext> deletionContext({
    required String gubId,
    required String sharedBudgetId,
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
      sharedBudgetsCollection(gubId).doc(sharedBudgetId).get(),
      _firestore.collection("gubs").doc(gubId).get(),
    ]);
    final budget = documents[0];
    final gub = documents[1];
    final creatorId = _nonEmptyString(budget.data()?["ownerId"]);
    final ownerId = _nonEmptyString(gub.data()?["ownerId"]) ?? "";
    return DeletionContext(
      canDelete:
          budget.exists &&
          gub.exists &&
          !_isDeleted(budget.data()) &&
          (userId == creatorId || userId == ownerId),
      currentUserIsOwner: userId == ownerId,
      creatorId: creatorId,
      ownerId: ownerId,
    );
  }

  bool _isDeleted(Map<String, dynamic>? data) {
    return data?["status"] == "deleted" || data?["deletedAt"] != null;
  }

  String? _nonEmptyString(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value;
  }
}
