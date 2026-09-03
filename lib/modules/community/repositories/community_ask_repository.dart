import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/community_ask_model.dart';

enum CommunityAskCreateStatus {
  created,
  duplicate,
  activeAskExists,
  missingSource,
  notAuthor,
  cooldown,
}

class CommunityAskCreateResult {
  const CommunityAskCreateResult._(this.status) : lastAskCreatedAt = null;

  static const created = CommunityAskCreateResult._(
    CommunityAskCreateStatus.created,
  );
  static const duplicate = CommunityAskCreateResult._(
    CommunityAskCreateStatus.duplicate,
  );
  static const activeAskExists = CommunityAskCreateResult._(
    CommunityAskCreateStatus.activeAskExists,
  );
  static const missingSource = CommunityAskCreateResult._(
    CommunityAskCreateStatus.missingSource,
  );
  static const notAuthor = CommunityAskCreateResult._(
    CommunityAskCreateStatus.notAuthor,
  );

  const CommunityAskCreateResult.cooldown(this.lastAskCreatedAt)
    : status = CommunityAskCreateStatus.cooldown;

  final CommunityAskCreateStatus status;
  final Timestamp? lastAskCreatedAt;
}

enum CommunityAskDeleteResult { deleted, missing, activeSlotMismatch }

class CommunityDirectAskCreateResult {
  const CommunityDirectAskCreateResult.created(this.askId)
    : activeAskExists = false,
      lastAskCreatedAt = null;

  const CommunityDirectAskCreateResult.activeAskExists()
    : askId = null,
      activeAskExists = true,
      lastAskCreatedAt = null;

  const CommunityDirectAskCreateResult.cooldown(this.lastAskCreatedAt)
    : askId = null,
      activeAskExists = false;

  final String? askId;
  final bool activeAskExists;
  final Timestamp? lastAskCreatedAt;
}

