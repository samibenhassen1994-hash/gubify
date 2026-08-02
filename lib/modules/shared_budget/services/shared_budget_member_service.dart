import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../repositories/shared_budget_member_repository.dart';
import '../../../repositories/gub_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../notifications/services/notification_service.dart';

class SharedBudgetMemberService {
  SharedBudgetMemberService._();

  static final SharedBudgetMemberService instance =
      SharedBudgetMemberService._();

  Stream<QuerySnapshot<Map<String, dynamic>>> membersStream({
    required String gubId,
    required String sharedBudgetId,
  }) {
    return SharedBudgetMemberRepository.instance.membersStream(
      gubId: gubId,
      sharedBudgetId: sharedBudgetId,
    );
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> memberStream({
    required String gubId,
    required String sharedBudgetId,
    required String uid,
  }) {
    return SharedBudgetMemberRepository.instance.memberStream(
      gubId: gubId,
      sharedBudgetId: sharedBudgetId,
      uid: uid,
    );
  }

  Future<void> submitContribution({
    required String gubId,
    required String sharedBudgetId,
    required String uid,
    required double amount,
  }) async {
    await GubRepository.instance.ensureActive(gubId);
    final amountInCents = amount * 100;

    if (!amount.isFinite ||
        amount <= 0 ||
        (amountInCents - amountInCents.round()).abs() >= 0.0000001) {
      throw ArgumentError("Contribution must be greater than zero.");
    }

    await SharedBudgetMemberRepository.instance.updateContribution(
      gubId: gubId,
      sharedBudgetId: sharedBudgetId,
      uid: uid,
      amount: amount,
    );

    // Legacy notification type and payload field are preserved.
    await NotificationService.instance.send(
      gubId: gubId,
      title: "Contribution submitted",
      body: "A member submitted a contribution.",
      type: "goal_submitted",
      senderId: uid,
      senderName: "System",
      data: {"goalId": sharedBudgetId, "memberId": uid},
    );
  }

  Future<void> confirmContribution({
    required String gubId,
    required String sharedBudgetId,
    required String uid,
    required String confirmedById,
  }) async {
    await GubRepository.instance.ensureActive(gubId);
    final owner = await UserRepository.instance.getUser(confirmedById);
    final ownerName = owner?["displayName"] ?? "Administrator";

    final confirmedContribution = await SharedBudgetMemberRepository.instance
        .confirmContribution(
          gubId: gubId,
          sharedBudgetId: sharedBudgetId,
          uid: uid,
          confirmedById: confirmedById,
        );

    // Legacy notification type and payload field are preserved.
    await NotificationService.instance.send(
      gubId: gubId,
      title: "Shared Budget",
      body:
          "$ownerName confirmed ${confirmedContribution.memberName}'s "
          "contribution (€${confirmedContribution.amount.toStringAsFixed(2)}).",
      type: "goal_confirmation",
      senderId: confirmedById,
      senderName: ownerName,
      data: {"goalId": sharedBudgetId, "memberId": uid},
    );
  }
}
