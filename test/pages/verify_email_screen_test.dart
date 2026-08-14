import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/pages/verify_email_screen.dart';
import 'package:gubify/services/auth_service.dart';

void main() {
  AuthService serviceFor(_FakeVerificationGateway verification) {
    return AuthService(
      authLinkGateway: const _FakeLinkGateway(),
      authAccountGateway: const _FakeAccountGateway(),
      authVerificationGateway: verification,
      googleCredentialProvider: const _FakeGoogleProvider(),
    );
  }

  Widget app({
    required AuthService service,
    Future<void> Function()? onVerified,
    Future<void> Function()? onUseAnotherAccount,
  }) {
    return MaterialApp(
      home: VerifyEmailScreen(
        authService: service,
        onVerified: onVerified ?? () async {},
        onUseAnotherAccount: onUseAnotherAccount ?? () async {},
      ),
    );
  }

  testWidgets('shows the current email and stays when it is not verified', (
    tester,
  ) async {
    final verification = _FakeVerificationGateway();
    await tester.pumpWidget(app(service: serviceFor(verification)));

    expect(find.text('person@example.com'), findsOneWidget);
    await tester.tap(find.text("I've verified my email"));
    await tester.pump();

    expect(verification.reloadCalls, 1);
    expect(find.byType(VerifyEmailScreen), findsOneWidget);
    expect(find.text('Email not verified yet.'), findsOneWidget);
  });

  testWidgets('continues only after reload confirms verification', (tester) async {
    var verified = false;
    final verification = _FakeVerificationGateway(becomesVerifiedOnReload: true);
    await tester.pumpWidget(
      app(
        service: serviceFor(verification),
        onVerified: () async => verified = true,
      ),
    );

    await tester.tap(find.text("I've verified my email"));
    await tester.pump();

    expect(verified, isTrue);
  });

  testWidgets('resends once and applies a local cooldown', (tester) async {
    final verification = _FakeVerificationGateway();
    await tester.pumpWidget(app(service: serviceFor(verification)));

    await tester.tap(find.text('Resend email'));
    await tester.pump();

    expect(verification.sendCalls, 1);
    expect(find.text('Resend email in 60 seconds'), findsOneWidget);
  });

  testWidgets('use another account delegates to the supplied escape action', (
    tester,
  ) async {
    var switchCalls = 0;
    await tester.pumpWidget(
      app(
        service: serviceFor(_FakeVerificationGateway()),
        onUseAnotherAccount: () async => switchCalls += 1,
      ),
    );

    await tester.tap(find.text('Use another account'));
    await tester.pump();

    expect(switchCalls, 1);
  });
}

class _FakeLinkGateway implements AuthLinkGateway {
  const _FakeLinkGateway();

  @override
  String? get currentUserId => 'uid';

  @override
  bool get isCurrentUserAnonymous => false;

  @override
  List<String> get providerIds => const ['password'];

  @override
  Future<AuthLinkState> linkEmailPassword({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AuthLinkState> linkGoogleIdToken(String idToken) =>
      throw UnimplementedError();
}

class _FakeAccountGateway implements AuthAccountGateway {
  const _FakeAccountGateway();

  @override
  Future<String> registerWithEmailPassword({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<String> signInWithEmailPassword({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<String> signInWithGoogleIdToken(String idToken) =>
      throw UnimplementedError();
}

class _FakeVerificationGateway implements AuthVerificationGateway {
  _FakeVerificationGateway({this.becomesVerifiedOnReload = false});

  @override
  String? currentUserId = 'uid';

  @override
  String? currentUserEmail = 'person@example.com';

  @override
  bool get isCurrentUserAnonymous => false;

  bool emailVerified = false;

  @override
  List<String> get providerIds => const ['password'];

  final bool becomesVerifiedOnReload;
  int reloadCalls = 0;
  int sendCalls = 0;

  @override
  bool get isCurrentUserEmailVerified => emailVerified;

  @override
  Future<void> reloadCurrentUser() async {
    reloadCalls += 1;
    if (becomesVerifiedOnReload) emailVerified = true;
  }

  @override
  Future<void> deleteCurrentUser() async {}

  @override
  Future<void> sendEmailVerification() async => sendCalls += 1;

  @override
  Future<void> signOut() async {
    currentUserId = null;
    currentUserEmail = null;
  }
}

class _FakeGoogleProvider implements GoogleCredentialProvider {
  const _FakeGoogleProvider();

  @override
  Future<GoogleIdentity> authenticate() => throw UnimplementedError();
}
