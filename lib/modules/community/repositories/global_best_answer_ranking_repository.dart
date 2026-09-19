import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/community_leaderboard_model.dart';

class GlobalBestAnswerRankingRepository {
  GlobalBestAnswerRankingRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static final instance = GlobalBestAnswerRankingRepository();
  final FirebaseFirestore _firestore;

  Future<CommunityLeaderboardPage> loadPage({
    Object? after,
    required int limit,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('globalBestAnswerRanking')
        .where('bestAnswerCount', isGreaterThan: 0)
        .orderBy('bestAnswerCount', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(limit);
    if (after is DocumentSnapshot<Map<String, dynamic>>) {
      query = query.startAfterDocument(after);
    }
    final snapshot = await query.get(const GetOptions(source: Source.server));
    return CommunityLeaderboardPage(
      members: snapshot.docs
          .map((document) {
            final data = document.data();
            return CommunityLeaderboardMember(
              userId: document.id,
              displayName:
                  (data['displayName'] as String?)?.trim().isNotEmpty == true
                  ? (data['displayName'] as String).trim()
                  : 'User',
              photoUrl: (data['photoUrl'] as String?)?.trim().isNotEmpty == true
                  ? (data['photoUrl'] as String).trim()
                  : null,
              xp: 0,
              bestAnswerCount: (data['bestAnswerCount'] as num?)?.toInt() ?? 0,
            );
          })
          .toList(growable: false),
      nextCursor: snapshot.docs.isEmpty ? null : snapshot.docs.last,
      hasMore: snapshot.docs.length == limit,
    );
  }
}
