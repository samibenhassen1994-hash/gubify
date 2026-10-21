import 'dart:async';

import 'package:flutter/foundation.dart';

import 'platform_admin_repository.dart';

class PlatformAdminIdentity {
  const PlatformAdminIdentity({required this.uid, required this.isAnonymous});
  final String uid;
  final bool isAnonymous;
}

class PlatformAdminService extends ChangeNotifier {
  PlatformAdminService({
    required Stream<PlatformAdminIdentity?> identities,
    required Stream<bool> Function(String uid) watchActive,
    Future<bool> Function(String uid)? readActive,
  }) {
    _readActive = readActive;
    _identitySubscription = identities.listen(
      (identity) {
        final generation = ++_generation;
        _roleSubscription?.cancel();
        _setAdmin(false);
        _uid = identity?.uid;
        if (identity == null || identity.isAnonymous) return;
        try {
          _roleSubscription = watchActive(identity.uid).listen(
            (active) {
              if (generation == _generation) _setAdmin(active);
            },
            onError: (Object error) {
              if (generation == _generation) _setAdmin(false);
            },
            onDone: () {
              if (generation == _generation) _setAdmin(false);
            },
          );
        } catch (_) {
          _setAdmin(false);
        }
      },
      onError: (Object error) {
        _invalidate();
      },
      onDone: _invalidate,
    );
  }

  static final instance = PlatformAdminService(
    identities: PlatformAdminRepository().identities(),
    watchActive: PlatformAdminRepository().watchActive,
    readActive: PlatformAdminRepository().readActive,
  );
  late final StreamSubscription<PlatformAdminIdentity?> _identitySubscription;
  StreamSubscription<bool>? _roleSubscription;
  int _generation = 0;
  bool _isAdmin = false;
  String? _uid;
  late final Future<bool> Function(String uid)? _readActive;
  bool get isAdmin => _isAdmin;
  String? get adminUid => _isAdmin ? _uid : null;
  void requireAdmin() {
    if (!isAdmin) {
      throw StateError('Community moderation access is unavailable.');
    }
  }

  Future<bool> readCurrentActive() async {
    final uid = _uid;
    final readActive = _readActive;
    if (uid == null || readActive == null) return false;
    try {
      final active = await readActive(uid);
      if (uid != _uid) return false;
      _setAdmin(active);
      return active;
    } on Object {
      if (uid == _uid) _setAdmin(false);
      return false;
    }
  }

  void _invalidate() {
    ++_generation;
    _roleSubscription?.cancel();
    _uid = null;
    _setAdmin(false);
  }

  void _setAdmin(bool value) {
    if (_isAdmin == value) return;
    _isAdmin = value;
    notifyListeners();
  }

  @override
  void dispose() {
    ++_generation;
    _identitySubscription.cancel();
    _roleSubscription?.cancel();
    super.dispose();
  }
}
