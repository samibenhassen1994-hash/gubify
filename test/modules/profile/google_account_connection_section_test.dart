import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/profile/widgets/google_account_connection_section.dart';
import 'package:gubify/services/auth_service.dart';

void main() {
  const identity = GoogleIdentity(
    idToken: 'token',
    email: 'person@example.com',
  );

  Widget buildSubject(AuthService authService) {
    return MaterialApp(
      home: Scaffold(
        body: GoogleAccountConnectionSection(authService: authService),
      ),
    );
  }

  AuthService serviceFor({
    _FakeAuthLinkGateway? auth,
    GoogleCredentialProvider? google,
    AuthVerificationGateway? verification,
  }) {
    return AuthService(
      authLinkGateway: auth ?? _FakeAuthLinkGateway(),
      authVerificationGateway: verification ?? _FakeVerificationGateway(),
      googleCredentialProvider:
          google ?? _FakeGoogleCredentialProvider(identity: identity),
    );
  }

  testWidgets('an anonymous user sees the Google connection action', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(serviceFor()));

    expect(find.text('Secure your account'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Create email & password login'), findsOneWidget);
  });

  testWidgets('opens the email and password form', (tester) async {
    await tester.pumpWidget(buildSubject(serviceFor()));

    await tester.tap(find.text('Create email & password login'));
    await tester.pumpAndSettle();

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.text('Create login'), findsOneWidget);
  });

  testWidgets('a password mismatch blocks email binding', (tester) async {
    final auth = _FakeAuthLinkGateway();
    await tester.pumpWidget(buildSubject(serviceFor(auth: auth)));
    await tester.tap(find.text('Create email & password login'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'person@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'first-password');
    await tester.enterText(find.byType(TextFormField).at(2), 'second-password');
    await tester.tap(find.text('Create login'));
    await tester.pump();

    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(auth.emailLinkCalls, 0);
  });

  testWidgets('email binding success removes Secure your account', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(serviceFor()));
    await tester.tap(find.text('Create email & password login'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'person@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'secure-password');
    await tester.enterText(find.byType(TextFormField).at(2), 'secure-password');
    await tester.tap(find.text('Create login'));
    await tester.pumpAndSettle();

    expect(
      find.text('Account secured. Check your email to verify your address.'),
      findsOneWidget,
    );
    expect(find.text('Secure your account'), findsNothing);
  });

  testWidgets('a weak password displays a controlled error', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        serviceFor(
          auth: _FakeAuthLinkGateway(
            emailLinkError: FirebaseAuthException(code: 'weak-password'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Create email & password login'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'person@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.enterText(find.byType(TextFormField).at(2), 'password');
    await tester.tap(find.text('Create login'));
    await tester.pumpAndSettle();

    expect(
      find.text('Choose a stronger password and try again.'),
      findsOneWidget,
    );
    expect(find.text('Secure your account'), findsOneWidget);
  });

  testWidgets('an email already in use displays a controlled error', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        serviceFor(
          auth: _FakeAuthLinkGateway(
            emailLinkError: FirebaseAuthException(code: 'email-already-in-use'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Create email & password login'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'person@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.enterText(find.byType(TextFormField).at(2), 'password');
    await tester.tap(find.text('Create login'));
    await tester.pumpAndSettle();

    expect(
      find.text('This email is already linked to another Gubify account.'),
      findsOneWidget,
    );
    expect(find.text('Secure your account'), findsOneWidget);
  });

  testWidgets('a non-anonymous user does not see Secure your account', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(serviceFor(auth: _FakeAuthLinkGateway(anonymous: false))),
    );

    expect(find.text('Secure your account'), findsNothing);
    expect(find.text('Create email & password login'), findsNothing);
  });

  testWidgets('a linked user sees no Google connection card', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        serviceFor(
          auth: _FakeAuthLinkGateway(providerIds: const ['google.com']),
        ),
      ),
    );

    expect(find.text('Secure your account'), findsNothing);
    expect(find.text('Google connected'), findsNothing);
    expect(find.text('Continue with Google'), findsNothing);
  });

  testWidgets('loading disables a second connection tap', (tester) async {
    final completer = Completer<GoogleIdentity>();
    final google = _CompletingGoogleCredentialProvider(completer);
    await tester.pumpWidget(buildSubject(serviceFor(google: google)));

    await tester.tap(find.text('Continue with Google'));
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    completer.complete(identity);
    await tester.pumpAndSettle();
    expect(find.text('Secure your account'), findsNothing);
  });

  testWidgets('successful linking confirms then removes the card', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(serviceFor()));

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.text('Google account connected'), findsOneWidget);
    expect(find.text('Secure your account'), findsNothing);
    expect(find.text('Continue with Google'), findsNothing);
  });

  testWidgets('cancellation keeps the anonymous connection action available', (
    tester,
  ) async {
    final auth = _FakeAuthLinkGateway();
    await tester.pumpWidget(
      buildSubject(
        serviceFor(
          auth: auth,
          google: _FakeGoogleCredentialProvider(
            error: const GoogleCredentialException(
              GoogleCredentialFailure.cancelled,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(auth.linkCalls, 0);
  });

  testWidgets('a credential collision shows a controlled message', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        serviceFor(
          auth: _FakeAuthLinkGateway(
            linkError: FirebaseAuthException(code: 'credential-already-in-use'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This Google account is already linked to another Gubify account.',
      ),
      findsOneWidget,
    );
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}

class _FakeAuthLinkGateway implements AuthLinkGateway {
  _FakeAuthLinkGateway({
    this.providerIds = const <String>['anonymous'],
    this.linkError,
    this.emailLinkError,
    this.anonymous = true,
  });

  @override
  final List<String> providerIds;

  final FirebaseAuthException? linkError;
  final FirebaseAuthException? emailLinkError;
  final bool anonymous;
  int linkCalls = 0;
  int emailLinkCalls = 0;

  @override
  String? get currentUserId => 'existing-uid';

  @override
  bool get isCurrentUserAnonymous => anonymous;

  @override
  Future<AuthLinkState> linkGoogleIdToken(String idToken) async {
    linkCalls += 1;
    final error = linkError;
    if (error != null) throw error;
    return const AuthLinkState(
      uid: 'existing-uid',
      providerIds: ['anonymous', 'google.com'],
    );
  }

  @override
  Future<AuthLinkState> linkEmailPassword({
    required String email,
    required String password,
  }) async {
    emailLinkCalls += 1;
    final error = emailLinkError;
    if (error != null) throw error;
    return const AuthLinkState(uid: 'existing-uid', providerIds: ['password']);
  }
}

class _FakeGoogleCredentialProvider implements GoogleCredentialProvider {
  _FakeGoogleCredentialProvider({this.identity, this.error});

  final GoogleIdentity? identity;
  final Object? error;

  @override
  Future<GoogleIdentity> authenticate() async {
    final failure = error;
    if (failure != null) throw failure;
    return identity!;
  }
}

class _FakeVerificationGateway implements AuthVerificationGateway {
  @override
  String? get currentUserEmail => 'person@example.com';

  @override
  String? get currentUserId => 'existing-uid';

  @override
  bool get isCurrentUserAnonymous => false;

  @override
  bool get isCurrentUserEmailVerified => false;

  @override
  List<String> get providerIds => const ['password'];

  @override
  Future<void> reloadCurrentUser() async {}

  @override
  Future<void> deleteCurrentUser() async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> signOut() async {}
}

class _CompletingGoogleCredentialProvider implements GoogleCredentialProvider {
  const _CompletingGoogleCredentialProvider(this.completer);

  final Completer<GoogleIdentity> completer;

  @override
  Future<GoogleIdentity> authenticate() => completer.future;
}
