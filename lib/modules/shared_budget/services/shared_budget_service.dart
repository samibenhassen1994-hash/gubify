import 'dart:developer' as developer;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/errors/active_creation_limit_exception.dart';
import '../../../core/models/creation_availability.dart';
import '../../../core/models/deletion_context.dart';
import '../../../repositories/creation_cooldown_repository.dart';
import '../../../repositories/gub_repository.dart';
import '../../../services/gub_service.dart';
import '../../../services/app_sound_service.dart';
import '../models/shared_budget_member_model.dart';
import '../models/shared_budget_model.dart';
import '../../../repositories/shared_budget_repository.dart';
import '../../notifications/services/notification_service.dart';

class SharedBudgetService {
  SharedBudgetService._();

  static final SharedBudgetService instance = SharedBudgetService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Set<String> _creationsInProgress = {};

  Future<CreationAvailability> creationAvailability({
    required String gubId,
    String? creatorId,
  }) async {
    final effectiveCreatorId = creatorId ?? _auth.currentUser?.uid;
    if (effectiveCreatorId == null) {
      throw StateError("You must be signed in to create a Shared Budget.");
    }
    if (await GubRepository.instance.isAuthoritativeOwner(
      gubId: gubId,
      userId: effectiveCreatorId,
    )) {
      return const CreationAvailability(isUnlimited: true);
    }

    final cooldown = await CreationCooldownRepository.instance.get(
      gubId: gubId,
      creatorId: effectiveCreatorId,
      moduleType: CreationModuleType.sharedBudget,
    );
    return CreationAvailability(cooldown: cooldown);
  }

  Future<void> createSharedBudget({
    required String gubId,
    required String title,
    required String description,
    required double targetAmount,
    DateTime? deadline,
    String? sourceType,
    String? sourceId,
    String? sourcePreview,
    String? originUserId,
    String? sourceAuthorName,
  }) async {
    await GubRepository.instance.ensureActive(gubId);
    final creator = await _requireAuthorizedCreator(gubId);
    final creationKey = "$gubId/${creator.uid}";
    if (!_creationsInProgress.add(creationKey)) {
      throw StateError("A Shared Budget creation is already in progress.");
    }

    try {
      final availability = await creationAvailability(
        gubId: gubId,
        creatorId: creator.uid,
      );
      if (availability.isCoolingDown) {
        throw CreationCooldownException(
          "You can create another Shared Budget in "
          "${formatCooldownRemaining(availability.cooldown!.remaining)}.",
        );
      }

      final normalizedValues = _validate(title, description, targetAmount);
      final members = await _loadHubMembers(gubId);

      final sharedBudget = _buildSharedBudget(
        creatorId: creator.uid,
        title: normalizedValues.title,
        description: normalizedValues.description,
        targetAmount: targetAmount,
        memberCount: members.length,
        deadline: deadline,
        sourceType: sourceType,
        sourceId: sourceId,
        sourcePreview: sourcePreview,
        originUserId: originUserId,
        sourceAuthorName: sourceAuthorName,
      );

      await SharedBudgetRepository.instance.createSharedBudget(
        gubId,
        sharedBudget,
      );

      final sharedBudgetMembers = members
          .map(
            (member) => SharedBudgetMemberModel(
              uid: member["uid"],
              displayName: member["displayName"] ?? "User",
              photoUrl: member["photoUrl"],
              amount: 0,
              confirmed: false,
              updatedAt: Timestamp.now(),
              confirmedAt: null,
            ),
          )
          .toList();

      await SharedBudgetRepository.instance.createSharedBudgetMembers(
        gubId: gubId,
        sharedBudgetId: sharedBudget.sharedBudgetId,
        members: sharedBudgetMembers,
      );

      await AppSoundService.instance.playCreated();

      var creatorName = creator.displayName ?? "Administrator";

      for (final member in members) {
        if (member["uid"] == creator.uid) {
          creatorName = member["displayName"] ?? creatorName;
          break;
        }
      }

      try {
        // Legacy notification type, module key and payload field are preserved.
        await NotificationService.instance.send(
          gubId: gubId,
          title: "New Shared Budget",
          body: "$creatorName created “${sharedBudget.title}”.",
          type: "goal_created",
          senderId: creator.uid,
          senderName: creatorName,
          markSenderAsRead: true,
          data: {
            "module": "goals",
            "gubId": gubId,
            "goalId": sharedBudget.sharedBudgetId,
          },
        );
      } catch (error, stackTrace) {
        developer.log(
          "Unable to send the Shared Budget creation notification.",
          name: "SharedBudgetService.createSharedBudget",
          error: error,
          stackTrace: stackTrace,
        );
      }
    } finally {
      _creationsInProgress.remove(creationKey);
    }
  }

  /// Future (lo lasciamo per compatibilità)
  Future<SharedBudgetModel?> getActiveSharedBudget(String gubId) {
    return SharedBudgetRepository.instance.getActiveSharedBudget(gubId);
  }

  /// Stream in tempo reale
  Stream<List<SharedBudgetModel>> activeSharedBudgetsStream(String gubId) {
    return sharedBudgetsStream(
      gubId,
    ).map((budgets) => budgets.where((budget) => !budget.isCompleted).toList());
  }

