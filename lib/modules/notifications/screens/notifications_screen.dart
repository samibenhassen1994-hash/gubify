import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/navigation/notification_router.dart';
import '../../../widgets/gub_content_card.dart';
import '../../../widgets/gub_screen_background.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  final String gubId;

  const NotificationsScreen({super.key, required this.gubId});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String? _openingNotificationId;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        NotificationService.instance.markAllAsRead(
          gubId: widget.gubId,
          uid: user.uid,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;

    return GubScreenBackground(
      variant: GubBackgroundAssignments.tasks,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Notifications"),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: NotificationService.instance.notificationsStream(
            widget.gubId,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: GubContentCard(
                  child: Text(
                    "Unable to load notifications.",
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: GubContentCard(
                  child: Text(
                    "No notifications yet.",
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final notifications = snapshot.data!.docs.where((doc) {
              final data = doc.data();
              if (!NotificationModel.targetsUser(data, currentUser.uid)) {
                return false;
              }

              final String type = data["type"] ?? "";
              final String senderId = data["senderId"] ?? "";

              // Le notifiche di esito devono essere visibili a tutti,
              // compreso il creatore della proposta.
              if (type == "proposal_approved" || type == "proposal_rejected") {
                return true;
              }

              // Le altre notifiche restano nascoste al mittente.
              return senderId != currentUser.uid;
            }).toList();

            if (notifications.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: GubContentCard(
                  child: Text(
                    "No notifications yet.",
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final data = notification.data();
                final isOpening = _openingNotificationId == notification.id;

                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    onTap: _openingNotificationId != null
                        ? null
                        : () => _openNotification(
                            notification: notification,
                            uid: currentUser.uid,
                          ),
                    leading: const CircleAvatar(
                      child: Icon(Icons.notifications),
                    ),
                    title: Text(data["title"] ?? ""),
                    subtitle: Text(data["body"] ?? ""),
                    trailing: isOpening
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _formatDate(data["createdAt"]),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _openNotification({
    required QueryDocumentSnapshot<Map<String, dynamic>> notification,
    required String uid,
  }) async {
    if (_openingNotificationId != null) return;

    setState(() => _openingNotificationId = notification.id);

    final documentData = notification.data();
    final routingData = Map<String, dynamic>.from(
      documentData["data"] ?? const <String, dynamic>{},
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
      if (!routingData.containsKey(key) && documentData[key] != null) {
        routingData[key] = documentData[key];
      }
    }

    try {
      await NotificationRepository.instance.markAsRead(
        gubId: widget.gubId,
        notificationId: notification.id,
        uid: uid,
      );
    } catch (error, stackTrace) {
      developer.log(
        "Unable to mark notification as read.",
        name: "NotificationsScreen",
        error: error,
        stackTrace: stackTrace,
      );
    }

    try {
      if (!mounted) return;

      await NotificationRouter.navigate(
        context: context,
        gubId: widget.gubId,
        data: routingData,
      );
    } catch (error, stackTrace) {
      developer.log(
        "Unable to open notification.",
        name: "NotificationsScreen",
        error: error,
        stackTrace: stackTrace,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Unable to open this notification.")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _openingNotificationId = null);
      }
    }
  }

  static String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) {
      return "";
    }

    final date = timestamp.toDate();

    return "${date.day}/${date.month}";
  }
}
