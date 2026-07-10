import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance =
      NotificationService._();

  Future<void> send({
    required String hubId,

    required String title,

    required String body,

    required String type,

    required String senderId,

    required String senderName,

    Map<String, dynamic> data = const {},
  }) async {
   final notification = NotificationModel(
  notificationId: _generateId(),
  title: title,
  body: body,
  type: type,
  senderId: senderId,
  senderName: senderName,
  createdAt: Timestamp.now(),
  readBy: [senderId],
  data: data,
);
    await NotificationRepository.instance
        .createNotification(
      hubId: hubId,
      notification: notification,
    );
  }

  String _generateId() {
    final random = Random();

    return DateTime.now()
            .millisecondsSinceEpoch
            .toString() +
        random.nextInt(999).toString();
  }
}