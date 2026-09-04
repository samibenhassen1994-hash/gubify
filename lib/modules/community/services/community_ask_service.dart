import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../config/app_limits.dart';
import '../models/community_ask_model.dart';
import '../repositories/community_ask_repository.dart';
import 'community_service.dart';

class CommunityAskAccount {
  const CommunityAskAccount({required this.userId, required this.isAnonymous});

  final String userId;
  final bool isAnonymous;
}

typedef CommunityAskCurrentAccount = CommunityAskAccount? Function();
typedef CommunityAskFromMessageCreate =
    Future<CommunityAskCreateResult> Function({
      required String communityId,
      required String sourceMessageId,
      required CommunityAskType type,
      required String authorId,
    });
typedef CommunityDirectAskCreate =
    Future<CommunityDirectAskCreateResult> Function({
      required String communityId,
      required String text,
      required CommunityAskType type,
      required String authorId,
      required String authorDisplayName,
    });
typedef CommunityAskDisplayName = Future<String> Function();
typedef CommunityActiveAsks =
    Stream<List<CommunityAskModel>> Function({
      required String communityId,
      required String authorId,
    });
typedef CommunityAsksWatch =
    Stream<List<CommunityAskModel>> Function({required String communityId});
typedef CommunityAskCount = Future<int> Function({required String communityId});
typedef CommunityAskDelete =
    Future<CommunityAskDeleteResult> Function({
      required String communityId,
      required String askId,
      required String authorId,
    });
typedef CommunityAskEdit =
    Future<void> Function({
      required String communityId,
      required String askId,
      required String text,
    });
typedef CommunityResolvedAsksLoad =
    Future<CommunityResolvedAsksPage> Function({
      required String communityId,
      CommunityResolvedAsksCursor? after,
    });
typedef CommunityUserAsksLoad =
    Future<CommunityUserAsksPage> Function({
      required String communityId,
      required String authorId,
      required CommunityAskStatus status,
      CommunityUserAsksCursor? after,
    });
typedef CommunityAskNow = DateTime Function();

class CommunityAskService {
  CommunityAskService._({
    required this._currentAccount,
    required this._currentDisplayName,
    required this._createAskFromMessage,
    required this._createDirectAsk,
    required this._activeAsks,
    required this._watchActiveAsks,
    required this._getActiveAskCount,
    required this._loadResolvedAsksPage,
    required this._loadUserAsksPage,
    required this._editAsk,
    required this._deleteAsk,
    required this._now,
  });

  factory CommunityAskService.forTesting({
    required CommunityAskCurrentAccount currentAccount,
    required CommunityAskFromMessageCreate createAskFromMessage,
    CommunityAskDisplayName? currentDisplayName,
    CommunityDirectAskCreate? createDirectAsk,
    CommunityActiveAsks? activeAsks,
    CommunityAsksWatch? watchActiveAsks,
    CommunityAskCount? getActiveAskCount,
    CommunityResolvedAsksLoad? loadResolvedAsksPage,
    CommunityUserAsksLoad? loadUserAsksPage,
    CommunityAskEdit? editAsk,
    CommunityAskDelete? deleteAsk,
    CommunityAskNow? now,
  }) => CommunityAskService._(
    currentAccount: currentAccount,
    currentDisplayName: currentDisplayName ?? () async => 'User',
    createAskFromMessage: createAskFromMessage,
    createDirectAsk:
        createDirectAsk ??
        ({
          required communityId,
          required text,
          required type,
          required authorId,
          required authorDisplayName,
        }) async =>
            const CommunityDirectAskCreateResult.created('generated-id'),
    activeAsks:
        activeAsks ??
        ({required communityId, required authorId}) =>
            Stream.value(const <CommunityAskModel>[]),
    watchActiveAsks:
        watchActiveAsks ??
        ({required communityId}) => Stream.value(const <CommunityAskModel>[]),
    getActiveAskCount: getActiveAskCount ?? ({required communityId}) async => 0,
    loadResolvedAsksPage:
        loadResolvedAsksPage ??
        ({required communityId, after}) async =>
            const CommunityResolvedAsksPage(
              asks: [],
              nextCursor: null,
              hasMore: false,
            ),
    loadUserAsksPage:
        loadUserAsksPage ??
        ({
          required communityId,
          required authorId,
          required status,
          after,
        }) async => const CommunityUserAsksPage(
          asks: [],
          nextCursor: null,
          hasMore: false,
        ),
    editAsk:
        editAsk ??
        ({required communityId, required askId, required text}) async {},
    deleteAsk:
        deleteAsk ??
        ({required communityId, required askId, required authorId}) async =>
            CommunityAskDeleteResult.deleted,
    now: now ?? DateTime.now,
  );

