import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_block_model.dart';

abstract interface class UserBlockRepository {
  Future<void> blockUser({
    required String blockerUserId,
    required String blockedUserId,
  });

  Future<void> unblockUser({
    required String blockerUserId,
    required String blockedUserId,
  });

  Stream<UserBlockModel?> blockStream({
    required String blockerUserId,
    required String blockedUserId,
  });

  Stream<List<UserBlockModel>> blockedUsersStream({
    required String blockerUserId,
  });
}

class FirestoreUserBlockRepository implements UserBlockRepository {
  FirestoreUserBlockRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _blocks(String userId) =>
      _firestore.collection('users').doc(userId).collection('blockedUsers');

  @override
  Future<void> blockUser({
    required String blockerUserId,
    required String blockedUserId,
  }) => _blocks(blockerUserId).doc(blockedUserId).set({
    'blockedUserId': blockedUserId,
    'blockedAt': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> unblockUser({
    required String blockerUserId,
    required String blockedUserId,
  }) => _blocks(blockerUserId).doc(blockedUserId).delete();

  @override
  Stream<UserBlockModel?> blockStream({
    required String blockerUserId,
    required String blockedUserId,
  }) => _blocks(blockerUserId).doc(blockedUserId).snapshots().map((snapshot) {
    final data = snapshot.data();
    return data == null ? null : UserBlockModel.fromFirestore(data);
  });

  @override
  Stream<List<UserBlockModel>> blockedUsersStream({
    required String blockerUserId,
  }) => _blocks(blockerUserId).snapshots().map(
    (snapshot) => [
      for (final document in snapshot.docs)
        UserBlockModel.fromFirestore(document.data()),
    ],
  );
}
