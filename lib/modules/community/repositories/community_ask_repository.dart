import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/community_ask_model.dart';

enum CommunityAskCreateResult { created, duplicate, missingSource, notAuthor }

class CommunityAskRepository {
  CommunityAskRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static final CommunityAskRepository instance = CommunityAskRepository();

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _asks(String communityId) =>
      _firestore.collection('communities').doc(communityId).collection('asks');

  Future<CommunityAskCreateResult> createAskFromMessage({
    required String communityId,
    required String sourceMessageId,
    required CommunityAskType type,
    required String authorId,
  }) {
    final community = _firestore.collection('communities').doc(communityId);
    final source = community.collection('messages').doc(sourceMessageId);
    final ask = community.collection('asks').doc(sourceMessageId);

    return _firestore.runTransaction<CommunityAskCreateResult>((
      transaction,
    ) async {
      final askSnapshot = await transaction.get(ask);
      if (askSnapshot.exists) {
        return CommunityAskCreateResult.duplicate;
      }
      final sourceSnapshot = await transaction.get(source);
      if (!sourceSnapshot.exists) {
        return CommunityAskCreateResult.missingSource;
      }

      final sourceData = sourceSnapshot.data();
      if (sourceData?['senderId'] != authorId) {
        return CommunityAskCreateResult.notAuthor;
      }

      transaction.set(ask, {
        'askId': sourceMessageId,
        'communityId': communityId,
        'authorId': authorId,
        'authorDisplayName': sourceData?['senderName'],
        'type': type.value,
        'text': sourceData?['text'],
        'sourceMessageId': sourceMessageId,
        'createdAt': FieldValue.serverTimestamp(),
        'status': CommunityAskStatus.active.value,
      });
      return CommunityAskCreateResult.created;
    });
  }

  Future<String> createDirectAsk({
    required String communityId,
    required String text,
    required CommunityAskType type,
    required String authorId,
    required String authorDisplayName,
  }) async {
    final ask = _asks(communityId).doc();
    await ask.set({
      'askId': ask.id,
      'communityId': communityId,
      'authorId': authorId,
      'authorDisplayName': authorDisplayName,
      'type': type.value,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'status': CommunityAskStatus.active.value,
    });
    return ask.id;
  }

  Stream<List<CommunityAskModel>> activeAsksStream({
    required String communityId,
    required String authorId,
  }) {
    return _asks(communityId)
        .where('authorId', isEqualTo: authorId)
        .where('status', isEqualTo: CommunityAskStatus.active.value)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) => CommunityAskModel.fromFirestore(
                  document.data(),
                  askId: document.id,
                ),
              )
              .toList(growable: false),
        );
  }

  Stream<List<CommunityAskModel>> watchActiveAsks({
    required String communityId,
  }) {
    return _asks(communityId)
        .where('status', isEqualTo: CommunityAskStatus.active.value)
        .snapshots()
        .map((snapshot) {
          final asks = snapshot.docs
              .map(
                (document) => CommunityAskModel.fromFirestore(
                  document.data(),
                  askId: document.id,
                ),
              )
              .toList(growable: false);
          asks.sort(
            (first, second) => second.createdAt.compareTo(first.createdAt),
          );
          return asks;
        });
  }

  Future<int> getActiveAskCount({required String communityId}) async {
    final snapshot = await _asks(
      communityId,
    ).where('status', isEqualTo: CommunityAskStatus.active.value).count().get();
    return snapshot.count ?? 0;
  }
}
