import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<NotificationModel>> notificationsStream(String gubId) {
    return Stream.fromFuture(_membershipBoundary(gubId)).asyncExpand(
      (boundary) => boundary == null
          ? Stream.value(const <NotificationModel>[])
          : NotificationRepository.instance.notificationsStream(
              gubId: gubId,
              membershipBoundary: boundary,
            ),
    );
  }

  Stream<List<NotificationModel>> unreadNotificationsStream(String gubId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(const <NotificationModel>[]);

    return Stream.fromFuture(_membershipBoundary(gubId)).asyncExpand((
      boundary,
    ) {
      if (boundary == null) return Stream.value(const <NotificationModel>[]);

      return NotificationRepository.instance
          .notificationsStream(gubId: gubId, membershipBoundary: boundary)
          .map(
            (notifications) => notifications
                .where(
                  (notification) =>
                      NotificationRepository.shouldCountUnreadNotification(
                        notification: notification,
                        userId: user.uid,
                        membershipBoundary: boundary,
                      ),
                )
                .toList(growable: false),
          );
    });
  }

  Future<void> markAllAsRead(String gubId) async {
    final user = _auth.currentUser;
    final boundary = await _membershipBoundary(gubId);
    if (user == null || boundary == null) return;

    await NotificationRepository.instance.markAllAsRead(
      gubId: gubId,
      uid: user.uid,
      membershipBoundary: boundary,
    );
  }

  Future<void> markAsRead({
    required String gubId,
    required String notificationId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError("You must be signed in to update notifications.");
    }

    await NotificationRepository.instance.markAsRead(
      gubId: gubId,
      notificationId: notificationId,
      uid: user.uid,
    );
  }

  Future<Timestamp?> _membershipBoundary(String gubId) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final membership = await _firestore
        .collection("gubs")
        .doc(gubId)
        .collection("members")
        .doc(user.uid)
        .get(const GetOptions(source: Source.server));
    final joinedAt = membership.data()?['joinedAt'];
    return membership.exists && joinedAt is Timestamp ? joinedAt : null;
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
