import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_model.dart';
import 'package:gubify/modules/community/repositories/community_repository.dart';
import 'package:gubify/modules/community/screens/community_explorer_screen.dart';
import 'package:gubify/modules/community/services/community_service.dart';
import 'package:gubify/modules/community/widgets/community_linked_account_gate.dart';
import 'package:gubify/services/auth_service.dart';

const _community = CommunityModel(
  communityId: 'community-1',
  name: 'Public Community',
  ownerId: 'owner',
  memberCount: 1,
  visibility: CommunityModel.publicVisibility,
  createdAt: null,
  type: CommunityModel.defaultType,
  language: CommunityModel.defaultLanguage,
  description: '',
  accessMode: CommunityModel.openAccessMode,
);

void main() {
  AuthService authService({bool anonymous = true}) => AuthService(
    authLinkGateway: _GateAuthLinkGateway(anonymous: anonymous),
    authVerificationGateway: _GateVerificationGateway(),
    googleCredentialProvider: const _GateGoogleCredentialProvider(),
  );

  testWidgets('anonymous account sees the polished linking gate', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showCommunityLinkedAccountGate(
                context,
                authService: authService(),
              ),
              child: const Text('Open gate'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open gate'));
    await tester.pumpAndSettle();

    expect(find.text('Link your account'), findsOneWidget);
    expect(find.byIcon(Icons.link_rounded), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Create email & password login'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Not now dismisses the gate with false', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showCommunityLinkedAccountGate(
                  context,
                  authService: authService(),
                );
              },
              child: const Text('Open gate'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open gate'));
    await tester.pumpAndSettle();
    final notNow = find.text('Not now');
    await tester.ensureVisible(notNow);
    await tester.pump();
    await tester.tap(notNow);
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('successful account linking closes the gate with true', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showCommunityLinkedAccountGate(
                  context,
                  authService: authService(),
                );
              },
              child: const Text('Open gate'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open gate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(find.text('Link your account'), findsNothing);
  });

  testWidgets('linked account bypasses the gate', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showCommunityLinkedAccountGate(
                  context,
                  authService: authService(anonymous: false),
                );
              },
              child: const Text('Open gate'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open gate'));
    await tester.pump();

    expect(result, isTrue);
    expect(find.text('Link your account'), findsNothing);
  });

  test('Community mutations reject an anonymous account', () {
    for (final action in [
      'create a community',
      'join a community',
      'request access to a community',
    ]) {
      expect(
        () => requireLinkedCommunityAccount(
          isSignedIn: true,
          isAnonymous: true,
          action: action,
        ),
        throwsA(isA<CommunityLinkedAccountRequiredException>()),
      );
    }
  });

  test('Community mutations accept a linked account', () {
    expect(
      () => requireLinkedCommunityAccount(
        isSignedIn: true,
        isAnonymous: false,
        action: 'join a community',
      ),
      returnsNormally,
    );
  });

  testWidgets(
    'anonymous Explorer loads public results without creating joined stream',
    (tester) async {
      var joinedSubscriptions = 0;
      final joinedController = StreamController<Set<String>>.broadcast(
        onListen: () => joinedSubscriptions++,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CommunityExplorerScreen(
            isAnonymous: () => true,
            pageLoader: (_) async => const CommunityExplorerPage(
              communities: [_community],
              nextCursor: null,
              hasMore: false,
            ),
            discoveryFilter: (communities) async => communities,
            joinedCommunityIdsStream: joinedController.stream,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_community.name), findsOneWidget);
      expect(joinedSubscriptions, 0);
      await joinedController.close();
    },
  );

  testWidgets('Explorer opens Community only after the account gate succeeds', (
    tester,
  ) async {
    var gateAllowed = false;
    var gateCalls = 0;
    var openCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityExplorerScreen(
          isAnonymous: () => true,
          pageLoader: (_) async => const CommunityExplorerPage(
            communities: [_community],
            nextCursor: null,
            hasMore: false,
          ),
          discoveryFilter: (communities) async => communities,
          linkedAccountGate: (_) async {
            gateCalls++;
            return gateAllowed;
          },
          onCommunityOpen: (_, _) async => openCalls++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(_community.name));
    await tester.pumpAndSettle();
    expect(gateCalls, 1);
    expect(openCalls, 0);

    gateAllowed = true;
    await tester.tap(find.text(_community.name));
    await tester.pumpAndSettle();
    expect(gateCalls, 2);
    expect(openCalls, 1);
  });
}

class _GateAuthLinkGateway implements AuthLinkGateway {
  const _GateAuthLinkGateway({required this.anonymous});

  final bool anonymous;

  @override
  String? get currentUserId => 'gate-user';

  @override
  bool get isCurrentUserAnonymous => anonymous;

  @override
  List<String> get providerIds =>
      anonymous ? const ['anonymous'] : const ['google.com'];

  @override
  Future<AuthLinkState> linkGoogleIdToken(String idToken) async =>
      const AuthLinkState(uid: 'gate-user', providerIds: ['google.com']);

  @override
  Future<AuthLinkState> linkEmailPassword({
    required String email,
    required String password,
  }) async => const AuthLinkState(uid: 'gate-user', providerIds: ['password']);
}

class _GateGoogleCredentialProvider implements GoogleCredentialProvider {
  const _GateGoogleCredentialProvider();

  @override
  Future<GoogleIdentity> authenticate() async =>
      const GoogleIdentity(idToken: 'gate-token', email: 'gate@example.com');
}

class _GateVerificationGateway implements AuthVerificationGateway {
  @override
  String? get currentUserEmail => null;

  @override
  String? get currentUserId => 'gate-user';

  @override
  bool get isCurrentUserAnonymous => true;

  @override
  bool get isCurrentUserEmailVerified => false;

  @override
  List<String> get providerIds => const ['anonymous'];

  @override
  Future<void> deleteCurrentUser() async {}

  @override
  Future<void> reloadCurrentUser() async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> signOut() async {}
}
