import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/community_ask_model.dart';

class CommunityProfileAskHistoryRepository {
  CommunityProfileAskHistoryRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static final instance = CommunityProfileAskHistoryRepository();
  static const pageSize = 5;

  final FirebaseFirestore _firestore;

  Future<CommunityProfileAsksPage> loadPage({
    required String viewerId,
    required String targetUserId,
    required CommunityAskStatus status,
    required Map<String, String> knownCommunities,
    CommunityProfileAsksCursor? after,
  }) async {
    final knownEntries = knownCommunities.entries.toList(growable: false);
    var knownOffset = after?.knownOffset ?? 0;
    var copyCursor = after?.copyCursor;
    var discoveryExhausted = after?.discoveryExhausted ?? false;
    List<String> communityIds;
    var names = <String, String>{};

    if (after != null && after.communityIds.isNotEmpty) {
      communityIds = after.communityIds;
      names = Map<String, String>.from(after.communityNames);
    } else if (knownOffset < knownEntries.length) {
      final end = (knownOffset + pageSize).clamp(0, knownEntries.length);
      final chunk = knownEntries.sublist(knownOffset, end);
      knownOffset = end;
      names = {for (final entry in chunk) entry.key: entry.value};
      communityIds = await _mutualIds(
        viewerId: viewerId,
        targetUserId: targetUserId,
        candidateIds: names.keys.toList(growable: false),
      );
    } else if (!discoveryExhausted) {
      Query<Map<String, dynamic>> query = _firestore
          .collection('users')
          .doc(viewerId)
          .collection('communities')
          .orderBy(FieldPath.documentId)
          .limit(pageSize);
      if (copyCursor != null) {
        query = query.startAfterDocument(
          copyCursor as DocumentSnapshot<Map<String, dynamic>>,
        );
      }
      final copies = await query.get();
      copyCursor = copies.docs.isEmpty ? copyCursor : copies.docs.last;
      discoveryExhausted = copies.docs.length < pageSize;
      for (final copy in copies.docs) {
        if (knownCommunities.containsKey(copy.id)) continue;
        final name = copy.data()['name'];
        names[copy.id] = name is String && name.trim().isNotEmpty
            ? name.trim()
            : 'Community';
      }
      communityIds = await _mutualIds(
        viewerId: viewerId,
        targetUserId: targetUserId,
        candidateIds: names.keys.toList(growable: false),
      );
      names.removeWhere((id, _) => !communityIds.contains(id));
    } else {
      communityIds = const [];
    }

    if (communityIds.isEmpty) {
      final hasMore = knownOffset < knownEntries.length || !discoveryExhausted;
      return CommunityProfileAsksPage(
        asks: const [],
        communityNames: names,
        nextCursor: hasMore
            ? CommunityProfileAsksCursor._(
                knownOffset: knownOffset,
                copyCursor: copyCursor,
                discoveryExhausted: discoveryExhausted,
              )
            : null,
        hasMore: hasMore,
      );
    }

    final orderField = status == CommunityAskStatus.active
        ? 'createdAt'
        : 'resolvedAt';
    Query<Map<String, dynamic>> askQuery = _firestore
        .collectionGroup('asks')
        .where('authorId', isEqualTo: targetUserId)
        .where('status', isEqualTo: status.value)
        .where('communityId', whereIn: communityIds)
        .orderBy(orderField, descending: true)
        .limit(pageSize);
    if (after?.communityIds.isNotEmpty == true && after?.askCursor != null) {
      askQuery = askQuery.startAfterDocument(
        after!.askCursor as DocumentSnapshot<Map<String, dynamic>>,
      );
    }
    final asks = await askQuery.get();
    final chunkHasMore = asks.docs.length == pageSize;
    final hasMore =
        chunkHasMore ||
        knownOffset < knownEntries.length ||
        !discoveryExhausted;
    return CommunityProfileAsksPage(
      asks: asks.docs
          .map(
            (document) => CommunityAskModel.fromFirestore(
              document.data(),
              askId: document.id,
            ),
          )
          .toList(growable: false),
      communityNames: names,
      nextCursor: hasMore
          ? CommunityProfileAsksCursor._(
              knownOffset: knownOffset,
              copyCursor: copyCursor,
              discoveryExhausted: discoveryExhausted,
              communityIds: chunkHasMore ? communityIds : const [],
              communityNames: chunkHasMore ? names : const {},
              askCursor: chunkHasMore ? asks.docs.last : null,
            )
          : null,
      hasMore: hasMore,
    );
  }

  Future<List<String>> _mutualIds({
    required String viewerId,
    required String targetUserId,
    required List<String> candidateIds,
  }) async {
    if (candidateIds.isEmpty) return const [];
    if (viewerId == targetUserId) return candidateIds;
    final snapshot = await _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('communities')
        .where(FieldPath.documentId, whereIn: candidateIds)
        .get();
    return snapshot.docs.map((document) => document.id).toList(growable: false);
  }
}

class CommunityProfileAsksCursor {
  const CommunityProfileAsksCursor._({
    required this.knownOffset,
    required this.copyCursor,
    required this.discoveryExhausted,
    this.communityIds = const [],
    this.communityNames = const {},
    this.askCursor,
  });

  const CommunityProfileAsksCursor.forTesting(Object cursor)
    : knownOffset = 0,
      copyCursor = cursor,
      discoveryExhausted = true,
      communityIds = const [],
      communityNames = const {},
      askCursor = null;

  final int knownOffset;
  final Object? copyCursor;
  final bool discoveryExhausted;
  final List<String> communityIds;
  final Map<String, String> communityNames;
  final Object? askCursor;
}

class CommunityProfileAsksPage {
  const CommunityProfileAsksPage({
    required this.asks,
    required this.communityNames,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<CommunityAskModel> asks;
  final Map<String, String> communityNames;
  final CommunityProfileAsksCursor? nextCursor;
  final bool hasMore;
}
