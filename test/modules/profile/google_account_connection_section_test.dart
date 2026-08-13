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
  }) {
    return AuthService(
      authLinkGateway: auth ?? _FakeAuthLinkGateway(),
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
  });

  @override
  final List<String> providerIds;

  final FirebaseAuthException? linkError;
  int linkCalls = 0;

  @override
  String? get currentUserId => 'existing-uid';

  @override
  bool get isCurrentUserAnonymous => true;

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

class _CompletingGoogleCredentialProvider implements GoogleCredentialProvider {
  const _CompletingGoogleCredentialProvider(this.completer);

  final Completer<GoogleIdentity> completer;

  @override
  Future<GoogleIdentity> authenticate() => completer.future;
}
