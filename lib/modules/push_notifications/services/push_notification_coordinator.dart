import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../navigation/global_push_notification_router.dart';
import 'global_push_notification_service.dart';

const globalNotificationChannelId = 'gubify_global_notifications';

class PushNotificationCoordinator {
  PushNotificationCoordinator({required this.navigatorKey});
  final GlobalKey<NavigatorState> navigatorKey;
  final _openedIds = <String>{};

  Future<void> start() async {
    const channel = AndroidNotificationChannel(
      globalNotificationChannelId,
      'Gubify notifications',
      description: 'Global Gubify notifications',
      importance: Importance.high,
      showBadge: true,
    );
    await FlutterLocalNotificationsPlugin().resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
    FirebaseMessaging.onMessageOpenedApp.listen(_openMessage);
    FirebaseMessaging.onMessage.listen((_) {}); // Inbox/bell stream is authoritative; no duplicate local notification.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) await _openMessage(initial);
  }

  Future<void> _openMessage(RemoteMessage message) => open(message.data);

  Future<void> open(Map<String, dynamic> rawData) async {
    final notificationId = rawData['notificationId']?.toString();
    final type = rawData['type']?.toString();
    if (notificationId == null || type == null || !_openedIds.add(notificationId)) return;
    final data = rawData.map((key, value) => MapEntry(key, value.toString()));
    await GlobalPushNotificationService.instance.markRead(notificationId);
    final context = navigatorKey.currentContext;
    if (context != null) {
      // The context is retrieved only after the awaited read transition.
      // ignore: use_build_context_synchronously
      await GlobalPushNotificationRouter().open(context, data);
    }
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}