  static final CommunityAskService instance = CommunityAskService._(
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
    createAskFromMessage: CommunityAskRepository.instance.createAskFromMessage,
    createDirectAsk: CommunityAskRepository.instance.createDirectAsk,
    activeAsks: CommunityAskRepository.instance.activeAsksStream,
    watchActiveAsks: CommunityAskRepository.instance.watchActiveAsks,
    getActiveAskCount: CommunityAskRepository.instance.getActiveAskCount,
    loadResolvedAsksPage: CommunityAskRepository.instance.loadResolvedAsksPage,
    loadUserAsksPage: CommunityAskRepository.instance.loadUserAsksPage,
    editAsk: CommunityAskRepository.instance.editAsk,
    deleteAsk: CommunityAskRepository.instance.deleteAsk,
    now: DateTime.now,
  );

  final CommunityAskCurrentAccount _currentAccount;
  final CommunityAskDisplayName _currentDisplayName;
  final CommunityAskFromMessageCreate _createAskFromMessage;
  final CommunityDirectAskCreate _createDirectAsk;
  final CommunityActiveAsks _activeAsks;
  final CommunityAsksWatch _watchActiveAsks;
  final CommunityAskCount _getActiveAskCount;
  final CommunityResolvedAsksLoad _loadResolvedAsksPage;
  final CommunityUserAsksLoad _loadUserAsksPage;
  final CommunityAskEdit _editAsk;
  final CommunityAskDelete _deleteAsk;
  final CommunityAskNow _now;

  static const int maxTextLength = AppLimits.communityMessageMaxLength;

  Future<void> createAskFromMessage({
    required String communityId,
    required String sourceMessageId,
    required CommunityAskType type,
  }) async {
    final account = _requireLinkedAccount();
    final normalizedCommunityId = communityId.trim();
    final normalizedMessageId = sourceMessageId.trim();
    if (normalizedCommunityId.isEmpty || normalizedMessageId.isEmpty) {
      throw ArgumentError('Community and source message are required.');
    }

    final result = await _createAskFromMessage(
      communityId: normalizedCommunityId,
      sourceMessageId: normalizedMessageId,
      type: type,
      authorId: account.userId,
    );
    switch (result.status) {
      case CommunityAskCreateStatus.created:
        return;
      case CommunityAskCreateStatus.duplicate:
        throw const CommunityAskAlreadyExistsException();
      case CommunityAskCreateStatus.activeAskExists:
        throw const CommunityActiveAskExistsException();
      case CommunityAskCreateStatus.missingSource:
        throw const CommunityAskSourceMissingException();
      case CommunityAskCreateStatus.notAuthor:
        throw const CommunityAskNotAllowedException();
      case CommunityAskCreateStatus.cooldown:
        throw CommunityAskCooldownException(
          _remainingCooldown(result.lastAskCreatedAt),
        );
    }
  }

  Future<String> createDirectAsk({
    required String communityId,
    required String text,
    required CommunityAskType type,
  }) async {
    final account = _requireLinkedAccount();
    final normalizedCommunityId = communityId.trim();
    final normalizedText = text.trim();
    if (normalizedCommunityId.isEmpty) {
      throw ArgumentError('Community ID is required.');
    }
    if (normalizedText.isEmpty) {
      throw ArgumentError('Ask text cannot be empty.');
    }
    if (normalizedText.length > maxTextLength) {
      throw ArgumentError('Ask cannot exceed $maxTextLength characters.');
    }

    final displayName = (await _currentDisplayName()).trim();
    if (displayName.isEmpty) {
      throw StateError('Your display name is unavailable.');
    }
    final result = await _createDirectAsk(
      communityId: normalizedCommunityId,
      text: normalizedText,
      type: type,
      authorId: account.userId,
      authorDisplayName: displayName,
    );
    if (result.lastAskCreatedAt != null) {
      throw CommunityAskCooldownException(
        _remainingCooldown(result.lastAskCreatedAt),
      );
    }
    if (result.activeAskExists || result.askId == null) {
      throw const CommunityActiveAskExistsException();
    }
    return result.askId!;
  }

  Stream<List<CommunityAskModel>> activeAsksStream({
    required String communityId,
    required String authorId,
  }) {
    _requireLinkedAccount();
    final normalizedCommunityId = communityId.trim();
    final normalizedAuthorId = authorId.trim();
    if (normalizedCommunityId.isEmpty || normalizedAuthorId.isEmpty) {
      return Stream.error(
        ArgumentError('Community and ask author are required.'),
      );
    }
    return _activeAsks(
      communityId: normalizedCommunityId,
      authorId: normalizedAuthorId,
    );
  }

  Stream<List<CommunityAskModel>> watchActiveAsks(String communityId) {
    _requireLinkedAccount();
    final normalizedCommunityId = communityId.trim();
    if (normalizedCommunityId.isEmpty) {
      return Stream.error(ArgumentError('Community ID is required.'));
    }
    return _watchActiveAsks(communityId: normalizedCommunityId);
  }