  Stream<List<SharedBudgetModel>> sharedBudgetsStream(String gubId) =>
      Stream.fromFuture(
        GubService().currentMembershipHistoryBoundary(gubId),
      ).asyncExpand((boundary) {
        if (boundary?.membershipStartedAt case final timestamp?) {
          return SharedBudgetRepository.instance.sharedBudgetsStream(
            gubId,
            membershipBoundary: timestamp,
          );
        }
        return Stream.value(const <SharedBudgetModel>[]);
      });

  Stream<List<SharedBudgetModel>> completedSharedBudgetsStream(String gubId) {
    return sharedBudgetsStream(
      gubId,
    ).map((budgets) => budgets.where((budget) => budget.isCompleted).toList());
  }

  Future<void> deleteSharedBudget({
    required String gubId,
    required String sharedBudgetId,
  }) async {
    await GubRepository.instance.ensureActive(gubId);
    if (!await canDeleteSharedBudget(
      gubId: gubId,
      sharedBudgetId: sharedBudgetId,
    )) {
      throw StateError(
        "You don't have permission to delete this Shared Budget.",
      );
    }
    await SharedBudgetRepository.instance.deleteSharedBudget(
      gubId,
      sharedBudgetId,
    );
  }

  Future<bool> canDeleteSharedBudget({
    required String gubId,
    required String sharedBudgetId,
  }) {
    return SharedBudgetRepository.instance.canDeleteSharedBudget(
      gubId: gubId,
      sharedBudgetId: sharedBudgetId,
    );
  }

  Future<DeletionContext> deletionContext({
    required String gubId,
    required String sharedBudgetId,
  }) {
    return SharedBudgetRepository.instance.deletionContext(
      gubId: gubId,
      sharedBudgetId: sharedBudgetId,
    );
  }

  Future<SharedBudgetModel?> getSharedBudgetById({
    required String gubId,
    required String sharedBudgetId,
  }) {
    return SharedBudgetRepository.instance.getSharedBudget(
      gubId,
      sharedBudgetId,
    );
  }

  Stream<SharedBudgetModel?> sharedBudgetStream({
    required String gubId,
    required String sharedBudgetId,
  }) {
    return SharedBudgetRepository.instance.sharedBudgetStream(
      gubId,
      sharedBudgetId,
    );
  }

  ({String title, String description}) _validate(
    String title,
    String description,
    double targetAmount,
  ) {
    final normalizedTitle = title.trim();
    final normalizedDescription = description.trim();

    if (normalizedTitle.isEmpty) {
      throw ArgumentError("Please enter a title.");
    }

    if (normalizedTitle.length > 100) {
      throw ArgumentError("The title cannot exceed 100 characters.");
    }

    if (normalizedDescription.length > 500) {
      throw ArgumentError("The description cannot exceed 500 characters.");
    }

    if (!targetAmount.isFinite ||
        targetAmount <= 0 ||
        !_hasAtMostTwoDecimalPlaces(targetAmount)) {
      throw ArgumentError("Please enter a valid target amount.");
    }

    return (title: normalizedTitle, description: normalizedDescription);
  }

  bool _hasAtMostTwoDecimalPlaces(double value) {
    final valueInCents = value * 100;
    return (valueInCents - valueInCents.round()).abs() < 0.0000001;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _loadHubMembers(
    String gubId,
  ) async {
    final snapshot = await _firestore
        .collection("gubs")
        .doc(gubId)
        .collection("members")
        .get();

    return snapshot.docs;
  }

  Future<User> _requireAuthorizedCreator(String gubId) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError("You must be signed in to create a Shared Budget.");
    }

    final gubDocument = await _firestore.collection("gubs").doc(gubId).get();

    if (!gubDocument.exists) {
      throw StateError("Gub not found.");
    }

    final ownerId = gubDocument.data()?["ownerId"] ?? "";

    if (ownerId != user.uid) {
      throw StateError("Only Gub administrators can create a Shared Budget.");
    }

    return user;
  }

  SharedBudgetModel _buildSharedBudget({
    required String creatorId,
    required String title,
    required String description,
    required double targetAmount,
    required int memberCount,
    DateTime? deadline,
    String? sourceType,
    String? sourceId,
    String? sourcePreview,
    String? originUserId,
    String? sourceAuthorName,
  }) {
    return SharedBudgetModel(
      sharedBudgetId: _generateSharedBudgetId(),
      title: title,
      description: description,
      targetAmount: targetAmount,
      currentAmount: 0,
      ownerId: creatorId,
      completedMembers: 0,
      totalMembers: memberCount,
      status: "active",
      archived: false,
      createdAt: Timestamp.now(),
      deadline: deadline == null ? null : Timestamp.fromDate(deadline),
      sourceType: sourceType,
      sourceId: sourceId,
      sourcePreview: sourcePreview,
      originUserId: originUserId,
      sourceAuthorName: sourceAuthorName,
    );
  }

  String _generateSharedBudgetId() {
    final random = Random();

    return DateTime.now().millisecondsSinceEpoch.toString() +
        random.nextInt(999).toString();
  }
}
