import 'package:cloud_firestore/cloud_firestore.dart';

class GoalMemberRepository {
  GoalMemberRepository._();

  static final GoalMemberRepository instance = GoalMemberRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> membersStream({
    required String hubId,
    required String goalId,
  }) {
    return _firestore
        .collection("gubs")
        .doc(hubId)
        .collection("goals")
        .doc(goalId)
        .collection("members")
        .snapshots();
  }

  Future<void> updateContribution({
    required String hubId,
    required String goalId,
    required String uid,
    required double amount,
  }) async {
    await _firestore
        .collection("gubs")
        .doc(hubId)
        .collection("goals")
        .doc(goalId)
        .collection("members")
        .doc(uid)
        .update({
          "amount": amount,
          "confirmed": false,
          "updatedAt": Timestamp.now(),
          "confirmedAt": null,
        });
  }

  Future<void> confirmContribution({
    required String hubId,
    required String goalId,
    required String uid,
  }) async {
    await _firestore
        .collection("gubs")
        .doc(hubId)
        .collection("goals")
        .doc(goalId)
        .collection("members")
        .doc(uid)
        .update({"confirmed": true, "confirmedAt": Timestamp.now()});
  }
}
