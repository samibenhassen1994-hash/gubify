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

  Stream<QuerySnapshot<Map<String, dynamic>>> membersStream(String gubId) =>
      _firestore
          .collection('gubs')
          .doc(gubId)
          .collection('members')
          .snapshots();

  Stream<List<Map<String, dynamic>>> bannedUsersStream(String gubId) =>
      _firestore
          .collection('gubs')
          .doc(gubId)
          .collection('bans')
          .snapshots()
          .asyncMap(
            (snapshot) => Future.wait(
              snapshot.docs.map((document) async {
                final data = <String, dynamic>{
                  ...document.data(),
                  'uid': document.id,
                };
                final name = data['displayName'];
                if (name is String && name.trim().isNotEmpty) return data;
                final profile = await _firestore
                    .collection('users')
                    .doc(document.id)
                    .get();
                final profileName = profile.data()?['displayName'];
                if (profileName is String && profileName.trim().isNotEmpty) {
                  data['displayName'] = profileName.trim();
                }
                return data;
              }),
            ),
          );

  Future<void> removeMember({
    required String gubId,
    required String uid,
    required String actorId,
  }) async {
    final gubReference = _firestore.collection("gubs").doc(gubId);
    final memberReference = gubReference.collection("members").doc(uid);
    final userGubReference = _firestore
        .collection("users")
        .doc(uid)
        .collection("gubs")
        .doc(gubId);

    await _firestore.runTransaction((transaction) async {
      final gub = await transaction.get(gubReference);
      final member = await transaction.get(memberReference);
      if (!gub.exists || gub.data()?['deletionStatus'] == 'deleting') {
        throw StateError('This Gub is no longer available.');
      }
      if (!member.exists) {
        throw StateError('This member is no longer in the Gub.');
      }

      final ownerId = gub.data()?['ownerId'] as String?;
      if (ownerId == null || uid == ownerId) {
        throw StateError('The Gub owner cannot leave or be removed.');
      }
      if (actorId != uid && actorId != ownerId) {
        throw StateError('Only the Gub owner can remove members.');
      }

      final memberCount = (gub.data()?['memberCount'] as num?)?.toInt() ?? 1;
      transaction.delete(memberReference);
      transaction.delete(userGubReference);
      transaction.update(gubReference, {
        'memberCount': (memberCount - 1).clamp(1, memberCount),
      });
    });
  }

  Future<void> banMember({
    required String gubId,
    required String uid,
    required String ownerId,
  }) async {
    final gubReference = _firestore.collection('gubs').doc(gubId);
    final memberReference = gubReference.collection('members').doc(uid);
    final banReference = gubReference.collection('bans').doc(uid);
    final copyReference = _firestore
        .collection('users')
        .doc(uid)
        .collection('gubs')
        .doc(gubId);
    await _firestore.runTransaction((transaction) async {
      final gub = await transaction.get(gubReference);
      final member = await transaction.get(memberReference);
      if (!gub.exists || gub.data()?['ownerId'] != ownerId || !member.exists) {
        throw StateError('This member is no longer available.');
      }
      if (uid == ownerId) throw StateError('The Gub owner cannot be banned.');
      final count = (gub.data()?['memberCount'] as num?)?.toInt() ?? 1;
      transaction.set(banReference, {
        'userId': uid,
        'displayName': member.data()?['displayName'] ?? 'User',
        'photoUrl': member.data()?['photoUrl'],
        'bannedBy': ownerId,
        'bannedAt': FieldValue.serverTimestamp(),
      });
      transaction.delete(memberReference);
      transaction.delete(copyReference);
      transaction.update(gubReference, {
        'memberCount': (count - 1).clamp(1, count),
      });
    });
  }

  Future<void> unbanMember({required String gubId, required String uid}) =>
      _firestore
          .collection('gubs')
          .doc(gubId)
          .collection('bans')
          .doc(uid)
          .delete();

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
