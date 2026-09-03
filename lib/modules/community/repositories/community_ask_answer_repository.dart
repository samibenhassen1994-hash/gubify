import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/community_ask_answer_model.dart';

enum CommunityAskResolveResult {
  resolved,
  missingAsk,
  missingAnswer,
  notAuthor,
  ownAnswer,
  alreadyResolved,
  winnerNotMember,
  askerNotMember,
}

enum CommunityAnswerCreateResult { created, alreadyExists, askAuthor }

enum CommunityAnswerEditResult { edited, alreadyEdited }

enum CommunityAnswerDeleteResult { deleted, missing, bestAnswerProtected }

class CommunityAskResolution {
  const CommunityAskResolution({
    required this.result,
    this.xpByUserId = const {},
    this.bestAnswerId,
    this.bestAnswerAuthorId,
  });

  final CommunityAskResolveResult result;
  final Map<String, int> xpByUserId;
  final String? bestAnswerId;
  final String? bestAnswerAuthorId;
}

class CommunityAskAnswerRepository {
  CommunityAskAnswerRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static final instance = CommunityAskAnswerRepository();
  static const bestAnswerXp = 20;
  static const askAuthorResolvedXp = 2;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _answers(
    String communityId,
    String askId,
  ) => _firestore
      .collection('communities')
      .doc(communityId)
      .collection('asks')
      .doc(askId)
      .collection('answers');

  Future<CommunityAnswerCreateResult> createAnswer({
    required String communityId,
    required String askId,
    required String authorId,
    required String askAuthorId,
    required String authorDisplayName,
    required String answerText,
  }) {
    if (authorId == askAuthorId) {
      return Future.value(CommunityAnswerCreateResult.askAuthor);
    }
    final answer = _answers(communityId, askId).doc(authorId);
    return _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(answer);
      if (existing.exists) {
        return CommunityAnswerCreateResult.alreadyExists;
      }
      transaction.set(answer, {
        'answerId': authorId,
        'authorId': authorId,
        'authorDisplayName': authorDisplayName,
        'text': answerText,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return CommunityAnswerCreateResult.created;
    });
  }

  Future<CommunityAnswerEditResult> editAnswer({
    required String communityId,
    required String askId,
    required String answerId,
    required String text,
    required bool hasBeenEdited,
  }) {
    if (hasBeenEdited) {
      return Future.value(CommunityAnswerEditResult.alreadyEdited);
    }
    return _answers(communityId, askId)
        .doc(answerId)
        .update({'text': text, 'updatedAt': FieldValue.serverTimestamp()})
        .then((_) => CommunityAnswerEditResult.edited);
  }

  Future<CommunityAnswerDeleteResult> deleteAnswer({
    required String communityId,
    required String askId,
    required String answerId,
  }) {
    final ask = _firestore
        .collection('communities')
        .doc(communityId)
        .collection('asks')
        .doc(askId);
    final answer = ask.collection('answers').doc(answerId);
    return _firestore.runTransaction((transaction) async {
      final askSnapshot = await transaction.get(ask);
      final answerSnapshot = await transaction.get(answer);
      if (!askSnapshot.exists || !answerSnapshot.exists) {
        return CommunityAnswerDeleteResult.missing;
      }
      final askData = askSnapshot.data()!;
      if (askData['status'] == 'resolved' &&
          askData['bestAnswerId'] == answerId) {
        return CommunityAnswerDeleteResult.bestAnswerProtected;
      }
      transaction.delete(answer);
      return CommunityAnswerDeleteResult.deleted;
    });
  }

