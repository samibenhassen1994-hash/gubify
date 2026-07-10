import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/goal_member_model.dart';
import '../models/goal_model.dart';
import '../../../repositories/goal_repository.dart';

class GoalService {
  GoalService._();

  static final GoalService instance = GoalService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createGoal({
    required String hubId,
    required String title,
    required String description,
    required double targetAmount,
    DateTime? deadline,
  }) async {
    _validate(title, targetAmount);

    final members = await _loadHubMembers(hubId);

    final goal = _buildGoal(
      title: title,
      description: description,
      targetAmount: targetAmount,
      memberCount: members.length,
      deadline: deadline,
    );

    await GoalRepository.instance.createGoal(
      hubId,
      goal,
    );

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
      hubId: hubId,
      goalId: goal.goalId,
      members: goalMembers,
    );
  }

  /// Future (lo lasciamo per compatibilità)
  Future<GoalModel?> getActiveGoal(
    String hubId,
  ) {
    return GoalRepository.instance.getActiveGoal(hubId);
  }

  /// Stream in tempo reale
  Stream<GoalModel?> activeGoalStream(
    String hubId,
  ) {
    return GoalRepository.instance.activeGoalStream(
      hubId,
    );
  }

  void _validate(
    String title,
    double targetAmount,
  ) {
    if (title.trim().isEmpty) {
      throw Exception("Goal title is required.");
    }

    if (targetAmount <= 0) {
      throw Exception("Invalid target amount.");
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _loadHubMembers(
    String hubId,
  ) async {
    final snapshot = await _firestore
        .collection("hubs")
        .doc(hubId)
        .collection("members")
        .get();

    return snapshot.docs;
  }

  GoalModel _buildGoal({
    required String title,
    required String description,
    required double targetAmount,
    required int memberCount,
    DateTime? deadline,
  }) {
    final user = _auth.currentUser!;

    return GoalModel(
      goalId: _generateGoalId(),
      title: title,
      description: description,
      targetAmount: targetAmount,
      currentAmount: 0,
      ownerId: user.uid,
      completedMembers: 0,
      totalMembers: memberCount,
      status: "active",
      archived: false,
      createdAt: Timestamp.now(),
      deadline: deadline == null
          ? null
          : Timestamp.fromDate(deadline),
    );
  }

  String _generateGoalId() {
    final random = Random();

    return DateTime.now().millisecondsSinceEpoch.toString() +
        random.nextInt(999).toString();
  }
}