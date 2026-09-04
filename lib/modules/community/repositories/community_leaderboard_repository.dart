import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/community_leaderboard_model.dart';

class CommunityLeaderboardRepository {
  CommunityLeaderboardRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static final instance = CommunityLeaderboardRepository();

  final FirebaseFirestore _firestore;

  Future<CommunityLeaderboardPage> loadTopLevel({
    required String communityId,
    Object? after,
    required int limit,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('communityUserProgress')
        .where('communityIds', arrayContains: communityId)
        .orderBy('xp', descending: true)
        .limit(limit);
    if (after is DocumentSnapshot<Map<String, dynamic>>) {
      query = query.startAfterDocument(after);
    }
    final progress = await query.get();
    if (progress.docs.isEmpty) {
      return const CommunityLeaderboardPage(members: []);
    }

    final ids = progress.docs.map((document) => document.id).toList();
    final members = await _firestore
        .collection('communities')
        .doc(communityId)
        .collection('members')
        .where(FieldPath.documentId, whereIn: ids)
        .get();
    final memberData = {for (final document in members.docs) document.id: document.data()};
    final ranked = <CommunityLeaderboardMember>[];
    for (final document in progress.docs) {
      final membership = memberData[document.id];
      if (membership == null) continue;
      ranked.add(
        CommunityLeaderboardMember(
          userId: document.id,
          displayName: _displayName(membership['displayName']),
          photoUrl: _photoUrl(membership['photoUrl']),
          xp: (document.data()['xp'] as num?)?.toInt() ?? 0,
          bestAnswerCount:
              (membership['bestAnswerCount'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    return CommunityLeaderboardPage(
      members: ranked,
      nextCursor: progress.docs.last,
      hasMore: progress.docs.length == limit,
    );
  }

  Future<CommunityLeaderboardPage> loadTopAnswers({
    required String communityId,
    Object? after,
    required int limit,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('communities')
        .doc(communityId)
        .collection('members')
        .where('bestAnswerCount', isGreaterThan: 0)
        .orderBy('bestAnswerCount', descending: true)
        .limit(limit);
    if (after is DocumentSnapshot<Map<String, dynamic>>) {
      query = query.startAfterDocument(after);
    }
    final members = await query.get();
    final ids = members.docs.map((document) => document.id).toSet();
    final progress = ids.isEmpty
        ? const <String, int>{}
        : await _loadXp(ids);
    return CommunityLeaderboardPage(
      members: members.docs
          .map(
            (document) => CommunityLeaderboardMember(
              userId: document.id,
              displayName: _displayName(document.data()['displayName']),
              photoUrl: _photoUrl(document.data()['photoUrl']),
              xp: progress[document.id] ?? 0,
              bestAnswerCount:
                  (document.data()['bestAnswerCount'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList(growable: false),
      nextCursor: members.docs.isEmpty ? null : members.docs.last,
      hasMore: members.docs.length == limit,
    );
  }

  Future<Map<String, int>> _loadXp(Set<String> ids) async {
    final snapshot = await _firestore
        .collection('communityUserProgress')
        .where(FieldPath.documentId, whereIn: ids.toList())
        .get();
    return {
      for (final document in snapshot.docs)
        document.id: (document.data()['xp'] as num?)?.toInt() ?? 0,
    };
  }

  String _displayName(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : 'User';

  String? _photoUrl(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;
}