  Stream<List<CommunityAskAnswerModel>> watchAnswers({
    required String communityId,
    required String askId,
  }) => _answers(communityId, askId)
      .orderBy('createdAt')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(
              (document) => CommunityAskAnswerModel.fromFirestore(
                document.data(),
                answerId: document.id,
              ),
            )
            .toList(growable: false),
      );

  Future<CommunityAskResolution> resolveAsk({
    required String communityId,
    required String askId,
    required String answerId,
    required String resolverId,
  }) {
    final community = _firestore.collection('communities').doc(communityId);
    final ask = community.collection('asks').doc(askId);
    final answer = ask.collection('answers').doc(answerId);
    DocumentReference<Map<String, dynamic>>? slot;
    return _firestore.runTransaction((transaction) async {
      final askSnapshot = await transaction.get(ask);
      if (!askSnapshot.exists) {
        return const CommunityAskResolution(
          result: CommunityAskResolveResult.missingAsk,
        );
      }
      final askData = askSnapshot.data()!;
      if (askData['status'] != 'active') {
        return const CommunityAskResolution(
          result: CommunityAskResolveResult.alreadyResolved,
        );
      }
      final askerId = askData['authorId'] as String? ?? '';
      slot = community.collection('activeAskSlots').doc(askerId);
      final answerSnapshot = await transaction.get(answer);
      if (!answerSnapshot.exists) {
        return const CommunityAskResolution(
          result: CommunityAskResolveResult.missingAnswer,
        );
      }
      final winnerId = answerSnapshot.data()?['authorId'] as String? ?? '';
      if (winnerId == askerId) {
        return const CommunityAskResolution(
          result: CommunityAskResolveResult.ownAnswer,
        );
      }

      if (resolverId != askerId) {
        return const CommunityAskResolution(
          result: CommunityAskResolveResult.notAuthor,
        );
      }
      final winnerMember = community.collection('members').doc(winnerId);
      final askerMember = community.collection('members').doc(askerId);
      final winnerSnapshot = await transaction.get(winnerMember);
      final askerSnapshot = await transaction.get(askerMember);
      final slotSnapshot = await transaction.get(slot!);
      if (!winnerSnapshot.exists) {
        return const CommunityAskResolution(
          result: CommunityAskResolveResult.winnerNotMember,
        );
      }
      if (!askerSnapshot.exists) {
        return const CommunityAskResolution(
          result: CommunityAskResolveResult.askerNotMember,
        );
      }
      final progress = _firestore.collection('communityUserProgress');
      final winnerProgress = progress.doc(winnerId);
      final askerProgress = progress.doc(askerId);
      final winnerProgressSnapshot = await transaction.get(winnerProgress);
      final askerProgressSnapshot = await transaction.get(askerProgress);
      int number(Map<String, dynamic>? data, String key) =>
          (data?[key] as num?)?.toInt() ?? 0;
      final winnerXp =
          number(winnerProgressSnapshot.data(), 'xp') + bestAnswerXp;
      final askerXp =
          number(askerProgressSnapshot.data(), 'xp') + askAuthorResolvedXp;
      transaction.update(ask, {
        'status': 'resolved',
        'bestAnswerId': answerId,
        'bestAnswerAuthorId': winnerId,
        'resolvedAt': FieldValue.serverTimestamp(),
        'xpAwarded': true,
      });
      if (slotSnapshot.exists) {
        transaction.delete(slot!);
      }
      transaction.update(winnerMember, {
        'bestAnswerCount': number(winnerSnapshot.data(), 'bestAnswerCount') + 1,
      });
      transaction.set(winnerProgress, {
        'xp': winnerXp,
        'communityIds': FieldValue.arrayUnion([communityId]),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastRewardCommunityId': communityId,
        'lastRewardAskId': askId,
        'lastRewardRole': 'bestAnswer',
      }, SetOptions(merge: true));
      transaction.set(askerProgress, {
        'xp': askerXp,
        'communityIds': FieldValue.arrayUnion([communityId]),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastRewardCommunityId': communityId,
        'lastRewardAskId': askId,
        'lastRewardRole': 'askAuthor',
      }, SetOptions(merge: true));
      return CommunityAskResolution(
        result: CommunityAskResolveResult.resolved,
        xpByUserId: {winnerId: winnerXp, askerId: askerXp},
        bestAnswerId: answerId,
        bestAnswerAuthorId: winnerId,
      );
    });
  }
}
