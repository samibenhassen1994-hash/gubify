import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SharedBudgetMemberRepository {
  SharedBudgetMemberRepository._();

  static final SharedBudgetMemberRepository instance =
      SharedBudgetMemberRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // The `goals` collection is a legacy Firestore path for Shared Budgets.

  Stream<QuerySnapshot<Map<String, dynamic>>> membersStream({
    required String gubId,
    required String sharedBudgetId,
  }) {
    return _firestore
        .collection("gubs")
        .doc(gubId)
        .collection("goals")
        .doc(sharedBudgetId)
        .collection("members")
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> memberStream({
    required String gubId,
    required String sharedBudgetId,
    required String uid,
  }) {
    return _firestore
        .collection("gubs")
        .doc(gubId)
        .collection("goals")
        .doc(sharedBudgetId)
        .collection("members")
        .doc(uid)
        .snapshots();
  }

  Future<void> updateContribution({
    required String gubId,
    required String sharedBudgetId,
    required String uid,
    required double amount,
  }) async {
    final currentUserId = _auth.currentUser?.uid;

    if (currentUserId == null || currentUserId != uid) {
      throw StateError("You can only update your own contribution.");
    }

    final sharedBudgetReference = _firestore
        .collection("gubs")
        .doc(gubId)
        .collection("goals")
        .doc(sharedBudgetId);
    final memberReference = sharedBudgetReference
        .collection("members")
        .doc(uid);

    await _firestore.runTransaction((transaction) async {
      final gubSnapshot = await transaction.get(
        _firestore.collection('gubs').doc(gubId),
      );
      final sharedBudgetSnapshot = await transaction.get(sharedBudgetReference);
      final memberSnapshot = await transaction.get(memberReference);

      if (!gubSnapshot.exists ||
          gubSnapshot.data()?['deletionStatus'] == 'deleting') {
        throw StateError('This Gub is no longer available.');
      }
      if (!sharedBudgetSnapshot.exists) {
        throw StateError("Shared Budget not found.");
      }

      if (!memberSnapshot.exists) {
        throw StateError("Member not found.");
      }

      final sharedBudgetData = sharedBudgetSnapshot.data()!;
      final memberData = memberSnapshot.data()!;
      final targetAmount =
          (sharedBudgetData["targetAmount"] as num?)?.toDouble() ?? 0;
      final currentAmount =
          (sharedBudgetData["currentAmount"] as num?)?.toDouble() ?? 0;
      final status = sharedBudgetData["status"] ?? "active";
      final archived = sharedBudgetData["archived"] ?? false;
      final alreadyConfirmed = memberData["confirmed"] ?? false;
      final remainingAmount = (targetAmount - currentAmount)
          .clamp(0.0, double.infinity)
          .toDouble();

      final amountInCents = amount * 100;

      if (!amount.isFinite ||
          amount <= 0 ||
          (amountInCents - amountInCents.round()).abs() >= 0.0000001) {
        throw ArgumentError("Contribution must be greater than zero.");
      }

      if (!targetAmount.isFinite || targetAmount <= 0) {
        throw StateError("This Shared Budget has an invalid target amount.");
      }

      if (!currentAmount.isFinite ||
          currentAmount < 0 ||
          currentAmount > targetAmount) {
        throw StateError("This Shared Budget has an invalid current amount.");
      }

      if (status == "completed" || archived || remainingAmount <= 0) {
        throw StateError("This Shared Budget is already completed.");
      }

      if (alreadyConfirmed) {
        throw StateError("A confirmed contribution can no longer be changed.");
      }

      final amountCents = (amount * 100).round();
      final remainingCents = (remainingAmount * 100).round();

      if (amountCents > remainingCents) {
        throw StateError(
          "You can contribute up to €${remainingAmount.toStringAsFixed(2)}.",
        );
      }

      transaction.update(memberReference, {
        "amount": amount,
        "confirmed": false,
        "updatedAt": FieldValue.serverTimestamp(),
        "confirmedAt": null,
      });
    });
  }

  Future<({String memberName, double amount})> confirmContribution({
    required String gubId,
    required String sharedBudgetId,
    required String uid,
    required String confirmedById,
  }) async {
    final currentUserId = _auth.currentUser?.uid;

    if (currentUserId == null || currentUserId != confirmedById) {
      throw StateError("You are not authorized to confirm this contribution.");
    }

    final gubReference = _firestore.collection("gubs").doc(gubId);
    final sharedBudgetReference = gubReference
        .collection("goals")
        .doc(sharedBudgetId);
    final memberReference = sharedBudgetReference
        .collection("members")
        .doc(uid);

    return _firestore.runTransaction((transaction) async {
      final gubSnapshot = await transaction.get(gubReference);
      final sharedBudgetSnapshot = await transaction.get(sharedBudgetReference);
      final memberSnapshot = await transaction.get(memberReference);

      if (!gubSnapshot.exists) {
        throw StateError("Gub not found.");
      }
      if (gubSnapshot.data()?['deletionStatus'] == 'deleting') {
        throw StateError('This Gub is no longer available.');
      }

      if (!sharedBudgetSnapshot.exists) {
        throw StateError("Shared Budget not found.");
      }

      if (!memberSnapshot.exists) {
        throw StateError("Member not found.");
      }

      final gubOwnerId = gubSnapshot.data()?["ownerId"] ?? "";

      if (currentUserId != gubOwnerId) {
        throw StateError("Only the Gub owner can confirm a contribution.");
      }

      final sharedBudgetData = sharedBudgetSnapshot.data()!;
      final memberData = memberSnapshot.data()!;
      final memberName = memberData["displayName"] is String
          ? memberData["displayName"] as String
          : "Member";
      final confirmed = memberData["confirmed"] ?? false;
      final memberAmount = (memberData["amount"] as num?)?.toDouble() ?? 0;
      final targetAmount =
          (sharedBudgetData["targetAmount"] as num?)?.toDouble() ?? 0;
      final currentAmount =
          (sharedBudgetData["currentAmount"] as num?)?.toDouble() ?? 0;
      final completedMembers =
          (sharedBudgetData["completedMembers"] as num?)?.toInt() ?? 0;
      final status = sharedBudgetData["status"] ?? "active";
      final archived = sharedBudgetData["archived"] ?? false;

      if (confirmed) {
        throw StateError("This contribution has already been confirmed.");
      }

      if (status == "completed" || currentAmount >= targetAmount) {
        throw StateError("This Shared Budget is already completed.");
      }

      if (archived) {
        throw StateError("Archived Shared Budgets cannot be updated.");
      }

      if (!memberAmount.isFinite || memberAmount <= 0) {
        throw StateError("The contribution amount must be greater than zero.");
      }

      if (!targetAmount.isFinite || targetAmount <= 0) {
        throw StateError("This Shared Budget has an invalid target amount.");
      }

      if (!currentAmount.isFinite ||
          currentAmount < 0 ||
          currentAmount > targetAmount) {
        throw StateError("This Shared Budget has an invalid current amount.");
      }

      final targetCents = (targetAmount * 100).round();
      final currentCents = (currentAmount * 100).round();
      final memberCents = (memberAmount * 100).round();
      final remainingCents = targetCents - currentCents;

      if (memberCents > remainingCents) {
        throw StateError(
          "This contribution exceeds the remaining Shared Budget amount. "
          "The member must update the contribution.",
        );
      }

      final newCurrentCents = currentCents + memberCents;
      final newCurrentAmount = newCurrentCents / 100;
      final isCompleted = newCurrentCents == targetCents;
      final now = FieldValue.serverTimestamp();

      transaction.update(memberReference, {
        "confirmed": true,
        "confirmedAt": now,
      });
      transaction.update(sharedBudgetReference, {
        "currentAmount": newCurrentAmount,
        "completedMembers": completedMembers + 1,
        if (isCompleted) ...{
          "status": "completed",
          "archived": false,
          "completedAt": now,
        },
      });

      return (memberName: memberName, amount: memberAmount);
    });
  }
}
