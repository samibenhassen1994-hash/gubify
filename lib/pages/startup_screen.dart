import 'package:flutter/material.dart';

import 'auth_entry_screen.dart';
import '../pages/name_screen.dart';
import '../screens/welcome_screen.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
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
  });

  final VoidCallback onNavigationReady;
  final AuthService? authService;
  final Future<void> Function()? onAnonymousSignIn;
  final Future<bool> Function(String userId)? userProfileExists;
  final WidgetBuilder? authenticatedAppBuilder;
  final Duration minimumDisplayDuration;

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

  @override
  void initState() {
    super.initState();
    _auth = widget.authService ?? AuthService();
    _start();
  }

  Future<void> _start() async {
    if (widget.minimumDisplayDuration > Duration.zero) {
      await Future<void>.delayed(widget.minimumDisplayDuration);
    }

    if (_auth.currentUserId == null) {
      if (mounted) setState(() => _showAuthEntry = true);
      return;
    }

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
