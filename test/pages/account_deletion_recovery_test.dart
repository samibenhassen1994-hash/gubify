import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/profile/repositories/account_deletion_marker_store.dart';
import 'package:gubify/pages/auth_entry_screen.dart';
import 'package:gubify/pages/startup_screen.dart';
import 'package:gubify/services/auth_service.dart';

void main() {
  testWidgets('matching deletion marker routes to recovery, not onboarding', (
    tester,
  ) async {
    final marker = _MarkerStore('uid');
    await tester.pumpWidget(
      MaterialApp(
        home: StartupScreen(
          authService: _AuthService('uid'),
          accountDeletionMarkerStore: marker,
          minimumDisplayDuration: Duration.zero,
          onNavigationReady: () {},
          clearLocalProfileState: () async {},
          clearUserCache: () {},
          userProfileExists: (_) async => false,
          accountDeletionRecoveryBuilder: (_, _) =>
              const Scaffold(body: Text("Account deletion wasn't completed.")),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Account deletion wasn't completed."), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
    expect(marker.clearCalls, 0);
  });

  testWidgets('stale marker with no Auth user is cleared and opens AuthEntry', (
    tester,
  ) async {
    final marker = _MarkerStore('deleted-uid');
    await tester.pumpWidget(
      MaterialApp(
        home: StartupScreen(
          authService: _AuthService(null),
          accountDeletionMarkerStore: marker,
          minimumDisplayDuration: Duration.zero,
          onNavigationReady: () {},
          clearLocalProfileState: () async {},
          clearUserCache: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AuthEntryScreen), findsOneWidget);
    expect(marker.value, isNull);
    expect(marker.clearCalls, 1);
  });

  testWidgets(
    'normal missing-profile routing remains NameScreen without marker',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StartupScreen(
            authService: _AuthService('uid'),
            accountDeletionMarkerStore: _MarkerStore(null),
            minimumDisplayDuration: Duration.zero,
            onNavigationReady: () {},
            clearLocalProfileState: () async {},
            clearUserCache: () {},
            userProfileExists: (_) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your name'), findsOneWidget);
      expect(find.text("Account deletion wasn't completed."), findsNothing);
    },
  );
}

class _MarkerStore implements AccountDeletionMarkerStore {
  _MarkerStore(this.value);
  String? value;
  int clearCalls = 0;

  @override
  Future<void> clear() async {
    clearCalls++;
    value = null;
  }

  @override
  Future<String?> readUserId() async => value;

  @override
  Future<void> writeUserId(String userId) async => value = userId;
}

class _AuthService extends AuthService {
  _AuthService(this.userId)
    : super(
        authLinkGateway: _LinkGateway(userId),
        authVerificationGateway: _VerificationGateway(userId),
      );

  final String? userId;
  @override
  String? get currentUserId => userId;
}

class _LinkGateway implements AuthLinkGateway {
  const _LinkGateway(this.currentUserId);
  @override
  final String? currentUserId;
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

class _VerificationGateway implements AuthVerificationGateway {
  const _VerificationGateway(this.currentUserId);
  @override
  final String? currentUserId;
  @override
  String? get currentUserEmail => null;
  @override
  bool get isCurrentUserAnonymous => false;
  @override
  bool get isCurrentUserEmailVerified => true;
  @override
  List<String> get providerIds => const [];
  @override
  Future<void> deleteCurrentUser() async {}
  @override
  Future<void> reloadCurrentUser() async {}
  @override
  Future<void> sendEmailVerification() async {}
  @override
  Future<void> signOut() async {}
}
