import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/pages/auth_entry_screen.dart';
import 'package:gubify/pages/name_screen.dart';
import 'package:gubify/services/auth_service.dart';

void main() {
  AuthService serviceFor({
    required _FakeVerificationGateway verification,
    required Future<bool> Function(String userId) userProfileExists,
  }) {
    return AuthService(
      authLinkGateway: _FakeLinkGateway(
        currentUserId: verification.currentUserId,
        anonymous: verification.isCurrentUserAnonymous,
        providerIds: verification.providerIds,
      ),
      authVerificationGateway: verification,
      userProfileExists: userProfileExists,
    );
  }

  Future<void> pumpOnboarding(
    WidgetTester tester, {
    required AuthService service,
  }) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: NameScreen(
          authService: service,
          onBackToSignIn: () async {
            navigatorKey.currentState!.pushAndRemoveUntil<void>(
              MaterialPageRoute(
                builder: (_) => AuthEntryScreen(
                  authService: service,
                  onAuthenticated: () async {},
                  onContinueAnonymously: () async {},
                ),
              ),
              (_) => false,
            );
          },
        ),
      ),
    );
  }

  testWidgets('new anonymous user sees Back and returns to account entry', (
    tester,
  ) async {
    var profileLookups = 0;
    final verification = _FakeVerificationGateway(anonymous: true);
    await pumpOnboarding(
      tester,
      service: serviceFor(
        verification: verification,
        userProfileExists: (_) async {
          profileLookups += 1;
          return false;
        },
      ),
    );

    expect(find.byTooltip('Back to sign in'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to sign in'));
    await tester.pumpAndSettle();

    expect(find.byType(AuthEntryScreen), findsOneWidget);
    expect(find.byType(NameScreen), findsNothing);
    expect(profileLookups, 1);
    expect(verification.deleteCalls, 1);
    expect(verification.signOutCalls, 0);
  });

  testWidgets('anonymous deletion failure falls back to sign out', (
    tester,
  ) async {
    final verification = _FakeVerificationGateway(
      anonymous: true,
      deleteFailure: StateError('delete failed'),
    );
    await pumpOnboarding(
      tester,
      service: serviceFor(
        verification: verification,
        userProfileExists: (_) async => false,
      ),
    );

    await tester.tap(find.byTooltip('Back to sign in'));
    await tester.pumpAndSettle();

    expect(find.byType(AuthEntryScreen), findsOneWidget);
    expect(verification.deleteCalls, 1);
    expect(verification.signOutCalls, 1);
  });

  testWidgets('verified email account is signed out but not deleted', (
    tester,
  ) async {
    final verification = _FakeVerificationGateway(
      providerIds: const ['password'],
      emailVerified: true,
    );
    await pumpOnboarding(
      tester,
      service: serviceFor(
        verification: verification,
        userProfileExists: (_) async => false,
      ),
    );

    expect(find.byTooltip('Back to sign in'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to sign in'));
    await tester.pumpAndSettle();

    expect(find.byType(AuthEntryScreen), findsOneWidget);
    expect(verification.deleteCalls, 0);
    expect(verification.signOutCalls, 1);
    expect(verification.originalUid, 'email-or-google-uid');
  });

  testWidgets('Google account is signed out but not deleted', (tester) async {
    final verification = _FakeVerificationGateway(
      providerIds: const ['google.com'],
      emailVerified: true,
    );
    await pumpOnboarding(
      tester,
      service: serviceFor(
        verification: verification,
        userProfileExists: (_) async => false,
      ),
    );

    await tester.tap(find.byTooltip('Back to sign in'));
    await tester.pumpAndSettle();

    expect(find.byType(AuthEntryScreen), findsOneWidget);
    expect(verification.deleteCalls, 0);
    expect(verification.signOutCalls, 1);
    expect(verification.originalUid, 'email-or-google-uid');
  });

  testWidgets('existing Gubify profile blocks every onboarding cleanup', (
    tester,
  ) async {
    final verification = _FakeVerificationGateway(anonymous: true);
    await pumpOnboarding(
      tester,
      service: serviceFor(
        verification: verification,
        userProfileExists: (_) async => true,
      ),
    );

    await tester.tap(find.byTooltip('Back to sign in'));
    await tester.pump();

    expect(find.byType(NameScreen), findsOneWidget);
    expect(
      find.text('Your Gubify profile already exists. Please reopen the app.'),
      findsOneWidget,
    );
    expect(verification.deleteCalls, 0);
    expect(verification.signOutCalls, 0);
  });

  testWidgets('normal profile form remains available', (tester) async {
    await pumpOnboarding(
      tester,
      service: serviceFor(
        verification: _FakeVerificationGateway(anonymous: true),
        userProfileExists: (_) async => false,
      ),
    );

    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration?.hintText,
      'Your name',
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText() ==
                'I agree to the Terms of Service and acknowledge the Privacy Policy.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(ElevatedButton, 'Continue'), findsOneWidget);
  });
}

class _FakeVerificationGateway implements AuthVerificationGateway {
  _FakeVerificationGateway({
    this.anonymous = false,
    this.providerIds = const ['password'],
    this.emailVerified = false,
    this.deleteFailure,
  });

  final bool anonymous;
  @override
  final List<String> providerIds;
  final bool emailVerified;
  final Object? deleteFailure;
  final String originalUid = 'email-or-google-uid';

  int deleteCalls = 0;
  int signOutCalls = 0;

  @override
  String? currentUserId = 'email-or-google-uid';

  @override
  String? currentUserEmail = 'person@example.com';

  @override
  bool get isCurrentUserAnonymous => anonymous;

  @override
  bool get isCurrentUserEmailVerified => emailVerified;

  @override
  Future<void> deleteCurrentUser() async {
    deleteCalls += 1;
    final failure = deleteFailure;
    if (failure != null) throw failure;
    currentUserId = null;
    currentUserEmail = null;
  }

  @override
  Future<void> reloadCurrentUser() async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    currentUserId = null;
    currentUserEmail = null;
  }
}

class _FakeLinkGateway implements AuthLinkGateway {
  const _FakeLinkGateway({
    required this.currentUserId,
    required this.anonymous,
    required this.providerIds,
  });

  @override
  final String? currentUserId;
  final bool anonymous;
  @override
  final List<String> providerIds;

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
