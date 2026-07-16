import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/notification_model.dart';

class NotificationRepository {
  NotificationRepository._();

  static final NotificationRepository instance = NotificationRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> notificationsCollection(
    String hubId,
  ) {
    return _firestore.collection("hubs").doc(hubId).collection("notifications");
  }

  Future<void> createNotification({
    required String hubId,
    required NotificationModel notification,
  }) async {
    await notificationsCollection(
      hubId,
    ).doc(notification.notificationId).set(notification.toFirestore());
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> notificationsStream(
    String hubId,
  ) {
    return notificationsCollection(
      hubId,
    ).orderBy("createdAt", descending: true).snapshots();
  }

  Future<void> markAllAsRead({
    required String hubId,
    required String uid,
  }) async {
    final snapshot = await notificationsCollection(hubId).get();

    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final List readBy = List.from(data["readBy"] ?? []);

      if (readBy.contains(uid)) continue;

      readBy.add(uid);

      batch.update(doc.reference, {"readBy": readBy});
    }

    await batch.commit();
  }
}
