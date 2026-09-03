import 'package:firebase_auth/firebase_auth.dart';

import '../../../config/app_limits.dart';
import '../models/community_ask_answer_model.dart';
import '../models/community_ask_model.dart';
import '../repositories/community_ask_answer_repository.dart';
import 'community_ask_service.dart';
import 'community_service.dart';
import 'community_user_xp_cache.dart';

typedef CommunityAnswerCreate =
    Future<CommunityAnswerCreateResult> Function({
      required String communityId,
      required String askId,
      required String authorId,
      required String askAuthorId,
      required String authorDisplayName,
      required String answerText,
    });
typedef CommunityAskResolve =
    Future<CommunityAskResolution> Function({
      required String communityId,
      required String askId,
      required String answerId,
      required String resolverId,
    });
typedef CommunityAnswerEdit =
    Future<CommunityAnswerEditResult> Function({
      required String communityId,
      required String askId,
      required String answerId,
      required String text,
      required bool hasBeenEdited,
    });
typedef CommunityAnswerDelete =
    Future<CommunityAnswerDeleteResult> Function({
      required String communityId,
      required String askId,
      required String answerId,
    });

class CommunityAskAnswerService {
  CommunityAskAnswerService._({
    required this._currentAccount,
    required this._currentDisplayName,
    required this._createAnswer,
    required this._resolveAsk,
    required this._editAnswer,
    required this._deleteAnswer,
    required this._primeXp,
  });

  factory CommunityAskAnswerService.forTesting({
    required CommunityAskCurrentAccount currentAccount,
    required Future<String> Function() currentDisplayName,
    required CommunityAnswerCreate createAnswer,
    CommunityAskResolve? resolveAsk,
    CommunityAnswerEdit? editAnswer,
    CommunityAnswerDelete? deleteAnswer,
    void Function(Map<String, int>)? primeXp,
  }) => CommunityAskAnswerService._(
    currentAccount: currentAccount,
    currentDisplayName: currentDisplayName,
    createAnswer: createAnswer,
    resolveAsk:
        resolveAsk ??
        ({
          required communityId,
          required askId,
          required answerId,
          required resolverId,
        }) async => const CommunityAskResolution(
          result: CommunityAskResolveResult.resolved,
        ),
    editAnswer:
        editAnswer ??
        ({
          required communityId,
          required askId,
          required answerId,
          required text,
          required hasBeenEdited,
        }) async => CommunityAnswerEditResult.edited,
    deleteAnswer:
        deleteAnswer ??
        ({required communityId, required askId, required answerId}) async =>
            CommunityAnswerDeleteResult.deleted,
    primeXp: primeXp ?? (_) {},
  );

  factory CommunityAskAnswerService.withXpCache(CommunityUserXpCache xpCache) =>
      _production(xpCache);

  static final instance = _production(CommunityUserXpCache.instance);

  static CommunityAskAnswerService _production(CommunityUserXpCache xpCache) =>
      CommunityAskAnswerService._(
        currentAccount: () {
          final user = FirebaseAuth.instance.currentUser;
          return user == null
              ? null
              : CommunityAskAccount(
                  userId: user.uid,
                  isAnonymous: user.isAnonymous,
                );
        },
        currentDisplayName: CommunityService.instance.currentDisplayName,
        createAnswer: CommunityAskAnswerRepository.instance.createAnswer,
        resolveAsk: CommunityAskAnswerRepository.instance.resolveAsk,
        editAnswer: CommunityAskAnswerRepository.instance.editAnswer,
        deleteAnswer: CommunityAskAnswerRepository.instance.deleteAnswer,
        primeXp: xpCache.prime,
      );

  static const maxTextLength = AppLimits.communityMessageMaxLength;
  static const bestAnswerXp = CommunityAskAnswerRepository.bestAnswerXp;
  static const askAuthorResolvedXp =
      CommunityAskAnswerRepository.askAuthorResolvedXp;

  final CommunityAskCurrentAccount _currentAccount;
  final Future<String> Function() _currentDisplayName;
  final CommunityAnswerCreate _createAnswer;
  final CommunityAskResolve _resolveAsk;
  final CommunityAnswerEdit _editAnswer;
  final CommunityAnswerDelete _deleteAnswer;
  final void Function(Map<String, int>) _primeXp;

  Future<String> createAnswer({
    required String communityId,
    required String askId,
    required String askAuthorId,
    required String text,
    required CommunityAskStatus askStatus,
  }) async {
    final account = _requireLinkedAccount();
    if (askStatus != CommunityAskStatus.active) {
      throw const CommunityAskResolvedException();
    }
    if (account.userId == askAuthorId) {
      throw const CommunityAskAuthorCannotAnswerException();
    }
    final normalizedText = text.trim();
    if (communityId.trim().isEmpty || askId.trim().isEmpty) {
      throw ArgumentError('Community and Ask are required.');
    }
    if (normalizedText.isEmpty || normalizedText.length > maxTextLength) {
      throw ArgumentError('Enter a valid Answer.');
    }
    final displayName = (await _currentDisplayName()).trim();
    if (displayName.isEmpty) {
      throw StateError('Display name unavailable.');
    }
    final result = await _createAnswer(
      communityId: communityId.trim(),
      askId: askId.trim(),
      authorId: account.userId,
      askAuthorId: askAuthorId,
      authorDisplayName: displayName,
      answerText: normalizedText,
    );
    if (result == CommunityAnswerCreateResult.alreadyExists) {
      throw const CommunityAnswerAlreadyExistsException();
    }
    if (result == CommunityAnswerCreateResult.askAuthor) {
      throw const CommunityAskAuthorCannotAnswerException();
    }
    return account.userId;
  }

