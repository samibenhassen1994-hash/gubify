import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/invites/invite_link_coordinator.dart';
import 'firebase_options.dart';
import 'modules/chat/widgets/gub_chat_overlay.dart';
import 'modules/community/services/community_current_user_xp_sync.dart';
import 'screens/gub/join_gub_screen.dart';
import 'theme/app_theme.dart';
import 'pages/startup_screen.dart';
import 'modules/push_notifications/services/push_notification_coordinator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const GubifyApp());
}

class GubifyApp extends StatefulWidget {
  const GubifyApp({super.key});

  @override
  State<GubifyApp> createState() => _GubifyAppState();
}

class _GubifyAppState extends State<GubifyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final InviteLinkCoordinator _inviteLinkCoordinator;
  late final CommunityCurrentUserXpSync _currentUserXpSync;
  late final PushNotificationCoordinator _pushNotificationCoordinator;

  @override
  void initState() {
    super.initState();
    _inviteLinkCoordinator = InviteLinkCoordinator(
      source: AppLinksInviteLinkSource(),
      openJoin: _openJoin,
    )..start();
    _currentUserXpSync = CommunityCurrentUserXpSync.instance;
    unawaited(_currentUserXpSync.start());
    _pushNotificationCoordinator = PushNotificationCoordinator(navigatorKey: _navigatorKey);
    unawaited(_pushNotificationCoordinator.start());
  }

  Future<void> _openJoin(String visibleCode) async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null || !mounted) return;

    await GubChatOverlay.runWithChatOverlayHidden(
      () => navigator.push<void>(
        MaterialPageRoute(
          builder: (_) => JoinGubScreen(initialCode: visibleCode),
        ),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_inviteLinkCoordinator.dispose());
    unawaited(_currentUserXpSync.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Gubify',
      theme: AppTheme.lightTheme,
      navigatorObservers: [GubChatNavigatorObserver.instance],
      home: StartupScreen(
        onNavigationReady: _inviteLinkCoordinator.markNavigationReady,
      ),
    );
  }
}
