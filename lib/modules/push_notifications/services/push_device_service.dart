import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../repositories/push_device_repository.dart';

class PushDeviceService {
  PushDeviceService._();
  static final instance = PushDeviceService._();
  static const _installationKey = 'push_device_installation_id';

  StreamSubscription<String>? _refreshSubscription;
  String? _attachedUid;

  Future<String> _installationId() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_installationKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = const Uuid().v4();
    await preferences.setString(_installationKey, created);
    return created;
  }

  Future<void> attach(String uid) async {
    if (uid.isEmpty || Firebase.apps.isEmpty) return;
    _attachedUid = uid;
    await FirebaseMessaging.instance.requestPermission();
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) await refreshToken(uid, token);
    await _refreshSubscription?.cancel();
    _refreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      final currentUid = _attachedUid;
      if (currentUid != null) unawaited(refreshToken(currentUid, token));
    });
  }

  Future<void> refreshToken(String uid, String token) async {
    if (uid.isEmpty || token.isEmpty) return;
    await PushDeviceRepository.instance.save(
      uid: uid,
      deviceId: await _installationId(),
      token: token,
      platform: Platform.isIOS ? 'ios' : 'android',
    );
  }

  /// Returns false only when both invalidation attempts fail.
  Future<bool> detachBeforeSignOut(String uid) async {
    if (Firebase.apps.isEmpty) return true;
    final deviceId = await _installationId();
    var firestoreSucceeded = false;
    var tokenSucceeded = false;
    try {
      await PushDeviceRepository.instance.delete(uid: uid, deviceId: deviceId);
      firestoreSucceeded = true;
    } catch (_) {}
    try {
      await FirebaseMessaging.instance.deleteToken();
      tokenSucceeded = true;
    } catch (_) {}
    if (firestoreSucceeded || tokenSucceeded) {
      _attachedUid = null;
      await _refreshSubscription?.cancel();
      _refreshSubscription = null;
    }
    return firestoreSucceeded || tokenSucceeded;
  }
}
