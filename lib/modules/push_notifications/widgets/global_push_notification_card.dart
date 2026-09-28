import 'package:flutter/material.dart';

import '../models/global_push_notification.dart';

class GlobalPushNotificationCard extends StatelessWidget {
  const GlobalPushNotificationCard({super.key, required this.notification, required this.onTap});
  final GlobalPushNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    tileColor: notification.read ? null : Colors.white.withValues(alpha: .10),
    leading: Icon(notification.read ? Icons.notifications_none_rounded : Icons.notifications_rounded),
    title: Text(notification.title),
    subtitle: Text(notification.body),
    onTap: onTap,
  );
}
