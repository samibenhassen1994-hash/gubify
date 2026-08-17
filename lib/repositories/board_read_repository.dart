import 'package:cloud_firestore/cloud_firestore.dart';
import 'gub_repository.dart';

class BoardReadRepository {
  BoardReadRepository._();

  static final BoardReadRepository instance = BoardReadRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> boardReadDocument({
    required String gubId,
    required String userId,
  }) {
    return _firestore
        .collection('gubs')
        .doc(gubId)
        .collection('boardReads')
        .doc(userId);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> readStateStream({
    required String gubId,
    required String userId,
  }) {
    return boardReadDocument(gubId: gubId, userId: userId).snapshots();
  }

  Stream<Timestamp?> lastReadAtStream({
    required String gubId,
    required String userId,
  }) {
    return readStateStream(gubId: gubId, userId: userId)
        .where((snapshot) {
          if (!snapshot.exists) return true;
          return snapshot.data()?['lastReadAt'] is Timestamp;
        })
        .map((snapshot) {
          if (!snapshot.exists) return null;
          return snapshot.data()?['lastReadAt'] as Timestamp;
        });
  }

  Future<Timestamp?> membershipJoinedAt({
    required String gubId,
    required String userId,
  }) async {
    final membership = await _firestore
        .collection('gubs')
        .doc(gubId)
        .collection('members')
        .doc(userId)
        .get(const GetOptions(source: Source.server));
    final joinedAt = membership.data()?['joinedAt'];
    return membership.exists && joinedAt is Timestamp ? joinedAt : null;
  }

  Future<void> markAsRead({
    required String gubId,
    required String userId,
  }) async {
    await GubRepository.instance.ensureActive(gubId);
    return boardReadDocument(gubId: gubId, userId: userId).set({
      'lastReadAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
