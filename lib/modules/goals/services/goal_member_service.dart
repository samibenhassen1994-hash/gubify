import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../repositories/goal_member_repository.dart';
import '../../../repositories/goal_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../notifications/services/notification_service.dart';

class GoalMemberService {
  GoalMemberService._();

  static final GoalMemberService instance =
      GoalMemberService._();

  Stream<QuerySnapshot<Map<String, dynamic>>> membersStream({
    required String hubId,
    required String goalId,
  }) {
    return GoalMemberRepository.instance.membersStream(
      hubId: hubId,
      goalId: goalId,
    );
  }

  Future<void> submitContribution({
    required String hubId,
    required String goalId,
    required String uid,
    required double amount,
  }) async {
    if (amount <= 0) {
      throw Exception(
        "Contribution must be greater than zero.",
      );
    }

    await GoalMemberRepository.instance.updateContribution(
      hubId: hubId,
      goalId: goalId,
      uid: uid,
      amount: amount,
    );

    await NotificationService.instance.send(
      hubId: hubId,
      title: "Contribution submitted",
      body: "A member submitted a contribution.",
      type: "goal_submitted",
      senderId: uid,
      senderName: "System",
      data: {
        "goalId": goalId,
        "memberId": uid,
      },
    );
  }

  Future<void> confirmContribution({
    required String hubId,
    required String goalId,
    required String uid,
    required String confirmedById,
  }) async {
    final firestore = FirebaseFirestore.instance;

    // Recupera il membro
    final memberDoc = await firestore
        .collection("hubs")
        .doc(hubId)
        .collection("goals")
        .doc(goalId)
        .collection("members")
        .doc(uid)
        .get();

    if (!memberDoc.exists) {
      throw Exception("Member not found.");
    }

    final memberData = memberDoc.data()!;

    final memberName =
        memberData["displayName"] ?? "Member";

    final amount =
        (memberData["amount"] ?? 0).toDouble();

    // Recupera il nome dell'amministratore
    final owner =
        await UserRepository.instance.getUser(
      confirmedById,
    );

    final ownerName =
        owner?["displayName"] ?? "Administrator";

    // Conferma il contributo
    await GoalMemberRepository.instance
        .confirmContribution(
      hubId: hubId,
      goalId: goalId,
      uid: uid,
    );

    // Aggiorna il budget
    await GoalRepository.instance
        .recalculateGoalProgress(
      hubId: hubId,
      goalId: goalId,
    );

    // Notifica
    await NotificationService.instance.send(
      hubId: hubId,
      title: "Shared Budget",
      body:
          "$ownerName confirmed $memberName's contribution (€${amount.toStringAsFixed(2)}).",
      type: "goal_confirmation",
      senderId: confirmedById,
      senderName: ownerName,
      data: {
        "goalId": goalId,
        "memberId": uid,
      },
    );
  }
}