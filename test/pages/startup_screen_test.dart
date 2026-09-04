import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/profile/repositories/account_deletion_marker_store.dart';
import 'package:gubify/pages/startup_screen.dart';
import 'package:gubify/services/auth_service.dart';

void main() {
  AuthService authenticatedService() {
    const userId = 'owner-uid';
    return AuthService(
      authLinkGateway: const _FakeLinkGateway(userId),
      authVerificationGateway: const _FakeVerificationGateway(userId),
    );
  }

  Future<void> pumpStartup(
    WidgetTester tester, {
    required AuthService authService,
    required Future<void> Function() communityDeletionRecovery,
    VoidCallback? onAuthenticatedAppBuilt,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: StartupScreen(
          authService: authService,
          userProfileExists: (_) async => true,
          authenticatedAppBuilder: (_) {
            onAuthenticatedAppBuilt?.call();
            return const Scaffold(body: Text('Authenticated app'));
          },
          minimumDisplayDuration: Duration.zero,
          accountDeletionMarkerStore: const _FakeDeletionMarkerStore(),
          communityDeletionRecovery: communityDeletionRecovery,
          onNavigationReady: () {},
        ),
      ),
    );
  }

  testWidgets('resumes incomplete Community deletion before opening the app', (
    tester,
  ) async {
    final events = <String>[];

    await pumpStartup(
      tester,
      authService: authenticatedService(),
      communityDeletionRecovery: () async {
        events.add('recovery');
      },
      onAuthenticatedAppBuilt: () => events.add('app'),
    );
    await tester.pumpAndSettle();

    expect(events, ['recovery', 'app']);
    expect(find.text('Authenticated app'), findsOneWidget);
  });

  testWidgets(
    'continues opening the app when Community deletion recovery fails',
    (tester) async {
      var recoveryCalls = 0;

      await pumpStartup(
        tester,
        authService: authenticatedService(),
        communityDeletionRecovery: () async {
          recoveryCalls += 1;
          throw StateError('temporary network failure');
        },
      );
      await tester.pumpAndSettle();

      expect(recoveryCalls, 1);
      expect(find.text('Authenticated app'), findsOneWidget);
    },
  );
}

class _FakeDeletionMarkerStore implements AccountDeletionMarkerStore {
  const _FakeDeletionMarkerStore();

  @override
  Future<void> clear() async {}

  @override
  Future<String?> readUserId() async => null;

  @override
  Future<void> writeUserId(String userId) async {}
}

class _FakeLinkGateway implements AuthLinkGateway {
  const _FakeLinkGateway(this.currentUserId);

  @override
  final String currentUserId;

  @override
  bool get isCurrentUserAnonymous => false;

  @override
  List<String> get providerIds => const ['google.com'];

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
  const _FakeVerificationGateway(this.currentUserId);

  @override
  final String currentUserId;

  @override
  String? get currentUserEmail => 'owner@example.com';

  @override
  bool get isCurrentUserAnonymous => false;

  @override
  bool get isCurrentUserEmailVerified => true;

  @override
  List<String> get providerIds => const ['google.com'];

  @override
  Future<void> deleteCurrentUser() => throw UnimplementedError();

  @override
  Future<void> reloadCurrentUser() => throw UnimplementedError();

  @override
  Future<void> sendEmailVerification() => throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();
}
