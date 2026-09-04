import 'dart:async';

import '../repositories/community_user_progress_repository.dart';

typedef CommunityUserXpLoader =
    Future<Map<String, int>> Function(Set<String> userIds);

class CommunityUserXpCache {
  CommunityUserXpCache({CommunityUserXpLoader? loadXp})
    : _loadXp = loadXp ?? CommunityUserProgressRepository.instance.loadXp;

  static final instance = CommunityUserXpCache();

  final CommunityUserXpLoader _loadXp;
  final Map<String, _XpEntry> _entries = {};
  final Set<_XpLeaseState> _leases = {};

  int get cachedUserCount => _entries.length;

  CommunityUserXpLease acquire(Iterable<String> userIds) {
    final ids = userIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    late final _XpLeaseState state;
    late final StreamController<Map<String, int>> controller;
    controller = StreamController<Map<String, int>>.broadcast(
      onListen: () => scheduleMicrotask(() => _emit(state)),
    );
    state = _XpLeaseState(ids, controller);
    _leases.add(state);
    for (final id in ids) {
      (_entries[id] ??= _XpEntry()).references++;
    }
    _emit(state);
    _loadMissing(ids);
    return CommunityUserXpLease._(
      state.controller.stream,
      () => _release(state),
    );
  }

  void prime(Map<String, int> xpByUserId) {
    for (final entry in xpByUserId.entries) {
      final userId = entry.key.trim();
      if (userId.isEmpty) continue;
      (_entries[userId] ??= _XpEntry())
        ..value = entry.value < 0 ? 0 : entry.value
        ..pendingLocalReward = entry.value < 0 ? 0 : entry.value
        ..loading = null;
    }
    _emitAll();
  }

  /// Seeds XP already paid for by a bounded query without marking a reward.
  /// Live current-user data and an optimistic local reward always win.
  void cacheLoaded(Map<String, int> xpByUserId) {
    for (final item in xpByUserId.entries) {
      final id = item.key.trim();
      if (id.isEmpty) continue;
      final entry = _entries[id] ??= _XpEntry();
      if (entry.pendingLocalReward != null ||
          (entry.retentions > 0 && entry.value != null)) {
        continue;
      }
      entry
        ..value = item.value < 0 ? 0 : item.value
        ..loading = null;
    }
    _emitAll();
  }

  /// Keeps the current linked user's XP available between Community surfaces.
  ///
  /// The session owner releases this retention when the account changes or
  /// signs out. Ordinary UI leases remain responsible for their own lifecycle.
  void retainCurrentUser(String userId) {
    final id = userId.trim();
    if (id.isEmpty) return;
    (_entries[id] ??= _XpEntry()).retentions++;
  }

  void releaseCurrentUser(String userId) {
    final id = userId.trim();
    if (id.isEmpty) return;
    final entry = _entries[id];
    if (entry == null) return;
    if (entry.retentions > 0) entry.retentions--;
    _removeIfUnused(id, entry);
  }

  /// Applies the single live progress-document stream for the current user.
  ///
  /// A completed Best Answer transaction primes the cache immediately. Until
  /// the document listener acknowledges that value, an older in-flight
  /// snapshot cannot make the UI regress. Once acknowledged, later lower
  /// values remain valid (for example, an intentional future reset).
  void applyCurrentUserXp(String userId, int xp) {
    final id = userId.trim();
    if (id.isEmpty) return;
    final normalizedXp = xp < 0 ? 0 : xp;
    final entry = _entries[id] ??= _XpEntry();
    final pendingLocalReward = entry.pendingLocalReward;
    if (pendingLocalReward != null) {
      if (normalizedXp < pendingLocalReward) return;
      entry.pendingLocalReward = null;
    }
    entry
      ..value = normalizedXp
      ..loading = null;
    _emitAll();
  }

  void _loadMissing(Set<String> ids) {
    final missing = ids.where((id) {
      final entry = _entries[id]!;
      return entry.value == null && entry.loading == null;
    }).toSet();
    if (missing.isEmpty) return;

    late final Future<void> loading;
    loading = _loadXp(missing).then(
      (loaded) {
        for (final id in missing) {
          final entry = _entries[id];
          if (entry == null || entry.loading != loading) continue;
          entry
            ..value = loaded[id] ?? 0
            ..loading = null;
        }
        _emitAll();
      },
      onError: (Object error, StackTrace stackTrace) {
        final failedIds = <String>{};
        for (final id in missing) {
          final entry = _entries[id];
          if (entry?.loading != loading) continue;
          entry!.loading = null;
          failedIds.add(id);
        }
        if (failedIds.isEmpty) return;
        for (final lease in _leases) {
          if (lease.ids.any(failedIds.contains)) {
            lease.controller.addError(error, stackTrace);
          }
        }
      },
    );
    for (final id in missing) {
      _entries[id]!.loading = loading;
    }
  }

  void _emitAll() {
    for (final lease in _leases.toList(growable: false)) {
      _emit(lease);
    }
  }

  void _emit(_XpLeaseState lease) {
    if (lease.controller.isClosed) return;
    lease.controller.add(<String, int>{
      for (final id in lease.ids) id: ?_entries[id]?.value,
    });
  }

  Future<void> _release(_XpLeaseState lease) async {
    if (!_leases.remove(lease)) return;
    for (final id in lease.ids) {
      final entry = _entries[id];
      if (entry == null) continue;
      entry.references--;
      _removeIfUnused(id, entry);
    }
    await lease.controller.close();
  }

  void _removeIfUnused(String id, _XpEntry entry) {
    if (entry.references == 0 && entry.retentions == 0) {
      _entries.remove(id);
    }
  }
}

class CommunityUserXpLease {
  CommunityUserXpLease._(this.stream, this._releaseLease);

  final Stream<Map<String, int>> stream;
  final Future<void> Function() _releaseLease;
  var _released = false;

  Future<void> release() async {
    if (_released) return;
    _released = true;
    await _releaseLease();
  }
}

class _XpEntry {
  int? value;
  int references = 0;
  int retentions = 0;
  int? pendingLocalReward;
  Future<void>? loading;
}

class _XpLeaseState {
  _XpLeaseState(this.ids, this.controller);

  final Set<String> ids;
  final StreamController<Map<String, int>> controller;
}
