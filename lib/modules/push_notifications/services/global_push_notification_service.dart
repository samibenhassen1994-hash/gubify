import 'package:firebase_auth/firebase_auth.dart';

import '../models/global_push_notification.dart';
import '../repositories/global_push_notification_repository.dart';

class GlobalPushNotificationService {
  GlobalPushNotificationService._();
  static final instance = GlobalPushNotificationService._();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  Stream<List<GlobalPushNotification>> watchRecent() {
    final uid = _uid;
    return uid == null ? Stream.value(const <GlobalPushNotification>[]) : GlobalPushNotificationRepository.instance.watchRecent(uid);
  }

  Stream<bool> watchHasUnread() {
    final uid = _uid;
    return uid == null ? Stream.value(false) : GlobalPushNotificationRepository.instance.watchHasUnread(uid);
  }

  Future<void> markRead(String notificationId) {
    final uid = _uid;
    return uid == null ? Future.value() : GlobalPushNotificationRepository.instance.markRead(uid, notificationId);
  }
}
