import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/pages/auth_entry_screen.dart';
import 'package:gubify/pages/name_screen.dart';
import 'package:gubify/pages/startup_screen.dart';
import 'package:gubify/pages/verify_email_screen.dart';
import 'package:gubify/screens/welcome_screen.dart';
import 'package:gubify/services/auth_service.dart';

void main() {
  testWidgets(
    'verified registration keeps its session and reaches NameScreen',
    (tester) async {
      final session = _FakeEmailSession();
      final verification = _SessionVerificationGateway(session);
      final account = _SessionAccountGateway(session);
      var profileLookups = 0;
      final service = AuthService(
        authLinkGateway: _SessionLinkGateway(session),
        authAccountGateway: account,
        authVerificationGateway: verification,
        googleCredentialProvider: const _UnusedGoogleProvider(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StartupScreen(
            authService: service,
            minimumDisplayDuration: Duration.zero,
            onNavigationReady: () {},
            userProfileExists: (uid) async {
              profileLookups += 1;
              expect(uid, session.registeredUid);
              return false;
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AuthEntryScreen), findsOneWidget);
      await tester.tap(find.text('Create account'));
      await tester.pump();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'person@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password');
      await tester.enterText(find.byType(TextFormField).at(2), 'password');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(find.byType(VerifyEmailScreen), findsOneWidget);
      expect(account.registrationCalls, 1);
      expect(verification.sendCalls, 1);
      expect(profileLookups, 0);

      await tester.tap(find.text("I've verified my email"));
      await tester.pump();

      expect(find.byType(VerifyEmailScreen), findsOneWidget);
      expect(find.text('Email not verified yet.'), findsOneWidget);
      expect(verification.signOutCalls, 0);

      session.emailVerified = true;
      await tester.tap(find.text("I've verified my email"));
      await tester.pumpAndSettle();

      expect(find.byType(VerifyEmailScreen), findsNothing);
      expect(find.byType(NameScreen), findsOneWidget);
      expect(find.byType(AuthEntryScreen), findsNothing);
      expect(verification.signOutCalls, 0);
      expect(verification.deleteCalls, 0);
      expect(profileLookups, 1);
      expect(session.registeredUid, 'verified-email-uid');
      expect(session.currentUid, session.registeredUid);
      expect(find.byTooltip('Back to sign in'), findsOneWidget);
      expect(verification.deleteCalls, 0);
    },
  );

  testWidgets('verified account with a profile keeps its session and opens app', (
    tester,
  ) async {
    final session = _FakeEmailSession()
      ..currentUid = 'existing-email-uid'
      ..registeredUid = 'existing-email-uid'
      ..email = 'person@example.com';
    final verification = _SessionVerificationGateway(session);
    final service = AuthService(
      authLinkGateway: _SessionLinkGateway(session),
      authAccountGateway: _SessionAccountGateway(session),
      authVerificationGateway: verification,
      googleCredentialProvider: const _UnusedGoogleProvider(),
    );
    var profileLookups = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StartupScreen(
          authService: service,
          minimumDisplayDuration: Duration.zero,
          onNavigationReady: () {},
          authenticatedAppBuilder: (_) =>
              const Scaffold(body: Text('TEST_APP_DESTINATION')),
          userProfileExists: (uid) async {
            profileLookups += 1;
            expect(uid, 'existing-email-uid');
            return true;
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(VerifyEmailScreen), findsOneWidget);
    session.emailVerified = true;
    await tester.tap(find.text("I've verified my email"));
    await tester.pumpAndSettle();

    expect(profileLookups, 1);
    expect(verification.signOutCalls, 0);
    expect(session.currentUid, 'existing-email-uid');
    expect(find.text('TEST_APP_DESTINATION'), findsOneWidget);
    expect(find.byType(WelcomeScreen), findsNothing);
    expect(find.byType(NameScreen), findsNothing);
  });

  testWidgets('use another account signs out and returns to auth entry', (
    tester,
  ) async {
    final session = _FakeEmailSession()
      ..currentUid = 'unverified-email-uid'
      ..registeredUid = 'unverified-email-uid'
      ..email = 'person@example.com';
    final verification = _SessionVerificationGateway(session);
    final service = AuthService(
      authLinkGateway: _SessionLinkGateway(session),
      authAccountGateway: _SessionAccountGateway(session),
      authVerificationGateway: verification,
      googleCredentialProvider: const _UnusedGoogleProvider(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StartupScreen(
          authService: service,
          minimumDisplayDuration: Duration.zero,
          onNavigationReady: () {},
          userProfileExists: (_) async => true,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(VerifyEmailScreen), findsOneWidget);
    await tester.tap(find.text('Use another account'));
    await tester.pumpAndSettle();

    expect(verification.signOutCalls, 1);
    expect(session.currentUid, isNull);
    expect(find.byType(AuthEntryScreen), findsOneWidget);
  });

  testWidgets('profile routing failure resets loading and allows retry', (
    tester,
  ) async {
    final session = _FakeEmailSession()
      ..registeredUid = 'verified-email-uid'
      ..email = 'person@example.com'
      ..emailVerified = true;
    final verification = _SessionVerificationGateway(session);
    final account = _SessionAccountGateway(session);
    var profileLookups = 0;
    final service = AuthService(
      authLinkGateway: _SessionLinkGateway(session),
      authAccountGateway: account,
      authVerificationGateway: verification,
      googleCredentialProvider: const _UnusedGoogleProvider(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StartupScreen(
          authService: service,
          minimumDisplayDuration: Duration.zero,
          onNavigationReady: () {},
          userProfileExists: (_) async {
            profileLookups += 1;
            if (profileLookups == 1) throw StateError('temporary failure');
            return false;
          },
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'person@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(find.byType(AuthEntryScreen), findsOneWidget);
    expect(
      find.text('Unable to open your account. Please try again.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Sign in'))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(profileLookups, 2);
    expect(account.emailSignInCalls, 2);
    expect(find.byType(NameScreen), findsOneWidget);
  });
}

class _FakeEmailSession {
  String? currentUid;
  String? registeredUid;
  String? lastSignedInUid;
  String? email;
  bool emailVerified = false;
}

class _SessionVerificationGateway implements AuthVerificationGateway {
  _SessionVerificationGateway(this.session);

  final _FakeEmailSession session;
  int sendCalls = 0;
  int reloadCalls = 0;
  int signOutCalls = 0;
  int deleteCalls = 0;

  @override
  String? get currentUserId => session.currentUid;

  @override
  String? get currentUserEmail => session.email;

  @override
  bool get isCurrentUserAnonymous => false;

  @override
  bool get isCurrentUserEmailVerified => session.emailVerified;

  @override
  List<String> get providerIds =>
      session.currentUid == null ? const [] : const ['password'];

  @override
  Future<void> deleteCurrentUser() async {
    deleteCalls += 1;
    session.currentUid = null;
  }

  @override
  Future<void> reloadCurrentUser() async => reloadCalls += 1;

  @override
  Future<void> sendEmailVerification() async => sendCalls += 1;

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    session.currentUid = null;
  }
}

class _SessionAccountGateway implements AuthAccountGateway {
  _SessionAccountGateway(this.session);

  final _FakeEmailSession session;
  int registrationCalls = 0;
  int emailSignInCalls = 0;

  @override
  Future<String> registerWithEmailPassword({
    required String email,
    required String password,
  }) async {
    registrationCalls += 1;
    session.registeredUid = 'verified-email-uid';
    session.currentUid = session.registeredUid;
    session.email = email;
    session.emailVerified = false;
    return session.registeredUid!;
  }

  @override
  Future<String> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    emailSignInCalls += 1;
    session.currentUid = session.registeredUid;
    session.lastSignedInUid = session.currentUid;
    session.email = email;
    return session.currentUid!;
  }

  @override
  Future<String> signInWithGoogleIdToken(String idToken) =>
      throw UnimplementedError();
}

class _SessionLinkGateway implements AuthLinkGateway {
  const _SessionLinkGateway(this.session);

  final _FakeEmailSession session;

  @override
  String? get currentUserId => session.currentUid;

  @override
  bool get isCurrentUserAnonymous => false;

  @override
  List<String> get providerIds =>
      session.currentUid == null ? const [] : const ['password'];

  @override
  Future<AuthLinkState> linkEmailPassword({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AuthLinkState> linkGoogleIdToken(String idToken) =>
      throw UnimplementedError();
}

class _UnusedGoogleProvider implements GoogleCredentialProvider {
  const _UnusedGoogleProvider();

  @override
  Future<GoogleIdentity> authenticate() => throw UnimplementedError();
}
