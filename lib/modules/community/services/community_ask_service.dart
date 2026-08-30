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
    Future<String> Function({
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

class CommunityAskService {
  CommunityAskService._({
    required this._currentAccount,
    required this._currentDisplayName,
    required this._createAskFromMessage,
    required this._createDirectAsk,
    required this._activeAsks,
    required this._watchActiveAsks,
    required this._getActiveAskCount,
  });

  factory CommunityAskService.forTesting({
    required CommunityAskCurrentAccount currentAccount,
    required CommunityAskFromMessageCreate createAskFromMessage,
    CommunityAskDisplayName? currentDisplayName,
    CommunityDirectAskCreate? createDirectAsk,
    CommunityActiveAsks? activeAsks,
    CommunityAsksWatch? watchActiveAsks,
    CommunityAskCount? getActiveAskCount,
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
        }) async => 'generated-id',
    activeAsks:
        activeAsks ??
        ({required communityId, required authorId}) =>
            Stream.value(const <CommunityAskModel>[]),
    watchActiveAsks:
        watchActiveAsks ??
        ({required communityId}) => Stream.value(const <CommunityAskModel>[]),
    getActiveAskCount: getActiveAskCount ?? ({required communityId}) async => 0,
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
  );

  final CommunityAskCurrentAccount _currentAccount;
  final CommunityAskDisplayName _currentDisplayName;
  final CommunityAskFromMessageCreate _createAskFromMessage;
  final CommunityDirectAskCreate _createDirectAsk;
  final CommunityActiveAsks _activeAsks;
  final CommunityAsksWatch _watchActiveAsks;
  final CommunityAskCount _getActiveAskCount;

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
    switch (result) {
      case CommunityAskCreateResult.created:
        return;
      case CommunityAskCreateResult.duplicate:
        throw const CommunityAskAlreadyExistsException();
      case CommunityAskCreateResult.missingSource:
        throw const CommunityAskSourceMissingException();
      case CommunityAskCreateResult.notAuthor:
        throw const CommunityAskNotAllowedException();
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
    return _createDirectAsk(
      communityId: normalizedCommunityId,
      text: normalizedText,
      type: type,
      authorId: account.userId,
      authorDisplayName: displayName,
    );
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
}

class CommunityAskAlreadyExistsException implements Exception {
  const CommunityAskAlreadyExistsException();

  @override
  String toString() => 'An ask already exists for this message.';
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

class CommunityAskLinkedAccountException implements Exception {
  const CommunityAskLinkedAccountException();

  @override
  String toString() => 'Link your account to use Community asks.';
}
