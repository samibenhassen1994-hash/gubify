import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../repositories/notification_repository.dart';

class NotificationsScreen extends StatefulWidget {
  final String hubId;

  const NotificationsScreen({
    super.key,
    required this.hubId,
  });

  @override
  State<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState
    extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        NotificationRepository.instance.markAllAsRead(
          hubId: widget.hubId,
          uid: user.uid,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser =
        FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: NotificationRepository.instance
            .notificationsStream(widget.hubId),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Text("No notifications yet."),
            );
          }

          final notifications = snapshot.data!.docs
              .where(
                (doc) =>
                    doc["senderId"] !=
                    currentUser.uid,
              )
              .toList();

          if (notifications.isEmpty) {
            return const Center(
              child: Text(
                "No notifications yet.",
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final data =
                  notifications[index].data();

              return Card(
                margin:
                    const EdgeInsets.only(
                        bottom: 12),
                child: ListTile(
                  leading:
                      const CircleAvatar(
                    child: Icon(
                      Icons.notifications,
                    ),
                  ),
                  title: Text(
                    data["title"] ?? "",
                  ),
                  subtitle: Text(
                    data["body"] ?? "",
                  ),
                  trailing: Text(
                    _formatDate(
                      data["createdAt"],
                    ),
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
    );
  }

  static String _formatDate(
    Timestamp? timestamp,
  ) {
    if (timestamp == null) {
      return "";
    }

    final date = timestamp.toDate();

    return "${date.day}/${date.month}";
  }
}