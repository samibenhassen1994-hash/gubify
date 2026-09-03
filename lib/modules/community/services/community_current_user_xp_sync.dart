import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../repositories/community_user_progress_repository.dart';
import 'community_user_xp_cache.dart';

class CommunityCurrentUserAccount {
  const CommunityCurrentUserAccount({
    required this.userId,
    required this.isAnonymous,
  });

  final String? userId;
  final bool isAnonymous;
}

typedef CommunityCurrentUserAccountChanges =
    Stream<CommunityCurrentUserAccount?> Function();
typedef CommunityCurrentUserAccountProvider =
    CommunityCurrentUserAccount? Function();
typedef CommunityCurrentUserXpWatcher = Stream<int> Function(String userId);
typedef CommunityProjectionBackfill = Future<void> Function(String userId);

/// Owns the sole live Community XP document listener for the current account.
///
/// This is intentionally session-scoped: Community surfaces only consume the
/// shared [CommunityUserXpCache] and never subscribe to an individual avatar.
class CommunityCurrentUserXpSync {
  CommunityCurrentUserXpSync({
    required this.currentAccount,
    required this.accountChanges,
    required this.watchUserXp,
    this.backfillProjection,
    CommunityUserXpCache? cache,
  }) : _cache = cache ?? CommunityUserXpCache.instance;

  factory CommunityCurrentUserXpSync.production() {
    final auth = FirebaseAuth.instance;
    return CommunityCurrentUserXpSync(
      currentAccount: () => _toAccount(auth.currentUser),
      accountChanges: () => auth.userChanges().map(_toAccount),
      watchUserXp: CommunityUserProgressRepository.instance.watchUserXp,
      backfillProjection:
          CommunityUserProgressRepository.instance.backfillCommunityIds,
    );
  }

  static final instance = CommunityCurrentUserXpSync.production();

  final CommunityCurrentUserAccountProvider currentAccount;
  final CommunityCurrentUserAccountChanges accountChanges;
  final CommunityCurrentUserXpWatcher watchUserXp;
  final CommunityProjectionBackfill? backfillProjection;
  final CommunityUserXpCache _cache;

  StreamSubscription<CommunityCurrentUserAccount?>? _accountSubscription;
  StreamSubscription<int>? _xpSubscription;
  Future<void> _transitions = Future<void>.value();
  String? _activeUserId;
  var _started = false;
  var _generation = 0;

  @visibleForTesting
  Future<void> get pendingTransitions => _transitions;

  /// Idempotently begins observing the current session.
  Future<void> start() async {
    if (!_started) {
      _started = true;
      _accountSubscription = accountChanges().listen(
        (account) => unawaited(_enqueue(account)),
        onError: (Object error, StackTrace stackTrace) {
          assert(() {
            debugPrint('Community current-user XP auth signal failed: $error');
            return true;
          }());
        },
      );
    }
    await _enqueue(currentAccount());
  }

  /// Re-evaluates the current Firebase user after an in-place account link.
  ///
  /// Firebase preserves the UID for `linkWithCredential`; this explicit hook
  /// means the listener starts even if a platform does not emit a userChanges
  /// event for that provider-link update.
  Future<void> refresh() {
    return start();
  }

  Future<void> dispose() async {
    if (!_started && _accountSubscription == null && _xpSubscription == null) {
      return;
    }
    _started = false;
    _generation++;
    final accountSubscription = _accountSubscription;
    final xpSubscription = _xpSubscription;
    final activeUserId = _activeUserId;
    _accountSubscription = null;
    _xpSubscription = null;
    _activeUserId = null;
    if (activeUserId != null) _cache.releaseCurrentUser(activeUserId);
    await accountSubscription?.cancel();
    await xpSubscription?.cancel();
  }

  Future<void> _enqueue(CommunityCurrentUserAccount? account) {
    _transitions = _transitions.then((_) => _applyAccount(account));
    return _transitions;
  }

  Future<void> _applyAccount(CommunityCurrentUserAccount? account) async {
    if (!_started) return;
    final nextUserId = _linkedUserId(account);
    if (nextUserId == _activeUserId) return;

    final previousUserId = _activeUserId;
    final previousSubscription = _xpSubscription;
    _generation++;
    final generation = _generation;
    _activeUserId = null;
    _xpSubscription = null;
    if (previousUserId != null) _cache.releaseCurrentUser(previousUserId);
    await previousSubscription?.cancel();

    if (!_started || generation != _generation || nextUserId == null) return;
    _activeUserId = nextUserId;
    _cache.retainCurrentUser(nextUserId);
    final backfill = backfillProjection;
    if (backfill != null) {
      unawaited(
        backfill(nextUserId).catchError((Object error, StackTrace stackTrace) {
          assert(() {
            debugPrint('Community membership projection backfill failed: $error');
            return true;
          }());
        }),
      );
    }
    _xpSubscription = watchUserXp(nextUserId).listen(
      (xp) {
        if (_started &&
            generation == _generation &&
            _activeUserId == nextUserId) {
          _cache.applyCurrentUserXp(nextUserId, xp);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        assert(() {
          debugPrint('Community current-user XP stream failed: $error');
          return true;
        }());
      },
    );
  }

  static CommunityCurrentUserAccount? _toAccount(User? user) {
    if (user == null) return null;
    return CommunityCurrentUserAccount(
      userId: user.uid,
      isAnonymous: user.isAnonymous,
    );
  }

  static String? _linkedUserId(CommunityCurrentUserAccount? account) {
    final userId = account?.userId?.trim();
    if (account == null ||
        account.isAnonymous ||
        userId == null ||
        userId.isEmpty) {
      return null;
    }
    return userId;
  }
}
