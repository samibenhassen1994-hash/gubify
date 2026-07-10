import 'package:cloud_firestore/cloud_firestore.dart';

class MemberRepository {
  MemberRepository._();

  static final MemberRepository instance =
      MemberRepository._();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Future<void> removeMember({
    required String hubId,
    required String uid,
  }) async {
    final batch = _firestore.batch();

    // Rimuove il membro dal gruppo
    batch.delete(
      _firestore
          .collection("hubs")
          .doc(hubId)
          .collection("members")
          .doc(uid),
    );

    // Rimuove il gruppo dalla lista personale dell'utente
    batch.delete(
      _firestore
          .collection("users")
          .doc(uid)
          .collection("hubs")
          .doc(hubId),
    );

    await batch.commit();
  }

  Future<void> updateMemberCount({
    required String hubId,
    required int memberCount,
  }) async {
    await _firestore
        .collection("hubs")
        .doc(hubId)
        .update({
      "memberCount": memberCount,
    });
  }

  Future<int> getMemberCount(
    String hubId,
  ) async {
    final snapshot = await _firestore
        .collection("hubs")
        .doc(hubId)
        .collection("members")
        .get();

    return snapshot.docs.length;
  }
}