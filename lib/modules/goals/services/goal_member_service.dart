import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../repositories/goal_member_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../notifications/services/notification_service.dart';

class GoalMemberService {
  GoalMemberService._();

  static final GoalMemberService instance = GoalMemberService._();

  Stream<QuerySnapshot<Map<String, dynamic>>> membersStream({
    required String gubId,
    required String goalId,
  }) {
    return GoalMemberRepository.instance.membersStream(
      gubId: gubId,
      goalId: goalId,
    );
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> memberStream({
    required String gubId,
    required String goalId,
    required String uid,
  }) {
    return GoalMemberRepository.instance.memberStream(
      gubId: gubId,
      goalId: goalId,
      uid: uid,
    );
  }

  Future<void> submitContribution({
    required String gubId,
    required String goalId,
    required String uid,
    required double amount,
  }) async {
    final amountInCents = amount * 100;

    if (!amount.isFinite ||
        amount <= 0 ||
        (amountInCents - amountInCents.round()).abs() >= 0.0000001) {
      throw ArgumentError("Contribution must be greater than zero.");
    }

    await GoalMemberRepository.instance.updateContribution(
      gubId: gubId,
      goalId: goalId,
      uid: uid,
      amount: amount,
    );

    await NotificationService.instance.send(
      gubId: gubId,
      title: "Contribution submitted",
      body: "A member submitted a contribution.",
      type: "goal_submitted",
      senderId: uid,
      senderName: "System",
      data: {"goalId": goalId, "memberId": uid},
    );
  }

  Future<void> confirmContribution({
    required String gubId,
    required String goalId,
    required String uid,
    required String confirmedById,
  }) async {
    final owner = await UserRepository.instance.getUser(confirmedById);
    final ownerName = owner?["displayName"] ?? "Administrator";

    final confirmedContribution = await GoalMemberRepository.instance
        .confirmContribution(
          gubId: gubId,
          goalId: goalId,
          uid: uid,
          confirmedById: confirmedById,
        );

    await NotificationService.instance.send(
      gubId: gubId,
      title: "Shared Budget",
      body:
          "$ownerName confirmed ${confirmedContribution.memberName}'s "
          "contribution (€${confirmedContribution.amount.toStringAsFixed(2)}).",
      type: "goal_confirmation",
      senderId: confirmedById,
      senderName: ownerName,
      data: {"goalId": goalId, "memberId": uid},
    );
  }
}
