import 'package:flutter/material.dart';

import '../../../widgets/gub_screen_background.dart';
import '../../push_notifications/services/global_push_notification_service.dart';
import '../../push_notifications/widgets/global_push_notification_card.dart';
import '../../push_notifications/services/push_notification_coordinator.dart';

class GlobalNotificationsScreen extends StatelessWidget {
  const GlobalNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GubScreenBackground(
      variant: GubBackgroundAssignments.profiles,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Notifications'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: SafeArea(
          top: false,
          child: StreamBuilder(
            stream: GlobalPushNotificationService.instance.watchRecent(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text('Unable to load notifications.'));
              final notifications = snapshot.data ?? const [];
              if (notifications.isEmpty) return const Center(child: Text('Your notifications will appear here.'));
              return ListView.builder(
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return GlobalPushNotificationCard(
                    notification: notification,
                    onTap: () => PushNotificationCoordinator.openFromInbox({
                      ...notification.data,
                      'notificationId': notification.id,
                      'type': notification.type,
                    }),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
