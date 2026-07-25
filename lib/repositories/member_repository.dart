import 'package:cloud_firestore/cloud_firestore.dart';

class MemberRepository {
  MemberRepository._();

  static final MemberRepository instance = MemberRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getMember({
    required String gubId,
    required String uid,
  }) async {
    final document = await _firestore
        .collection("gubs")
        .doc(gubId)
        .collection("members")
        .doc(uid)
        .get();

    return document.data();
  }

  Future<void> removeMember({
    required String gubId,
    required String uid,
  }) async {
    final batch = _firestore.batch();

    // Rimuove il membro dal gruppo
    batch.delete(
      _firestore.collection("gubs").doc(gubId).collection("members").doc(uid),
    );

    // Rimuove il gruppo dalla lista personale dell'utente
    batch.delete(
      _firestore.collection("users").doc(uid).collection("gubs").doc(gubId),
    );

    await batch.commit();
  }

  Future<void> updateMemberCount({
    required String gubId,
    required int memberCount,
  }) async {
    await _firestore.collection("gubs").doc(gubId).update({
      "memberCount": memberCount,
    });
  }

  Future<int> getMemberCount(String gubId) async {
    final snapshot = await _firestore
        .collection("gubs")
        .doc(gubId)
        .collection("members")
        .get();

    return snapshot.docs.length;
  }
}
