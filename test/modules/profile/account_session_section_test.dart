import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/profile/widgets/account_session_section.dart';
import 'package:gubify/modules/profile/widgets/google_account_connection_section.dart';
import 'package:gubify/services/auth_service.dart';
import 'package:gubify/widgets/user_header.dart';

void main() {
  AuthService serviceFor({
    required bool anonymous,
    List<String> providerIds = const <String>[],
    _FakeVerificationGateway? verification,
  }) {
    return AuthService(
      authLinkGateway: _FakeAuthLinkGateway(
        anonymous: anonymous,
        providerIds: providerIds,
      ),
      authVerificationGateway: verification ?? _FakeVerificationGateway(),
      clearUserCache: () {},
    );
  }

  Widget subject({
    required AuthService service,
    required Future<void> Function() onLoggedOut,
    required VoidCallback onSecureAccount,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: AccountSessionSection(
          authService: service,
          onLoggedOut: onLoggedOut,
          onSecureAccount: onSecureAccount,
        ),
      ),
    );
  }

  testWidgets('pure anonymous users see the security warning, not logout', (
    tester,
  ) async {
    var secureAccountCalls = 0;
    await tester.pumpWidget(
      subject(
        service: serviceFor(anonymous: true),
        onLoggedOut: () async {},
        onSecureAccount: () => secureAccountCalls += 1,
      ),
    );

    expect(
      find.text('To log out, secure your account first.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Connect Google or email to keep your account and data before signing out.',
      ),
      findsOneWidget,
    );
    expect(find.text('Log out'), findsNothing);

    final title = tester.widget<Text>(
      find.text('To log out, secure your account first.'),
    );
    final description = tester.widget<Text>(
      find.text(
        'Connect Google or email to keep your account and data before signing out.',
      ),
    );
    expect(title.textAlign, TextAlign.center);
    expect(description.textAlign, TextAlign.center);
    expect(
      find.ancestor(
        of: find.text('Secure your account'),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Column &&
              widget.crossAxisAlignment == CrossAxisAlignment.center,
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Secure your account'));
    expect(secureAccountCalls, 1);
  });

  testWidgets('recoverable accounts confirm logout before signing out', (
    tester,
  ) async {
    final verification = _FakeVerificationGateway();
    var loggedOutCalls = 0;
    await tester.pumpWidget(
      subject(
        service: serviceFor(
          anonymous: false,
          providerIds: const ['password'],
          verification: verification,
        ),
        onLoggedOut: () async {
          loggedOutCalls += 1;
        },
        onSecureAccount: () {},
      ),
    );

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(verification.signOutCalls, 0);
    expect(loggedOutCalls, 0);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(_confirmationLogOutButton());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(verification.signOutCalls, 1);
    expect(verification.deleteCalls, 0);
    expect(loggedOutCalls, 1);
  });

  testWidgets('logout disables a second tap while it is running', (tester) async {
    final signOutCompleter = Completer<void>();
    final verification = _FakeVerificationGateway(
      signOutCompleter: signOutCompleter,
    );
    await tester.pumpWidget(
      subject(
        service: serviceFor(
          anonymous: false,
          providerIds: const ['password'],
          verification: verification,
        ),
        onLoggedOut: () async {},
        onSecureAccount: () {},
      ),
    );

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(_confirmationLogOutButton());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(verification.signOutCalls, 1);

    final loadingLogOutButton = find.ancestor(
      of: find.byType(CircularProgressIndicator),
      matching: find.byType(OutlinedButton),
    );
    final logOutButton = tester.widget<OutlinedButton>(loadingLogOutButton);
    expect(logOutButton.onPressed, isNull);

    await tester.tap(loadingLogOutButton);
    await tester.pump();
    expect(verification.signOutCalls, 1);

    signOutCompleter.complete();
    await tester.pump();
    await tester.pump();
    expect(verification.signOutCalls, 1);
  });

  testWidgets('settings contains logout for a recoverable account', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserSettingsSheet(
            authService: serviceFor(
              anonymous: false,
              providerIds: const ['password'],
            ),
            onLoggedOut: () async {},
          ),
        ),
      ),
    );

    expect(find.byType(AccountSessionSection), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    expect(
      find.text('To log out, secure your account first.'),
      findsNothing,
    );
  });

  testWidgets('settings shows anonymous warning and opens account security', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserSettingsSheet(
            authService: serviceFor(anonymous: true),
            onLoggedOut: () async {},
          ),
        ),
      ),
    );

    expect(find.byType(AccountSessionSection), findsOneWidget);
    expect(
      find.text('To log out, secure your account first.'),
      findsOneWidget,
    );
    expect(find.text('Log out'), findsNothing);

    await tester.tap(find.text('Secure your account'));
    await tester.pump();

    expect(find.byType(GoogleAccountConnectionSection), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}

Finder _confirmationLogOutButton() {
  return find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(FilledButton, 'Log out'),
  );
}

class _FakeAuthLinkGateway implements AuthLinkGateway {
  const _FakeAuthLinkGateway({
    required this.anonymous,
    required this.providerIds,
  });

  final bool anonymous;

  @override
  final List<String> providerIds;

  @override
  String? get currentUserId => 'account-uid';

  @override
  bool get isCurrentUserAnonymous => anonymous;

  @override
  Future<AuthLinkState> linkEmailPassword({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AuthLinkState> linkGoogleIdToken(String idToken) =>
      throw UnimplementedError();
}

class _FakeVerificationGateway implements AuthVerificationGateway {
  _FakeVerificationGateway({this.signOutCompleter});

  final Completer<void>? signOutCompleter;
  int signOutCalls = 0;
  int deleteCalls = 0;

  @override
  String? get currentUserEmail => 'person@example.com';

  @override
  String? get currentUserId => 'account-uid';

  @override
  bool get isCurrentUserAnonymous => false;

  @override
  bool get isCurrentUserEmailVerified => true;

  @override
  List<String> get providerIds => const ['password'];

  @override
  Future<void> deleteCurrentUser() async {
    deleteCalls += 1;
  }

  @override
  Future<void> reloadCurrentUser() => throw UnimplementedError();

  @override
  Future<void> sendEmailVerification() => throw UnimplementedError();

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    await signOutCompleter?.future;
  }
}
