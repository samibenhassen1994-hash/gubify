import 'package:cloud_firestore/cloud_firestore.dart';

class InviteTokenData {
  final String code;
  final String gubId;
  final String ownerId;
  final String gubName;
  final bool active;

  const InviteTokenData({
    required this.code,
    required this.gubId,
    required this.ownerId,
    required this.gubName,
    required this.active,
  });

  factory InviteTokenData.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return InviteTokenData(
      code: snapshot.id,
      gubId: data['gubId'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
      gubName: data['gubName'] as String? ?? '',
      active: data['active'] == true,
    );
  }

  bool get isUsable =>
      active && gubId.isNotEmpty && ownerId.isNotEmpty && gubName.isNotEmpty;
}

class GubInviteRepository {
  GubInviteRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  String newGubId() => _firestore.collection('gubs').doc().id;

  Future<Duration?> inviteRegenerationCooldown(String gubId) async {
    final snapshot = await _firestore.collection('gubs').doc(gubId).get();
    final regeneratedAt = snapshot.data()?['inviteRegeneratedAt'];
    if (regeneratedAt is! Timestamp) return null;
    final remaining = regeneratedAt
        .toDate()
        .add(const Duration(seconds: 60))
        .difference(DateTime.now());
    return remaining > Duration.zero ? remaining : null;
  }

  Future<bool> tryCreateGubWithToken({
    required String gubId,
    required String name,
    required String ownerId,
    required String displayName,
    required String? photoUrl,
    required String canonicalCode,
  }) {
    final tokenReference = _firestore
        .collection('inviteTokens')
        .doc(canonicalCode);
    final gubReference = _firestore.collection('gubs').doc(gubId);
    final ownerMembership = gubReference.collection('members').doc(ownerId);
    final ownerCopy = _firestore
        .collection('users')
        .doc(ownerId)
        .collection('gubs')
        .doc(gubId);

    return _firestore.runTransaction<bool>((transaction) async {
      final token = await transaction.get(tokenReference);
      if (token.exists) return false;

      transaction.set(tokenReference, {
        'gubId': gubId,
        'ownerId': ownerId,
        'gubName': name,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(gubReference, {
        'gubId': gubId,
        'name': name,
        'ownerId': ownerId,
        'inviteTokenId': canonicalCode,
        'memberCount': 1,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(ownerMembership, {
        'uid': ownerId,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'role': 'owner',
        'joinedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(ownerCopy, {
        'gubId': gubId,
        'name': name,
        'ownerId': ownerId,
        'role': 'owner',
        'joinedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  Future<InviteTokenData?> getToken(String canonicalCode) async {
    final snapshot = await _firestore
        .collection('inviteTokens')
        .doc(canonicalCode)
        .get();
    return snapshot.exists ? InviteTokenData.fromSnapshot(snapshot) : null;
  }

  Future<bool> tryRegenerateInvite({
    required String gubId,
    required String ownerId,
    required String canonicalCode,
  }) {
    final gubReference = _firestore.collection('gubs').doc(gubId);
    final newTokenReference = _firestore
        .collection('inviteTokens')
        .doc(canonicalCode);
    return _firestore.runTransaction((transaction) async {
      final gub = await transaction.get(gubReference);
      final newToken = await transaction.get(newTokenReference);
      if (!gub.exists ||
          gub.data()?['ownerId'] != ownerId ||
          gub.data()?['deletionStatus'] == 'deleting' ||
          newToken.exists) {
        return false;
      }
      final oldCode = gub.data()?['inviteTokenId'] as String?;
      final name = gub.data()?['name'] as String?;
      if (oldCode == null || oldCode == canonicalCode || name == null) {
        return false;
      }
      final oldTokenReference = _firestore
          .collection('inviteTokens')
          .doc(oldCode);
      final oldToken = await transaction.get(oldTokenReference);
      if (!oldToken.exists || oldToken.data()?['active'] != true) return false;
      transaction.set(newTokenReference, {
        'gubId': gubId,
        'ownerId': ownerId,
        'gubName': name,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(oldTokenReference, {'active': false});
      transaction.update(gubReference, {
        'inviteTokenId': canonicalCode,
        'inviteRegeneratedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  Future<Map<String, dynamic>?> getOwnMembership({
    required String gubId,
    required String userId,
  }) async {
    final snapshot = await _firestore
        .collection('gubs')
        .doc(gubId)
        .collection('members')
        .doc(userId)
        .get();
    return snapshot.data();
  }

  Future<Map<String, dynamic>?> getOwnCopy({
    required String gubId,
    required String userId,
  }) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('gubs')
        .doc(gubId)
        .get();
    return snapshot.data();
  }

  Future<bool> isUserBanned({
    required String gubId,
    required String userId,
  }) async {
    final snapshot = await _firestore
        .collection('gubs')
        .doc(gubId)
        .collection('bans')
        .doc(userId)
        .get();
    return snapshot.exists;
  }

  Future<void> joinWithToken({
    required InviteTokenData token,
    required String userId,
    required String displayName,
    required String? photoUrl,
  }) async {
    final gubReference = _firestore.collection('gubs').doc(token.gubId);
    final membership = gubReference.collection('members').doc(userId);
    final userCopy = _firestore
        .collection('users')
        .doc(userId)
        .collection('gubs')
        .doc(token.gubId);
    final batch = _firestore.batch();

    batch.update(gubReference, {'memberCount': FieldValue.increment(1)});
    batch.set(membership, {
      'uid': userId,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'role': 'member',
      'joinedAt': FieldValue.serverTimestamp(),
      'joinedViaInviteToken': token.code,
    });
    batch.set(userCopy, {
      'gubId': token.gubId,
      'name': token.gubName,
      'ownerId': token.ownerId,
      'role': 'member',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}
