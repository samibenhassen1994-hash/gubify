import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/community_model.dart';
import 'platform_moderation_model.dart';

class PlatformModerationRepository {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  Stream<List<CommunityModel>> communities(int limit) => _db
      .collection('communities')
      .orderBy(FieldPath.documentId)
      .limit(limit)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.map(CommunityModel.fromFirestore).toList(),
      );

  CollectionReference<Map<String, dynamic>> _content(
    String communityId,
    PlatformContentKind kind,
    String? askId,
  ) {
    final community = _db.collection('communities').doc(communityId);
    return kind == PlatformContentKind.answers
        ? community.collection('asks').doc(askId!).collection('answers')
        : community.collection(kind.name);
  }

  Stream<List<PlatformModerationItem>> content(
    String communityId,
    PlatformContentKind kind,
    String? askId,
    int limit,
  ) => _content(communityId, kind, askId)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(
              (doc) => PlatformModerationItem.fromFirestore(doc.id, doc.data()),
            )
            .toList(),
      );
  Future<void> setHidden({
    required String communityId,
    required PlatformContentKind kind,
    String? askId,
    required String itemId,
    required bool hidden,
    required String actorId,
  }) => _content(communityId, kind, askId).doc(itemId).update({
    'moderationHidden': hidden,
    'moderatedBy': actorId,
    'moderatedAt': FieldValue.serverTimestamp(),
  });
}
