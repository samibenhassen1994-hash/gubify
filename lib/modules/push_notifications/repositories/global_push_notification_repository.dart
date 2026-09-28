import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/global_push_notification.dart';

class GlobalPushNotificationRepository {
  GlobalPushNotificationRepository._();
  static final instance = GlobalPushNotificationRepository._();

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('pushNotifications');

  Stream<List<GlobalPushNotification>> watchRecent(String uid) => _collection(uid)
      .orderBy('createdAt', descending: true).limit(50).snapshots().map((snapshot) =>
          snapshot.docs.map((document) => GlobalPushNotification.fromFirestore(document.id, document.data())).toList(growable: false));

  Stream<bool> watchHasUnread(String uid) => _collection(uid)
      .where('read', isEqualTo: false).limit(1).snapshots().map((snapshot) => snapshot.docs.isNotEmpty);

  Future<void> markRead(String uid, String notificationId) =>
      _collection(uid).doc(notificationId).update({'read': true});
}