class CommunityAskRepository {
  CommunityAskRepository({
    FirebaseFirestore? firestore,
    DateTime Function()? clock,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _clock = clock ?? DateTime.now;

  static final CommunityAskRepository instance = CommunityAskRepository();

  final FirebaseFirestore _firestore;
  final DateTime Function() _clock;

  CollectionReference<Map<String, dynamic>> _asks(String communityId) =>
      _firestore.collection('communities').doc(communityId).collection('asks');

  DocumentReference<Map<String, dynamic>> _activeAskSlot(
    String communityId,
    String authorId,
  ) => _firestore
      .collection('communities')
      .doc(communityId)
      .collection('activeAskSlots')
      .doc(authorId);

  DocumentReference<Map<String, dynamic>> _member(
    String communityId,
    String userId,
  ) => _firestore
      .collection('communities')
      .doc(communityId)
      .collection('members')
      .doc(userId);

  Future<CommunityAskCreateResult> createAskFromMessage({
    required String communityId,
    required String sourceMessageId,
    required CommunityAskType type,
    required String authorId,
  }) {
    final community = _firestore.collection('communities').doc(communityId);
    final source = community.collection('messages').doc(sourceMessageId);
    final ask = community.collection('asks').doc(sourceMessageId);
    final slot = _activeAskSlot(communityId, authorId);
    final member = _member(communityId, authorId);

    return _firestore.runTransaction<CommunityAskCreateResult>((
      transaction,
    ) async {
      final askSnapshot = await transaction.get(ask);
      if (askSnapshot.exists) {
        return CommunityAskCreateResult.duplicate;
      }
      final slotSnapshot = await transaction.get(slot);
      if (slotSnapshot.exists) {
        return CommunityAskCreateResult.activeAskExists;
      }
      final memberSnapshot = await transaction.get(member);
      final lastAskCreatedAt = memberSnapshot.data()?['lastAskCreatedAt'];
      if (lastAskCreatedAt is Timestamp &&
          lastAskCreatedAt
              .toDate()
              .add(const Duration(hours: 8))
              .isAfter(_clock())) {
        return CommunityAskCreateResult.cooldown(lastAskCreatedAt);
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
      transaction.set(slot, {
        'askId': sourceMessageId,
        'authorId': authorId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(member, {
        'lastAskCreatedAt': FieldValue.serverTimestamp(),
      });
      return CommunityAskCreateResult.created;
    });
  }

  Future<CommunityDirectAskCreateResult> createDirectAsk({
    required String communityId,
    required String text,
    required CommunityAskType type,
    required String authorId,
    required String authorDisplayName,
  }) {
    final ask = _asks(communityId).doc();
    final slot = _activeAskSlot(communityId, authorId);
    final member = _member(communityId, authorId);
    return _firestore.runTransaction((transaction) async {
      final slotSnapshot = await transaction.get(slot);
      if (slotSnapshot.exists) {
        return const CommunityDirectAskCreateResult.activeAskExists();
      }
      final memberSnapshot = await transaction.get(member);
      final lastAskCreatedAt = memberSnapshot.data()?['lastAskCreatedAt'];
      if (lastAskCreatedAt is Timestamp &&
          lastAskCreatedAt
              .toDate()
              .add(const Duration(hours: 8))
              .isAfter(_clock())) {
        return CommunityDirectAskCreateResult.cooldown(lastAskCreatedAt);
      }
      transaction.set(ask, {
        'askId': ask.id,
        'communityId': communityId,
        'authorId': authorId,
        'authorDisplayName': authorDisplayName,
        'type': type.value,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'status': CommunityAskStatus.active.value,
      });
      transaction.set(slot, {
        'askId': ask.id,
        'authorId': authorId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(member, {
        'lastAskCreatedAt': FieldValue.serverTimestamp(),
      });
      return CommunityDirectAskCreateResult.created(ask.id);
    });
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

  Future<CommunityResolvedAsksPage> loadResolvedAsksPage({
    required String communityId,
    CommunityResolvedAsksCursor? after,
    int limit = 5,
  }) async {
    Query<Map<String, dynamic>> query = _asks(communityId)
        .where('status', isEqualTo: CommunityAskStatus.resolved.value)
        .orderBy('resolvedAt', descending: true)
        .limit(limit);
    if (after != null) {
      query = query.startAfterDocument(
        after._document as DocumentSnapshot<Map<String, dynamic>>,
      );
    }
    final snapshot = await query.get();
    return CommunityResolvedAsksPage(
      asks: snapshot.docs
          .map(
            (document) => CommunityAskModel.fromFirestore(
              document.data(),
              askId: document.id,
            ),
          )
          .toList(growable: false),
      nextCursor: snapshot.docs.isEmpty
          ? null
          : CommunityResolvedAsksCursor._(snapshot.docs.last),
      hasMore: snapshot.docs.length == limit,
    );
  }

  Future<CommunityUserAsksPage> loadUserAsksPage({
    required String communityId,
    required String authorId,
    required CommunityAskStatus status,
    CommunityUserAsksCursor? after,
    int limit = 5,
  }) async {
    final orderField = status == CommunityAskStatus.active
        ? 'createdAt'
        : 'resolvedAt';
    Query<Map<String, dynamic>> query = _asks(communityId)
        .where('authorId', isEqualTo: authorId)
        .where('status', isEqualTo: status.value)
        .orderBy(orderField, descending: true)
        .limit(limit);
    if (after != null) {
      query = query.startAfterDocument(
        after._document as DocumentSnapshot<Map<String, dynamic>>,
      );
    }
    final snapshot = await query.get();
    return CommunityUserAsksPage(
      asks: snapshot.docs
          .map(
            (document) => CommunityAskModel.fromFirestore(
              document.data(),
              askId: document.id,
            ),
          )
          .toList(growable: false),
      nextCursor: snapshot.docs.isEmpty
          ? null
          : CommunityUserAsksCursor._(snapshot.docs.last),
      hasMore: snapshot.docs.length == limit,
    );
  }

  Future<void> editAsk({
    required String communityId,
    required String askId,
    required String text,
  }) => _asks(communityId).doc(askId).update({
    'text': text,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  Future<CommunityAskDeleteResult> deleteAsk({
    required String communityId,
    required String askId,
    required String authorId,
  }) async {
    final community = _firestore.collection('communities').doc(communityId);
    final ask = community.collection('asks').doc(askId);
    final answers = ask.collection('answers');

    while (true) {
      final snapshot = await answers.limit(450).get();
      if (snapshot.docs.isEmpty) {
        break;
      }
      final batch = _firestore.batch();
      for (final answer in snapshot.docs) {
        batch.delete(answer.reference);
      }
      await batch.commit();
    }

    final slot = _activeAskSlot(communityId, authorId);
    return _firestore.runTransaction((transaction) async {
      final askSnapshot = await transaction.get(ask);
      if (!askSnapshot.exists) {
        return CommunityAskDeleteResult.missing;
      }
      final slotSnapshot = await transaction.get(slot);
      final askData = askSnapshot.data()!;
      if (askData['status'] == CommunityAskStatus.active.value &&
          slotSnapshot.exists &&
          slotSnapshot.data()?['askId'] != askId) {
        return CommunityAskDeleteResult.activeSlotMismatch;
      }
      transaction.delete(ask);
      if (askData['status'] == CommunityAskStatus.active.value &&
          slotSnapshot.exists) {
        transaction.delete(slot);
      }
      return CommunityAskDeleteResult.deleted;
    });
  }

  Stream<CommunityAskModel?> watchAsk({
    required String communityId,
    required String askId,
  }) => _asks(communityId)
      .doc(askId)
      .snapshots()
      .map(
        (snapshot) => snapshot.exists
            ? CommunityAskModel.fromFirestore(
                snapshot.data()!,
                askId: snapshot.id,
              )
            : null,
      );
}

class CommunityResolvedAsksCursor {
  const CommunityResolvedAsksCursor._(this._document);

  const CommunityResolvedAsksCursor.forTesting(Object cursor)
    : _document = cursor;

  final Object _document;
}

class CommunityResolvedAsksPage {
  const CommunityResolvedAsksPage({
    required this.asks,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<CommunityAskModel> asks;
  final CommunityResolvedAsksCursor? nextCursor;
  final bool hasMore;
}

class CommunityUserAsksCursor {
  const CommunityUserAsksCursor._(this._document);

  const CommunityUserAsksCursor.forTesting(Object cursor) : _document = cursor;

  final Object _document;
}

class CommunityUserAsksPage {
  const CommunityUserAsksPage({
    required this.asks,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<CommunityAskModel> asks;
  final CommunityUserAsksCursor? nextCursor;
  final bool hasMore;
}
