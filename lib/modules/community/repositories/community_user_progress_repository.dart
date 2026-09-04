import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityUserProgressRepository {
  CommunityUserProgressRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static final instance = CommunityUserProgressRepository();
  static const queryBatchSize = 30;

  final FirebaseFirestore _firestore;
  final Set<String> _projectionBackfillChecked = <String>{};
  static const int projectionVersion = 1;
  static const int projectionBackfillPageSize = 100;

  /// Watches only the current linked user's progress document.
  ///
  /// A missing document deliberately represents a new user with zero XP.
  Stream<int> watchUserXp(String userId) {
    final id = userId.trim();
    if (id.isEmpty) return Stream<int>.value(0);
    return _firestore
        .collection('communityUserProgress')
        .doc(id)
        .snapshots()
        .map((snapshot) => (snapshot.data()?['xp'] as num?)?.toInt() ?? 0);
  }

  Future<Map<String, int>> loadXp(Set<String> userIds) async {
    final ids = userIds.where((id) => id.trim().isNotEmpty).toList();
    final result = <String, int>{};
    for (var offset = 0; offset < ids.length; offset += queryBatchSize) {
      final end = (offset + queryBatchSize).clamp(0, ids.length);
      final snapshot = await _firestore
          .collection('communityUserProgress')
          .where(FieldPath.documentId, whereIn: ids.sublist(offset, end))
          .get();
      for (final document in snapshot.docs) {
        result[document.id] = (document.data()['xp'] as num?)?.toInt() ?? 0;
      }
    }
    return result;
  }

  /// Repairs the technical membership projection for pre-existing accounts.
  ///
  /// The user's bounded/paginated Community copies only provide candidate IDs;
  /// each candidate is accepted in the transaction only when the authoritative
  /// member document still exists. This runs at most once per user per session.
  Future<void> backfillCommunityIds(String userId) async {
    final id = userId.trim();
    if (id.isEmpty || !_projectionBackfillChecked.add(id)) return;

    final progressReference = _firestore
        .collection('communityUserProgress')
        .doc(id);
    final progress = await progressReference.get();
    if ((progress.data()?['communityProjectionVersion'] as num?)?.toInt() ==
        projectionVersion) {
      return;
    }

    QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      Query<Map<String, dynamic>> query = _firestore
          .collection('users')
          .doc(id)
          .collection('communities')
          .orderBy(FieldPath.documentId)
          .limit(projectionBackfillPageSize);
      if (cursor != null) query = query.startAfterDocument(cursor);
      final page = await query.get();
      for (final copy in page.docs) {
        final communityId = copy.id;
        await _firestore.runTransaction<void>((transaction) async {
          final memberReference = _firestore
              .collection('communities')
              .doc(communityId)
              .collection('members')
              .doc(id);
          final member = await transaction.get(memberReference);
          final currentProgress = await transaction.get(progressReference);
          if (!member.exists || member.data()?['uid'] != id) return;
          final data = <String, dynamic>{
            'communityIds': FieldValue.arrayUnion([communityId]),
            'membershipProjectionCommunityId': communityId,
            'membershipProjectionAction': 'backfill',
            'membershipProjectionUpdatedAt': FieldValue.serverTimestamp(),
          };
          if (!currentProgress.exists) data['xp'] = 0;
          transaction.set(progressReference, data, SetOptions(merge: true));
        });
      }
      if (page.docs.length < projectionBackfillPageSize) break;
      cursor = page.docs.last;
    }

    await progressReference.set({
      'xp': progress.exists ? FieldValue.increment(0) : 0,
      'communityProjectionVersion': projectionVersion,
    }, SetOptions(merge: true));
  }
}
