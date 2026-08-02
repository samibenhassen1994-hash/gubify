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
