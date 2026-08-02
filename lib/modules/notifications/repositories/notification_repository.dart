import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/notification_model.dart';
import '../../../repositories/gub_repository.dart';

class NotificationRepository {
  NotificationRepository._();

  static final NotificationRepository instance = NotificationRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> notificationsCollection(
    String gubId,
  ) {
    return _firestore.collection("gubs").doc(gubId).collection("notifications");
  }

  Future<void> createNotification({
    required String gubId,
    required NotificationModel notification,
  }) async {
    await GubRepository.instance.ensureActive(gubId);
    await notificationsCollection(
      gubId,
    ).doc(notification.notificationId).set(notification.toFirestore());
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> notificationsStream(
    String gubId,
  ) {
    return notificationsCollection(
      gubId,
    ).orderBy("createdAt", descending: true).snapshots();
  }

  Future<void> markAllAsRead({
    required String gubId,
    required String uid,
  }) async {
    await GubRepository.instance.ensureActive(gubId);
    final snapshot = await notificationsCollection(gubId).get();

    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (!NotificationModel.targetsUser(data, uid)) continue;

      final List readBy = List.from(data["readBy"] ?? []);

      if (readBy.contains(uid)) continue;

      readBy.add(uid);

      batch.update(doc.reference, {"readBy": readBy});
    }

    await batch.commit();
  }

  Future<void> markAsRead({
    required String gubId,
    required String notificationId,
    required String uid,
  }) async {
    await GubRepository.instance.ensureActive(gubId);
    await notificationsCollection(gubId).doc(notificationId).update({
      "readBy": FieldValue.arrayUnion([uid]),
    });
  }
}
