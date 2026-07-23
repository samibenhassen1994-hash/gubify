import 'dart:developer' as developer;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/goal_member_model.dart';
import '../models/goal_model.dart';
import '../../../repositories/goal_repository.dart';
import '../../notifications/services/notification_service.dart';

class GoalService {
  GoalService._();

  static final GoalService instance = GoalService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createGoal({
    required String gubId,
    required String title,
    required String description,
    required double targetAmount,
    DateTime? deadline,
  }) async {
    final creator = await _requireAuthorizedCreator(gubId);
    final normalizedValues = _validate(title, description, targetAmount);
    final members = await _loadHubMembers(gubId);

    final goal = _buildGoal(
      creatorId: creator.uid,
      title: normalizedValues.title,
      description: normalizedValues.description,
      targetAmount: targetAmount,
      memberCount: members.length,
      deadline: deadline,
    );

    await GoalRepository.instance.createGoal(gubId, goal);

    final goalMembers = members
        .map(
          (member) => GoalMemberModel(
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

    await GoalRepository.instance.createGoalMembers(
      gubId: gubId,
      goalId: goal.goalId,
      members: goalMembers,
    );

    var creatorName = creator.displayName ?? "Administrator";

    for (final member in members) {
      if (member["uid"] == creator.uid) {
        creatorName = member["displayName"] ?? creatorName;
        break;
      }
    }

    try {
      await NotificationService.instance.send(
        gubId: gubId,
        title: "New Shared Budget",
        body: "$creatorName created “${goal.title}”.",
        type: "goal_created",
        senderId: creator.uid,
        senderName: creatorName,
        markSenderAsRead: true,
        data: {"module": "goals", "gubId": gubId, "goalId": goal.goalId},
      );
    } catch (error, stackTrace) {
      developer.log(
        "Unable to send the Shared Budget creation notification.",
        name: "GoalService.createGoal",
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Future (lo lasciamo per compatibilità)
  Future<GoalModel?> getActiveGoal(String gubId) {
    return GoalRepository.instance.getActiveGoal(gubId);
  }

  /// Stream in tempo reale
  Stream<List<GoalModel>> activeGoalsStream(String gubId) {
    return GoalRepository.instance.activeGoalsStream(gubId);
  }

  Stream<List<GoalModel>> goalsStream(String gubId) {
    return GoalRepository.instance.goalsStream(gubId);
  }

  Stream<List<GoalModel>> completedGoalsStream(String gubId) {
    return GoalRepository.instance.completedGoalsStream(gubId);
  }

  Future<void> deleteGoal({required String gubId, required String goalId}) {
    return GoalRepository.instance.deleteGoal(gubId, goalId);
  }

  Future<GoalModel?> getGoalById({
    required String gubId,
    required String goalId,
  }) {
    return GoalRepository.instance.getGoal(gubId, goalId);
  }

  Stream<GoalModel?> goalStream({
    required String gubId,
    required String goalId,
  }) {
    return GoalRepository.instance.goalStream(gubId, goalId);
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

  GoalModel _buildGoal({
    required String creatorId,
    required String title,
    required String description,
    required double targetAmount,
    required int memberCount,
    DateTime? deadline,
  }) {
    return GoalModel(
      goalId: _generateGoalId(),
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
    );
  }

  String _generateGoalId() {
    final random = Random();

    return DateTime.now().millisecondsSinceEpoch.toString() +
        random.nextInt(999).toString();
  }
}
