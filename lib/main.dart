import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/app_links/community_app_link_handler.dart';
import 'core/app_links/gubify_app_link_coordinator.dart';
import 'firebase_options.dart';
import 'modules/chat/widgets/gub_chat_overlay.dart';
import 'modules/community/screens/community_public_details_screen.dart';
import 'modules/community/services/community_service.dart';
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
  late final GubifyAppLinkCoordinator _appLinkCoordinator;
  late final CommunityAppLinkHandler _communityAppLinkHandler;
  late final CommunityCurrentUserXpSync _currentUserXpSync;
  late final PushNotificationCoordinator _pushNotificationCoordinator;

  @override
  void initState() {
    super.initState();
    _communityAppLinkHandler = CommunityAppLinkHandler(
      resolveCommunityId:
          CommunityService.instance.resolvePublicCommunityIdBySlug,
      openCommunity: _openCommunityById,
      showUnavailable: _showCommunityUnavailable,
    );
    _appLinkCoordinator = GubifyAppLinkCoordinator(
      source: AppLinksGubifyAppLinkSource(),
      openInvite: _openJoin,
      openCommunity: _communityAppLinkHandler.open,
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

  Future<void> _openCommunityById(String communityId) async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null || !mounted) return;

    await GubChatOverlay.runWithChatOverlayHidden(
      () => navigator.push<void>(
        MaterialPageRoute(
          builder: (_) =>
              CommunityPublicDetailsScreen(communityId: communityId),
        ),
      ),
    );
  }

  Future<void> _showCommunityUnavailable() async {
    final context = _navigatorKey.currentContext;
    if (context == null || !mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('This Community is no longer available.')),
    );
  }

  @override
  void dispose() {
    unawaited(_appLinkCoordinator.dispose());
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
        onNavigationReady: _appLinkCoordinator.markNavigationReady,
      ),
    );
  }
}
