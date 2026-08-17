import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../../repositories/user_repository.dart';
import '../../../services/auth_service.dart';
import '../../../services/member_service.dart';
import '../../../services/local_storage_service.dart';
import '../../community/services/community_service.dart';
import '../models/account_deletion_model.dart';
import '../repositories/account_deletion_repository.dart';
import '../repositories/account_deletion_marker_store.dart';

class AccountDeletionService {
  AccountDeletionService({
    required this.authService,
    AccountDeletionRepositoryContract? repository,
    AccountDeletionMarkerStore? markerStore,
    Future<void> Function(String gubId)? leavePrivateGub,
    Future<void> Function(String communityId)? leaveCommunity,
    void Function()? clearUserCache,
    Future<void> Function()? clearLocalProfileState,
  }) : _repository = repository ?? AccountDeletionRepository(),
       _markerStore =
           markerStore ?? SharedPreferencesAccountDeletionMarkerStore(),
       _leavePrivateGub =
           leavePrivateGub ??
           ((gubId) => MemberService.instance.leaveGub(gubId: gubId)),
       _leaveCommunity =
           leaveCommunity ?? CommunityService.instance.leaveCommunity,
       _clearUserCache = clearUserCache ?? UserRepository.instance.clearCache,
       _clearLocalProfileState =
           clearLocalProfileState ?? LocalStorageService().clear;

  final AuthService authService;
  final AccountDeletionRepositoryContract _repository;
  final AccountDeletionMarkerStore _markerStore;
  final Future<void> Function(String gubId) _leavePrivateGub;
  final Future<void> Function(String communityId) _leaveCommunity;
  final void Function() _clearUserCache;
  final Future<void> Function() _clearLocalProfileState;
  bool _running = false;

  Future<AccountDeletionPreflight> preflight() async {
    final uid = authService.currentUserId;
    if (uid == null) return const AccountDeletionPreflight();
    return _repository.loadPreflight(uid);
  }

  Future<AccountDeletionResult> deleteAccount({String? password}) async {
    if (_running) {
      return const AccountDeletionResult(AccountDeletionStatus.cleanupFailed);
    }
    final uid = authService.currentUserId;
    if (uid == null) {
      return const AccountDeletionResult(AccountDeletionStatus.noCurrentUser);
    }
    _running = true;
    try {
      late final AccountDeletionPreflight ownership;
      try {
        ownership = await _atStage(
          'ownershipPreflight',
          () => _repository.loadPreflight(uid),
        );
      } catch (_) {
        return const AccountDeletionResult(AccountDeletionStatus.cleanupFailed);
      }
      if (ownership.isBlocked) {
        return AccountDeletionResult(
          AccountDeletionStatus.ownershipBlocked,
          preflight: ownership,
        );
      }

      final reauthentication = await authService.reauthenticateForDeletion(
        password: password,
      );
      if (reauthentication != AccountDeletionReauthStatus.success) {
        return AccountDeletionResult(_mapReauthentication(reauthentication));
      }

      try {
        await _atStage(
          'persistRecoveryMarker',
          () => _markerStore.writeUserId(uid),
        );
        final memberships = await _atStage(
          'cleanupPersonalCopies',
          () => _repository.loadMemberships(uid),
        );
        final privateIds = memberships.privateGubIds;
        final communityIds = memberships.communityIds;
        await _atStage(
          'anonymizeSharedContent',
          () => _repository.anonymizeSharedContent(
            userId: uid,
            privateGubIds: privateIds,
            communityIds: communityIds,
          ),
        );
        await _cleanMemberships(uid, privateIds, communityIds);
        await _atStage(
          'deleteFirestoreProfile',
          () => _repository.deleteProfile(uid),
        );
        _clearUserCache();
        await _atStage('clearLocalState', _clearLocalProfileState);
      } catch (_) {
        return const AccountDeletionResult(AccountDeletionStatus.cleanupFailed);
      }

      final authDeleted = await authService.deleteCurrentAccountAuthUser();
      if (authDeleted) {
        try {
          await _markerStore.clear();
        } catch (_) {
          // Startup clears a stale marker when the Auth user is already gone.
        }
      }
      return AccountDeletionResult(
        authDeleted
            ? AccountDeletionStatus.success
            : AccountDeletionStatus.authDeletionFailed,
      );
    } finally {
      _running = false;
    }
  }

  Future<void> _cleanMemberships(
    String uid,
    List<String> privateIds,
    List<String> communityIds,
  ) async {
    for (final gubId in privateIds) {
      try {
        await _repository.deletePrivateReadState(gubId, uid);
      } on FirebaseException catch (error) {
        if (error.code != 'permission-denied') {
          _debugFailure('cleanupReadState', error);
          rethrow;
        }
      }
      try {
        await _leavePrivateGub(gubId);
      } on StateError {
        await _atStage(
          'cleanupPersonalCopies',
          () => _repository.deletePrivateCopy(gubId, uid),
        );
      } on Object catch (error) {
        _debugFailure('leavePrivateGubs', error);
        rethrow;
      }
    }

    for (final communityId in communityIds) {
      try {
        await _repository.deleteCommunityJoinRequest(communityId, uid);
      } on FirebaseException catch (error) {
        if (error.code != 'permission-denied') {
          _debugFailure('cleanupReadState', error);
          rethrow;
        }
      }
      try {
        await _leaveCommunity(communityId);
      } on StateError {
        await _atStage(
          'cleanupPersonalCopies',
          () => _repository.deleteCommunityCopy(communityId, uid),
        );
      } on Object catch (error) {
        _debugFailure('leaveCommunities', error);
        rethrow;
      }
    }
  }

  Future<T> _atStage<T>(String stage, Future<T> Function() operation) async {
    try {
      return await operation();
    } on Object catch (error) {
      _debugFailure(stage, error);
      rethrow;
    }
  }

  void _debugFailure(String stage, Object error) {
    if (!kDebugMode) return;
    debugPrint('Account deletion failed at: $stage');
    if (error is FirebaseException) {
      debugPrint(
        'FirebaseException plugin: ${error.plugin}, code: ${error.code}',
      );
    } else {
      debugPrint('Account deletion error type: ${error.runtimeType}');
    }
  }

  AccountDeletionStatus _mapReauthentication(
    AccountDeletionReauthStatus status,
  ) => switch (status) {
    AccountDeletionReauthStatus.wrongPassword =>
      AccountDeletionStatus.wrongPassword,
    AccountDeletionReauthStatus.wrongGoogleAccount =>
      AccountDeletionStatus.wrongGoogleAccount,
    AccountDeletionReauthStatus.cancelled =>
      AccountDeletionStatus.reauthenticationCancelled,
    _ => AccountDeletionStatus.reauthenticationFailed,
  };
}
