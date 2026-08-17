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

  Stream<List<NotificationModel>> notificationsStream({
    required String gubId,
    required Timestamp membershipBoundary,
  }) {
    return notificationsCollection(gubId)
        .where("createdAt", isGreaterThanOrEqualTo: membershipBoundary)
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((document) {
                final data = Map<String, dynamic>.from(document.data());
                data["notificationId"] = document.id;
                final routingData = Map<String, dynamic>.from(
                  data["data"] ?? const <String, dynamic>{},
                );
                for (final key in const [
                  "type",
                  "module",
                  "screen",
                  "goalId",
                  "proposalId",
                  "taskId",
                  "eventId",
                  "organizedEventId",
                  "calendarEventId",
                  "postId",
                  "gubId",
                ]) {
                  if (!routingData.containsKey(key) && data[key] != null) {
                    routingData[key] = data[key];
                  }
                }
                data["data"] = routingData;
                return NotificationModel.fromFirestore(data);
              })
              .where(isGeneralNotification)
              .toList(growable: false),
        );
  }

  static bool isGeneralNotification(NotificationModel notification) =>
      notification.type != "board_post";

  static bool shouldCountUnreadNotification({
    required NotificationModel notification,
    required String userId,
    required Timestamp membershipBoundary,
  }) {
    if (!_isOnOrAfter(notification.createdAt, membershipBoundary) ||
        notification.readBy.contains(userId) ||
        notification.type == "board_post" ||
        !NotificationModel.targetsUser({"data": notification.data}, userId)) {
      return false;
    }

    if (notification.type == "proposal_approved" ||
        notification.type == "proposal_rejected") {
      return true;
    }

    return notification.senderId != userId;
  }

  static bool _isOnOrAfter(Timestamp value, Timestamp boundary) {
    return value.seconds > boundary.seconds ||
        (value.seconds == boundary.seconds &&
            value.nanoseconds >= boundary.nanoseconds);
  }

  Future<void> markAllAsRead({
    required String gubId,
    required String uid,
    required Timestamp membershipBoundary,
  }) async {
    await GubRepository.instance.ensureActive(gubId);
    final snapshot = await notificationsCollection(
      gubId,
    ).where("createdAt", isGreaterThanOrEqualTo: membershipBoundary).get();

    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data["type"] == "board_post") continue;
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
