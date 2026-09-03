import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'auth_entry_screen.dart';
import '../pages/name_screen.dart';
import '../screens/welcome_screen.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/local_storage_service.dart';
import '../repositories/user_repository.dart';
import '../modules/profile/repositories/account_deletion_marker_store.dart';
import '../modules/profile/screens/account_deletion_recovery_screen.dart';
import '../modules/profile/services/account_deletion_service.dart';
import '../modules/community/restrictions/services/community_restriction_service.dart';
import '../modules/community/services/community_service.dart';
import '../widgets/startup_artwork_background.dart';
import 'verify_email_screen.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({
    super.key,
    required this.onNavigationReady,
    this.authService,
    this.onAnonymousSignIn,
    this.userProfileExists,
    this.authenticatedAppBuilder,
    this.minimumDisplayDuration = const Duration(seconds: 2),
    this.accountDeletionMarkerStore,
    this.accountDeletionRecoveryBuilder,
    this.clearLocalProfileState,
    this.clearUserCache,
    this.communityDeletionRecovery,
  });

  final VoidCallback onNavigationReady;
  final AuthService? authService;
  final Future<void> Function()? onAnonymousSignIn;
  final Future<bool> Function(String userId)? userProfileExists;
  final WidgetBuilder? authenticatedAppBuilder;
  final Duration minimumDisplayDuration;
  final AccountDeletionMarkerStore? accountDeletionMarkerStore;
  final Widget Function(BuildContext context, AuthService authService)?
  accountDeletionRecoveryBuilder;
  final Future<void> Function()? clearLocalProfileState;
  final VoidCallback? clearUserCache;
  final Future<void> Function()? communityDeletionRecovery;

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  late final AuthService _auth;
  UserService? _userService;
  bool _showAuthEntry = false;
  bool _showVerifyEmail = false;
  bool _isRouting = false;
  bool _hasStartupRoutingError = false;
  bool _showAccountDeletionRecovery = false;
  late final AccountDeletionMarkerStore _accountDeletionMarkerStore;

  @override
  void initState() {
    super.initState();
    _auth = widget.authService ?? AuthService();
    _accountDeletionMarkerStore =
        widget.accountDeletionMarkerStore ??
        SharedPreferencesAccountDeletionMarkerStore();
    _start();
  }

  Future<void> _start() async {
    if (widget.minimumDisplayDuration > Duration.zero) {
      await Future<void>.delayed(widget.minimumDisplayDuration);
    }

    final currentUserId = _auth.currentUserId;
    final deletionUserId = await _accountDeletionMarkerStore.readUserId();
    if (currentUserId == null) {
      if (deletionUserId != null) {
        (widget.clearUserCache ?? UserRepository.instance.clearCache).call();
        await (widget.clearLocalProfileState?.call() ??
            LocalStorageService().clear());
        await _accountDeletionMarkerStore.clear();
      }
      if (mounted) setState(() => _showAuthEntry = true);
      return;
    }

    if (deletionUserId == currentUserId) {
      if (mounted) setState(() => _showAccountDeletionRecovery = true);
      return;
    }
    if (deletionUserId != null) await _accountDeletionMarkerStore.clear();

    await _routeCurrentUserFromStartup();
  }

  Future<void> _routeCurrentUserFromStartup() async {
    try {
      await _routeCurrentUser();
    } on Object {
      if (mounted) setState(() => _hasStartupRoutingError = true);
    }
  }

  Future<void> _continueAnonymously() async {
    final onAnonymousSignIn = widget.onAnonymousSignIn;
    if (onAnonymousSignIn != null) {
      await onAnonymousSignIn();
    } else {
      await _auth.signInAnonymously();
    }
    await _routeCurrentUser();
  }

  Future<void> _routeCurrentUser() async {
    if (_isRouting) return;
    final uid = _auth.currentUserId;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _showAuthEntry = true;
          _showVerifyEmail = false;
          _hasStartupRoutingError = false;
        });
      }
      return;
    }

    if (_auth.requiresCurrentUserEmailVerification) {
      if (mounted) {
        setState(() {
          _showAuthEntry = false;
          _showVerifyEmail = true;
          _hasStartupRoutingError = false;
        });
      }
      return;
    }

    _isRouting = true;
    try {
      final exists =
          await (widget.userProfileExists?.call(uid) ??
              (_userService ??= UserService()).userExists(uid));

      if (!mounted) return;

      if (exists) {
        await _resumeIncompleteCommunityDeletions();
        if (!mounted) return;
        unawaited(_initializePlatformRestriction(uid));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                widget.authenticatedAppBuilder?.call(context) ??
                const WelcomeScreen(),
          ),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onNavigationReady();
        });
      } else {
        final authService = _auth;
        final onNavigationReady = widget.onNavigationReady;
        final userProfileExists = widget.userProfileExists;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (nameScreenContext) => NameScreen(
              authService: authService,
              onNavigationReady: onNavigationReady,
              onBackToSignIn: () async {
                if (!nameScreenContext.mounted) return;
                Navigator.of(nameScreenContext).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => StartupScreen(
                      authService: authService,
                      userProfileExists: userProfileExists,
                      authenticatedAppBuilder: widget.authenticatedAppBuilder,
                      minimumDisplayDuration: Duration.zero,
                      onNavigationReady: onNavigationReady,
                    ),
                  ),
                  (_) => false,
                );
              },
            ),
          ),
        );
      }
    } on Object {
      _isRouting = false;
      rethrow;
    }
  }

  Future<void> _resumeIncompleteCommunityDeletions() async {
    try {
      await (widget.communityDeletionRecovery?.call() ??
          CommunityService.instance.resumeIncompleteOwnedDeletions());
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Community deletion recovery startup check failed: '
          'error=${error.runtimeType}',
        );
      }
    }
  }

  Future<void> _initializePlatformRestriction(String userId) async {
    try {
      await CommunityRestrictionService.instance.initializePlatformRestriction(
        userId,
      );
    } on Object {
      // Missing defaults are already interpreted as unrestricted. Startup must
      // remain available if first-time initialization cannot be completed.
    }
  }

  Future<void> _useAnotherAccount() async {
    await _auth.signOutForAuthSwitch();
    if (!mounted) return;
    setState(() {
      _isRouting = false;
      _showVerifyEmail = false;
      _showAuthEntry = true;
      _hasStartupRoutingError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showAccountDeletionRecovery) {
      return widget.accountDeletionRecoveryBuilder?.call(context, _auth) ??
          AccountDeletionRecoveryScreen(
            authService: _auth,
            deletionService: AccountDeletionService(
              authService: _auth,
              markerStore: _accountDeletionMarkerStore,
            ),
            onCompleted: () {
              if (!mounted) return;
              setState(() {
                _showAccountDeletionRecovery = false;
                _showAuthEntry = true;
              });
            },
          );
    }
    if (_showAuthEntry) {
      return AuthEntryScreen(
        authService: _auth,
        onAuthenticated: _routeCurrentUser,
        onContinueAnonymously: _continueAnonymously,
      );
    }

    if (_showVerifyEmail) {
      return VerifyEmailScreen(
        authService: _auth,
        onVerified: _routeCurrentUser,
        onUseAnotherAccount: _useAnotherAccount,
      );
    }

    if (_hasStartupRoutingError) {
      return StartupArtworkBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Unable to open your account. Please try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() => _hasStartupRoutingError = false);
                    _routeCurrentUserFromStartup();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const StartupArtworkBackground(
      child: Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
      ),
    );
  }
}
