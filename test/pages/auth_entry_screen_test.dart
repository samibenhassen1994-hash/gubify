import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/pages/auth_entry_screen.dart';
import 'package:gubify/pages/startup_screen.dart';
import 'package:gubify/modules/legal/privacy_policy_screen.dart';
import 'package:gubify/modules/legal/terms_screen.dart';
import 'package:gubify/services/auth_service.dart';

void main() {
  AuthService serviceFor({
    GoogleCredentialProvider? google,
    AuthAccountGateway? account,
    PasswordResetGateway? passwordReset,
  }) {
    return AuthService(
      authLinkGateway: const _FakeAuthLinkGateway(),
      authAccountGateway: account ?? _FakeAuthAccountGateway(),
      passwordResetGateway: passwordReset,
      googleCredentialProvider:
          google ??
          const _FakeGoogleCredentialProvider(
            GoogleIdentity(idToken: 'token', email: 'person@example.com'),
          ),
    );
  }

  Widget app({
    required AuthService service,
    Future<void> Function()? onAuthenticated,
    Future<void> Function()? onContinueAnonymously,
  }) {
    return MaterialApp(
      home: AuthEntryScreen(
        authService: service,
        onAuthenticated: onAuthenticated ?? () async {},
        onContinueAnonymously: onContinueAnonymously ?? () async {},
      ),
    );
  }

  testWidgets('shows the explicit anonymous and account entry actions', (
    tester,
  ) async {
    await tester.pumpWidget(app(service: serviceFor()));

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('or'), findsOneWidget);
    expect(find.text('Continue without an account'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byKey(const ValueKey('auth-entry-background')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-entry-logo')), findsOneWidget);
    expect(
      (tester
                  .widget<Image>(
                    find.byKey(const ValueKey('auth-entry-background')),
                  )
                  .image
              as AssetImage)
          .assetName,
      AuthEntryScreen.backgroundAsset,
    );
    expect(
      tester
          .widget<Image>(find.byKey(const ValueKey('auth-entry-background')))
          .fit,
      BoxFit.cover,
    );
    expect(
      (tester.widget<Image>(find.byKey(const ValueKey('auth-entry-logo'))).image
              as AssetImage)
          .assetName,
      AuthEntryScreen.logoAsset,
    );
    expect(
      tester.getTopLeft(find.text('Continue with Google')).dy,
      greaterThan(tester.getTopLeft(find.text('Create account')).dy),
    );
  });

  testWidgets('startup does not create an anonymous user automatically', (
    tester,
  ) async {
    var anonymousSignInCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StartupScreen(
          authService: serviceFor(),
          minimumDisplayDuration: Duration.zero,
          onNavigationReady: () {},
          onAnonymousSignIn: () async => anonymousSignInCalls += 1,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AuthEntryScreen), findsOneWidget);
    expect(find.text('Continue without an account'), findsOneWidget);
    expect(anonymousSignInCalls, 0);
  });

  testWidgets('creates an anonymous session only after the explicit action', (
    tester,
  ) async {
    var anonymousContinuationCalls = 0;
    await tester.pumpWidget(
      app(
        service: serviceFor(),
        onContinueAnonymously: () async => anonymousContinuationCalls += 1,
      ),
    );

    expect(anonymousContinuationCalls, 0);
    final anonymousAction = find.text('Continue without an account');
    await tester.ensureVisible(anonymousAction);
    await tester.pumpAndSettle();
    await tester.tap(anonymousAction);
    await tester.pumpAndSettle();
    expect(anonymousContinuationCalls, 1);
  });

  testWidgets(
    'successful Google sign-in delegates to the authenticated route',
    (tester) async {
      var authenticated = false;
      await tester.pumpWidget(
        app(
          service: serviceFor(),
          onAuthenticated: () async => authenticated = true,
        ),
      );

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      expect(authenticated, isTrue);
    },
  );

  testWidgets('cancelled Google sign-in leaves the entry actions available', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        service: serviceFor(
          google: const _ThrowingGoogleCredentialProvider(
            GoogleCredentialException(GoogleCredentialFailure.cancelled),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Continue with Google'));
    await tester.pump();

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('email collision shows a controlled error and keeps the form', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        service: serviceFor(
          account: _FakeAuthAccountGateway(
            emailError: FirebaseAuthException(code: 'email-already-in-use'),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'person@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(
      find.text('This email is already linked to an account.'),
      findsOneWidget,
    );
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('shows Forgot password only in sign in mode', (tester) async {
    await tester.pumpWidget(app(service: serviceFor()));

    expect(find.text('Forgot password?'), findsOneWidget);
    final forgotPasswordAlignment = find.byWidgetPredicate(
      (widget) =>
          widget is Align &&
          widget.alignment == Alignment.center &&
          widget.child is TextButton,
    );
    expect(forgotPasswordAlignment, findsOneWidget);

    await tester.tap(find.text('Create account'));
    await tester.pump();
    expect(find.text('Forgot password?'), findsNothing);

    final signInModeAction = find.text('Already have an account? Sign in');
    await tester.ensureVisible(signInModeAction);
    await tester.tap(signInModeAction);
    await tester.pump();
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('password reset prefills email and submits once', (tester) async {
    final passwordReset = _FakePasswordResetGateway();
    await tester.pumpWidget(
      app(service: serviceFor(passwordReset: passwordReset)),
    );

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'person@example.com',
    );
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    final resetEmail = tester.widget<TextFormField>(
      find.byType(TextFormField).last,
    );
    expect(resetEmail.controller?.text, 'person@example.com');

    await tester.tap(find.text('Send reset email'));
    await tester.pumpAndSettle();

    expect(passwordReset.emails, ['person@example.com']);
    expect(
      find.text(
        "If an account exists for this email, you'll receive a password reset link.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('invalid reset email does not submit', (tester) async {
    final passwordReset = _FakePasswordResetGateway();
    await tester.pumpWidget(
      app(service: serviceFor(passwordReset: passwordReset)),
    );

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send reset email'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(passwordReset.emails, isEmpty);
  });

  testWidgets('password reset errors remain controlled', (tester) async {
    final passwordReset = _FakePasswordResetGateway(
      error: FirebaseAuthException(code: 'network-request-failed'),
    );
    await tester.pumpWidget(
      app(service: serviceFor(passwordReset: passwordReset)),
    );

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).last,
      'person@example.com',
    );
    await tester.tap(find.text('Send reset email'));
    await tester.pumpAndSettle();

    expect(
      find.text('Check your internet connection and try again.'),
      findsOneWidget,
    );
  });

  testWidgets('password reset prevents a duplicate submission', (tester) async {
    final completer = Completer<void>();
    final passwordReset = _FakePasswordResetGateway(completer: completer);
    await tester.pumpWidget(
      app(service: serviceFor(passwordReset: passwordReset)),
    );

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).last,
      'person@example.com',
    );
    await tester.tap(find.text('Send reset email'));
    await tester.pump();

    final sendButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.byType(CircularProgressIndicator),
        matching: find.byType(FilledButton),
      ),
    );
    expect(sendButton.onPressed, isNull);
    expect(passwordReset.emails, ['person@example.com']);

    completer.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('requires terms acceptance before creating an email account', (
    tester,
  ) async {
    final account = _FakeAuthAccountGateway();
    await tester.pumpWidget(app(service: serviceFor(account: account)));

    await tester.tap(find.text('Create account'));
    await tester.pump();

    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('or'), findsNothing);
    expect(find.text('Continue without an account'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Create account'),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'new@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.enterText(find.byType(TextFormField).at(2), 'password');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();

    expect(account.registrationCalls, 0);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Create account'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('restores Google entry when returning to sign in mode', (
    tester,
  ) async {
    await tester.pumpWidget(app(service: serviceFor()));

    await tester.tap(find.text('Create account'));
    await tester.pump();
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('or'), findsNothing);

    final signInModeAction = find.text('Already have an account? Sign in');
    await tester.ensureVisible(signInModeAction);
    await tester.pumpAndSettle();
    await tester.tap(signInModeAction);
    await tester.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('or'), findsOneWidget);
  });

  testWidgets('terms and privacy links open the existing legal screens', (
    tester,
  ) async {
    await tester.pumpWidget(app(service: serviceFor()));
    await tester.tap(find.text('Create account'));
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('Terms of Service'),
      ),
      findsOneWidget,
    );

    _linkRecognizer(tester, 'Terms of Service').onTap!.call();
    await tester.pumpAndSettle();
    expect(find.byType(TermsScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    _linkRecognizer(tester, 'Privacy Policy').onTap!.call();
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
  });
}

TapGestureRecognizer _linkRecognizer(WidgetTester tester, String label) {
  final richText = tester
      .widgetList<RichText>(find.byType(RichText))
      .firstWhere((widget) => widget.text.toPlainText().contains(label));
  final span = _findTextSpan(richText.text, label);
  final recognizer = span.recognizer;
  if (recognizer is! TapGestureRecognizer) {
    throw TestFailure('TextSpan "$label" has no TapGestureRecognizer.');
  }
  return recognizer;
}

TextSpan _findTextSpan(InlineSpan root, String label) {
  if (root is TextSpan) {
    if (root.text == label) return root;

    for (final child in root.children ?? const <InlineSpan>[]) {
      try {
        return _findTextSpan(child, label);
      } on TestFailure {
        // Continue searching the remaining branches.
      }
    }
  }

  throw TestFailure('TextSpan "$label" was not found.');
}

class _FakeAuthLinkGateway implements AuthLinkGateway {
  const _FakeAuthLinkGateway();

  @override
  String? get currentUserId => null;

  @override
  bool get isCurrentUserAnonymous => false;

  @override
  List<String> get providerIds => const [];

  @override
  Future<AuthLinkState> linkEmailPassword({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AuthLinkState> linkGoogleIdToken(String idToken) =>
      throw UnimplementedError();
}

class _FakeAuthAccountGateway implements AuthAccountGateway {
  _FakeAuthAccountGateway({this.emailError});

  final FirebaseAuthException? emailError;
  int registrationCalls = 0;

  @override
  Future<String> registerWithEmailPassword({
    required String email,
    required String password,
  }) async {
    registrationCalls += 1;
    return 'new-user';
  }

  @override
  Future<String> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final error = emailError;
    if (error != null) throw error;
    return 'email-user';
  }

  @override
  Future<String> signInWithGoogleIdToken(String idToken) async => 'google-user';
}

class _FakePasswordResetGateway implements PasswordResetGateway {
  _FakePasswordResetGateway({this.error, this.completer});

  final FirebaseAuthException? error;
  final Completer<void>? completer;
  final List<String> emails = [];

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    emails.add(email);
    final failure = error;
    if (failure != null) throw failure;
    await completer?.future;
  }
}

class _FakeGoogleCredentialProvider implements GoogleCredentialProvider {
  const _FakeGoogleCredentialProvider(this.identity);

  final GoogleIdentity identity;

  @override
  Future<GoogleIdentity> authenticate() async => identity;
}

class _ThrowingGoogleCredentialProvider implements GoogleCredentialProvider {
  const _ThrowingGoogleCredentialProvider(this.error);

  final Object error;

  @override
  Future<GoogleIdentity> authenticate() async => throw error;
}
