import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../modules/goals/models/goal_model.dart';
import '../repositories/goal_repository.dart';

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

    final amountPerMember = _calculateAmountPerMember(
      targetAmount,
      members.length,
    );

    final goal = _buildGoal(
      title: title,
      description: description,
      targetAmount: targetAmount,
      amountPerMember: amountPerMember,
      memberCount: members.length,
      deadline: deadline,
    );

    await _saveGoal(
      hubId,
      goal,
    );

    // La creazione dei GoalMember
    // arriverà nello step successivo.
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

  double _calculateAmountPerMember(
    double amount,
    int members,
  ) {
    if (members == 0) return amount;

    return amount / members;
  }

  GoalModel _buildGoal({
    required String title,
    required String description,
    required double targetAmount,
    required double amountPerMember,
    required int memberCount,
    DateTime? deadline,
  }) {
    final user = _auth.currentUser!;

    final goalId = _generateGoalId();

    return GoalModel(
      goalId: goalId,
      title: title,
      description: description,
      targetAmount: targetAmount,
      amountPerMember: amountPerMember,
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

  Future<void> _saveGoal(
    String hubId,
    GoalModel goal,
  ) async {
    await GoalRepository.instance.createGoal(
      hubId,
      goal,
    );
  }

  String _generateGoalId() {
    final random = Random();

    return DateTime.now().millisecondsSinceEpoch.toString() +
        random.nextInt(999).toString();
  }
}