import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';
import '../../../services/gub_service.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  Stream<QuerySnapshot<Map<String, dynamic>>> notificationsStream(
    String gubId,
  ) => Stream.fromFuture(GubService().currentMembershipHistoryBoundary(gubId))
      .asyncExpand((boundary) {
        if (boundary?.membershipStartedAt case final timestamp?) {
          return NotificationRepository.instance.notificationsStream(
            gubId,
            membershipBoundary: timestamp,
          );
        }
        return Stream.empty();
      });

  Future<void> markAllAsRead({
    required String gubId,
    required String uid,
  }) async {
    final boundary = await GubService().currentMembershipHistoryBoundary(gubId);
    final timestamp = boundary?.membershipStartedAt;
    if (timestamp == null) return;
    await NotificationRepository.instance.markAllAsRead(
      gubId: gubId,
      uid: uid,
      membershipBoundary: timestamp,
    );
  }

  Future<void> send({
    required String gubId,
    required String title,
    required String body,
    required String type,
    required String senderId,
    required String senderName,
    Map<String, dynamic> data = const {},
    bool markSenderAsRead = true,
  }) async {
    final notification = NotificationModel(
      notificationId: _generateId(),
      title: title,
      body: body,
      type: type,
      senderId: senderId,
      senderName: senderName,
      createdAt: Timestamp.now(),
      readBy: markSenderAsRead ? [senderId] : [],
      data: data,
    );

    await NotificationRepository.instance.createNotification(
      gubId: gubId,
      notification: notification,
    );
  }

  String _generateId() {
    final random = Random();

    return DateTime.now().millisecondsSinceEpoch.toString() +
        random.nextInt(999).toString();
  }
}