  Future<int> getActiveAskCount(String communityId) {
    _requireLinkedAccount();
    final normalizedCommunityId = communityId.trim();
    if (normalizedCommunityId.isEmpty) {
      throw ArgumentError('Community ID is required.');
    }
    return _getActiveAskCount(communityId: normalizedCommunityId);
  }

  Future<CommunityResolvedAsksPage> loadResolvedAsksPage({
    required String communityId,
    CommunityResolvedAsksCursor? after,
  }) {
    _requireLinkedAccount();
    final normalizedCommunityId = communityId.trim();
    if (normalizedCommunityId.isEmpty) {
      throw ArgumentError('Community ID is required.');
    }
    return _loadResolvedAsksPage(
      communityId: normalizedCommunityId,
      after: after,
    );
  }

  Future<CommunityUserAsksPage> loadMyAsksPage({
    required String communityId,
    required CommunityAskStatus status,
    CommunityUserAsksCursor? after,
  }) {
    final account = _requireLinkedAccount();
    final normalizedCommunityId = communityId.trim();
    if (normalizedCommunityId.isEmpty) {
      throw ArgumentError('Community ID is required.');
    }
    return _loadUserAsksPage(
      communityId: normalizedCommunityId,
      authorId: account.userId,
      status: status,
      after: after,
    );
  }

  Future<void> editAsk({
    required CommunityAskModel ask,
    required String text,
  }) async {
    final account = _requireLinkedAccount();
    if (ask.authorId != account.userId) {
      throw const CommunityAskNotAllowedException();
    }
    if (ask.status != CommunityAskStatus.active) {
      throw const CommunityAskEditUnavailableException();
    }
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      throw ArgumentError('Ask text cannot be empty.');
    }
    if (normalizedText.length > maxTextLength) {
      throw ArgumentError('Ask cannot exceed $maxTextLength characters.');
    }
    await _editAsk(
      communityId: ask.communityId,
      askId: ask.askId,
      text: normalizedText,
    );
  }

  Future<void> deleteAsk(CommunityAskModel ask) async {
    final account = _requireLinkedAccount();
    if (ask.authorId != account.userId) {
      throw const CommunityAskNotAllowedException();
    }
    final result = await _deleteAsk(
      communityId: ask.communityId,
      askId: ask.askId,
      authorId: account.userId,
    );
    if (result == CommunityAskDeleteResult.missing) {
      throw StateError('This Ask is unavailable.');
    }
    if (result == CommunityAskDeleteResult.activeSlotMismatch) {
      throw StateError('Unable to remove this Ask safely.');
    }
  }

  CommunityAskAccount _requireLinkedAccount() {
    final account = _currentAccount();
    if (account == null) {
      throw StateError('You must be signed in to use Community asks.');
    }
    if (account.isAnonymous) {
      throw const CommunityAskLinkedAccountException();
    }
    return account;
  }

  Duration _remainingCooldown(Timestamp? lastAskCreatedAt) {
    if (lastAskCreatedAt == null) return const Duration(minutes: 1);
    final remaining = lastAskCreatedAt
        .toDate()
        .add(const Duration(hours: 8))
        .difference(_now());
    return remaining.isNegative || remaining == Duration.zero
        ? const Duration(minutes: 1)
        : remaining;
  }
}

class CommunityAskCooldownException implements Exception {
  CommunityAskCooldownException(this.remaining);

  final Duration remaining;

  String get userMessage {
    final minutes = (remaining.inSeconds + 59) ~/ 60;
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    final duration = hours == 0
        ? '${minutes}m'
        : remainingMinutes == 0
        ? '${hours}h'
        : '${hours}h ${remainingMinutes}m';
    return 'You can create another Ask in $duration.';
  }

  @override
  String toString() => userMessage;
}

class CommunityAskAlreadyExistsException implements Exception {
  const CommunityAskAlreadyExistsException();

  @override
  String toString() => 'An ask already exists for this message.';
}

class CommunityActiveAskExistsException implements Exception {
  const CommunityActiveAskExistsException();

  @override
  String toString() => 'You already have an active Ask in this Community.';
}

class CommunityAskSourceMissingException implements Exception {
  const CommunityAskSourceMissingException();

  @override
  String toString() => 'The original message is no longer available.';
}

class CommunityAskNotAllowedException implements Exception {
  const CommunityAskNotAllowedException();

  @override
  String toString() => 'You can only create an ask from your own message.';
}

class CommunityAskEditUnavailableException implements Exception {
  const CommunityAskEditUnavailableException();

  @override
  String toString() => 'This Ask has already been resolved.';
}

class CommunityAskLinkedAccountException implements Exception {
  const CommunityAskLinkedAccountException();

  @override
  String toString() => 'Link your account to use Community asks.';
}