  Future<void> editAnswer({
    required CommunityAskModel ask,
    required CommunityAskAnswerModel answer,
    required String text,
  }) async {
    final account = _requireLinkedAccount();
    if (ask.status != CommunityAskStatus.active) {
      throw const CommunityAskResolvedException();
    }
    if (answer.authorId != account.userId ||
        answer.answerId != account.userId) {
      throw const CommunityAskNotAnswerAuthorException();
    }
    if (answer.updatedAt != null) {
      throw const CommunityAnswerAlreadyEditedException();
    }
    final normalizedText = text.trim();
    if (normalizedText.isEmpty || normalizedText.length > maxTextLength) {
      throw ArgumentError('Enter a valid Answer.');
    }
    final result = await _editAnswer(
      communityId: ask.communityId,
      askId: ask.askId,
      answerId: answer.answerId,
      text: normalizedText,
      hasBeenEdited: answer.updatedAt != null,
    );
    if (result == CommunityAnswerEditResult.alreadyEdited) {
      throw const CommunityAnswerAlreadyEditedException();
    }
  }

  Future<void> deleteAnswer({
    required CommunityAskModel ask,
    required CommunityAskAnswerModel answer,
  }) async {
    final account = _requireLinkedAccount();
    if (account.userId != answer.authorId && account.userId != ask.authorId) {
      throw const CommunityAskNotAnswerAuthorException();
    }
    final result = await _deleteAnswer(
      communityId: ask.communityId,
      askId: ask.askId,
      answerId: answer.answerId,
    );
    if (result == CommunityAnswerDeleteResult.bestAnswerProtected) {
      throw const CommunityBestAnswerProtectedException();
    }
    if (result == CommunityAnswerDeleteResult.missing) {
      throw StateError('This Answer is unavailable.');
    }
  }

  Future<CommunityAskResolution> selectBestAnswer({
    required CommunityAskModel ask,
    required CommunityAskAnswerModel answer,
  }) async {
    final account = _requireLinkedAccount();
    if (ask.status != CommunityAskStatus.active) {
      throw const CommunityAskResolvedException();
    }
    if (account.userId != ask.authorId) {
      throw const CommunityAskNotAuthorException();
    }
    if (answer.authorId == ask.authorId) {
      throw const CommunityAskOwnAnswerException();
    }
    final result = await _resolveAsk(
      communityId: ask.communityId,
      askId: ask.askId,
      answerId: answer.answerId,
      resolverId: account.userId,
    );
    switch (result.result) {
      case CommunityAskResolveResult.resolved:
        _primeXp(result.xpByUserId);
        return result;
      case CommunityAskResolveResult.ownAnswer:
        throw const CommunityAskOwnAnswerException();
      case CommunityAskResolveResult.winnerNotMember:
        throw const CommunityAskWinnerNotMemberException();
      case CommunityAskResolveResult.alreadyResolved:
        throw const CommunityAskResolvedException();
      default:
        throw StateError('Unable to select this Best Answer.');
    }
  }

  Stream<List<CommunityAskAnswerModel>> watchAnswers({
    required String communityId,
    required String askId,
  }) {
    _requireLinkedAccount();
    return CommunityAskAnswerRepository.instance.watchAnswers(
      communityId: communityId,
      askId: askId,
    );
  }

  CommunityAskAccount _requireLinkedAccount() {
    final account = _currentAccount();
    if (account == null || account.isAnonymous) {
      throw const CommunityAskLinkedAccountException();
    }
    return account;
  }
}

class CommunityAskResolvedException implements Exception {
  const CommunityAskResolvedException();
}

class CommunityAskNotAuthorException implements Exception {
  const CommunityAskNotAuthorException();
}

class CommunityAskOwnAnswerException implements Exception {
  const CommunityAskOwnAnswerException();
}

class CommunityAskAuthorCannotAnswerException implements Exception {
  const CommunityAskAuthorCannotAnswerException();
}

class CommunityAnswerAlreadyEditedException implements Exception {
  const CommunityAnswerAlreadyEditedException();
}

class CommunityAskWinnerNotMemberException implements Exception {
  const CommunityAskWinnerNotMemberException();
}

class CommunityAskNotAnswerAuthorException implements Exception {
  const CommunityAskNotAnswerAuthorException();
}

class CommunityBestAnswerProtectedException implements Exception {
  const CommunityBestAnswerProtectedException();
}

class CommunityAnswerAlreadyExistsException implements Exception {
  const CommunityAnswerAlreadyExistsException();
}
