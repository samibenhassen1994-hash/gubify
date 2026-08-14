import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/profile/models/account_details_model.dart';
import 'package:gubify/modules/profile/repositories/account_repository.dart';
import 'package:gubify/modules/profile/screens/account_screen.dart';
import 'package:gubify/modules/profile/services/account_service.dart';
import 'package:gubify/services/auth_service.dart';

void main() {
  Widget subject({required bool anonymous, required List<String> providers}) {
    final auth = AuthService(
      authLinkGateway: _AuthGateway(anonymous, providers),
      authVerificationGateway: _VerificationGateway(),
    );
    return MaterialApp(
      home: AccountScreen(
        authService: auth,
        accountService: AccountService(
          authService: auth,
          repository: _AccountRepository(),
        ),
      ),
    );
  }

  testWidgets('pure anonymous account shows secure action', (tester) async {
    await tester.pumpWidget(subject(anonymous: true, providers: const []));
    await tester.pumpAndSettle();
    expect(find.text('Anonymous'), findsOneWidget);
    expect(find.text('Google'), findsNothing);
    expect(find.text('Email'), findsOneWidget); // Section title only.
    expect(find.text('Not set'), findsNWidgets(2));
    expect(find.text('Secure your account'), findsOneWidget);
  });

  testWidgets('Google-only account exposes no password or linking action', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(anonymous: false, providers: const ['google.com']),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Chip, 'Google'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Email'), findsNothing);
    expect(find.text('Password'), findsNothing);
    expect(find.text('Add email & password'), findsNothing);
    expect(find.text('Change password'), findsNothing);
  });

  testWidgets('email account can change password', (tester) async {
    await tester.pumpWidget(
      subject(anonymous: false, providers: const ['password']),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Chip, 'Email'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Google'), findsNothing);
    expect(find.text('Change password'), findsOneWidget);
  });

  testWidgets(
    'Google and email are represented as one multi-provider account',
    (tester) async {
      await tester.pumpWidget(
        subject(anonymous: false, providers: const ['google.com', 'password']),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(Chip, 'Google'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Email'), findsOneWidget);
      expect(find.text('Change password'), findsOneWidget);
    },
  );

  test('name cooldown allows first and 30-day changes, but blocks recent', () {
    final auth = AuthService(
      authLinkGateway: const _AuthGateway(false, ['password']),
      authVerificationGateway: _VerificationGateway(),
    );
    final service = AccountService(
      authService: auth,
      repository: _AccountRepository(),
      now: () => DateTime.utc(2026, 8, 14),
    );
    expect(
      service.canChangeName(const AccountDetailsModel(displayName: 'A')),
      isTrue,
    );
    expect(
      service.canChangeName(
        AccountDetailsModel(
          displayName: 'A',
          displayNameChangedAt: Timestamp.fromDate(DateTime.utc(2026, 8, 1)),
        ),
      ),
      isFalse,
    );
    expect(
      service.canChangeName(
        AccountDetailsModel(
          displayName: 'A',
          displayNameChangedAt: Timestamp.fromDate(DateTime.utc(2026, 7, 15)),
        ),
      ),
      isTrue,
    );
  });

  test(
    'name change writes once while empty and identical names do not write',
    () async {
      final repository = _AccountRepository();
      final auth = AuthService(
        authLinkGateway: const _AuthGateway(false, ['password']),
        authVerificationGateway: _VerificationGateway(),
      );
      final service = AccountService(authService: auth, repository: repository);
      const current = AccountDetailsModel(displayName: 'Test User');

      expect(
        (await service.changeDisplayName(
          current: current,
          displayName: '  ',
        )).status,
        NameChangeStatus.invalidName,
      );
      expect(
        (await service.changeDisplayName(
          current: current,
          displayName: 'Test User',
        )).status,
        NameChangeStatus.unchanged,
      );
      expect(
        (await service.changeDisplayName(
          current: current,
          displayName: 'New Name',
        )).isSuccess,
        isTrue,
      );
      expect(repository.changedNames, ['New Name']);
    },
  );

  test(
    'pure anonymous user can perform the first post-onboarding rename',
    () async {
      final repository = _AccountRepository();
      final auth = AuthService(
        authLinkGateway: const _AuthGateway(true, []),
        authVerificationGateway: _VerificationGateway(),
      );
      final service = AccountService(authService: auth, repository: repository);

      final result = await service.changeDisplayName(
        current: const AccountDetailsModel(displayName: 'Anonymous User'),
        displayName: 'New Anonymous Name',
      );

      expect(result.isSuccess, isTrue);
      expect(repository.changedNames, ['New Anonymous Name']);
    },
  );
}

class _AccountRepository implements AccountProfileRepository {
  final List<String> changedNames = [];
  @override
  Future<AccountDetailsModel?> load(String userId) async => AccountDetailsModel(
    displayName: 'Test User',
    createdAt: Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
  );

  @override
  Future<void> changeDisplayName({
    required String userId,
    required String displayName,
  }) async => changedNames.add(displayName);
}

class _AuthGateway implements AuthLinkGateway {
  const _AuthGateway(this.isCurrentUserAnonymous, this.providerIds);
  @override
  final bool isCurrentUserAnonymous;
  @override
  final List<String> providerIds;
  @override
  String? get currentUserId => 'uid';
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
  @override
  String? get currentUserEmail => null;
  @override
  String? get currentUserId => 'uid';
  @override
  bool get isCurrentUserAnonymous => false;
  @override
  bool get isCurrentUserEmailVerified => true;
  @override
  List<String> get providerIds => const ['password'];
  @override
  Future<void> deleteCurrentUser() async {}
  @override
  Future<void> reloadCurrentUser() async {}
  @override
  Future<void> sendEmailVerification() async {}
  @override
  Future<void> signOut() async {}
}
