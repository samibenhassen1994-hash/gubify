import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/profile/models/account_deletion_model.dart';
import 'package:gubify/modules/profile/repositories/account_deletion_repository.dart';
import 'package:gubify/modules/profile/repositories/account_deletion_marker_store.dart';
import 'package:gubify/modules/profile/services/account_deletion_service.dart';
import 'package:gubify/modules/profile/widgets/delete_account_dialog.dart';
import 'package:gubify/services/auth_service.dart';

void main() {
  testWidgets('successful deletion invokes the authenticated-area reset', (
    tester,
  ) async {
    var resets = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DeleteAccountDialog(
          service: _service(_AuthService(), _Repository()),
          requiresPassword: false,
          onDeleted: (_) async => resets++,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
    for (var frame = 0; frame < 20 && resets == 0; frame++) {
      await tester.pump();
    }

    expect(resets, 1);
  });

  testWidgets('Auth deletion failure keeps retry UI and does not reset', (
    tester,
  ) async {
    var resets = 0;
    final auth = _AuthService()..deleteResult = false;
    await tester.pumpWidget(
      MaterialApp(
        home: DeleteAccountDialog(
          service: _service(auth, _Repository()),
          requiresPassword: false,
          onDeleted: (_) async => resets++,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
    await tester.pumpAndSettle();

    expect(resets, 0);
    expect(
      find.text("Account deletion couldn't be completed. Please retry."),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Delete account'), findsOneWidget);
  });

  test(
    'ownership preflight blocks before reauthentication or cleanup',
    () async {
      final repository = _Repository()
        ..preflightValue = const AccountDeletionPreflight(
          privateGubs: [OwnedAccountResource(id: 'g1', name: 'Family')],
        );
      final auth = _AuthService();
      final service = _service(auth, repository);

      final result = await service.deleteAccount();

      expect(result.status, AccountDeletionStatus.ownershipBlocked);
      expect(auth.reauthenticateCalls, 0);
      expect(repository.events, ['preflight']);
    },
  );

  test('community ownership is also blocked authoritatively', () async {
    final repository = _Repository()
      ..preflightValue = const AccountDeletionPreflight(
        communities: [OwnedAccountResource(id: 'c1', name: 'Football')],
      );
    final result = await _service(_AuthService(), repository).deleteAccount();
    expect(result.status, AccountDeletionStatus.ownershipBlocked);
  });

  test('wrong password stops before destructive cleanup', () async {
    final repository = _Repository();
    final auth = _AuthService()
      ..reauthentication = AccountDeletionReauthStatus.wrongPassword;
    final result = await _service(
      auth,
      repository,
    ).deleteAccount(password: 'wrong');
    expect(result.status, AccountDeletionStatus.wrongPassword);
    expect(repository.profileDeleted, isFalse);
    expect(auth.deleteCalls, 0);
  });

  test('wrong Google account stops before destructive cleanup', () async {
    final repository = _Repository();
    final auth = _AuthService()
      ..reauthentication = AccountDeletionReauthStatus.wrongGoogleAccount;

    final result = await _service(auth, repository).deleteAccount();

    expect(result.status, AccountDeletionStatus.wrongGoogleAccount);
    expect(repository.profileDeleted, isFalse);
    expect(auth.deleteCalls, 0);
  });

  test('membership cleanup completes before Auth deletion', () async {
    final repository = _Repository()
      ..privateIds = ['g1']
      ..communityIds = ['c1'];
    final auth = _AuthService();
    final events = repository.events;
    final service = AccountDeletionService(
      authService: auth,
      repository: repository,
      markerStore: _MarkerStore(events),
      leavePrivateGub: (id) async => events.add('leave-gub:$id'),
      leaveCommunity: (id) async => events.add('leave-community:$id'),
      clearUserCache: () => events.add('clear-cache'),
      clearLocalProfileState: () async => events.add('clear-local-profile'),
    );
    auth.onDelete = () => events.add('delete-auth');

    final result = await service.deleteAccount();

    expect(result.isSuccess, isTrue);
    expect(events, [
      'preflight',
      'marker-write:uid',
      'membership-index',
      'anonymize-shared',
      'private-reads:g1',
      'leave-gub:g1',
      'community-request:c1',
      'leave-community:c1',
      'delete-profile',
      'clear-cache',
      'clear-local-profile',
      'delete-auth',
      'marker-clear',
    ]);
  });

  test('cleanup failure never deletes Firebase Auth user', () async {
    final repository = _Repository()
      ..privateIds = ['g1']
      ..failReadCleanup = true;
    final auth = _AuthService();

    final result = await _service(auth, repository).deleteAccount();

    expect(result.status, AccountDeletionStatus.cleanupFailed);
    expect(auth.deleteCalls, 0);
  });

  test('membership discovery failure stops before Auth deletion', () async {
    final repository = _Repository()..failMembershipDiscovery = true;
    final auth = _AuthService();

    final result = await _service(auth, repository).deleteAccount();

    expect(result.status, AccountDeletionStatus.cleanupFailed);
    expect(repository.profileDeleted, isFalse);
    expect(auth.deleteCalls, 0);
  });

  test('missing membership is harmless and stale copy is removed', () async {
    final repository = _Repository()..privateIds = ['gone'];
    final auth = _AuthService();
    final service = AccountDeletionService(
      authService: auth,
      repository: repository,
      markerStore: _MarkerStore(repository.events),
      leavePrivateGub: (_) async => throw StateError('missing'),
      leaveCommunity: (_) async {},
      clearUserCache: () {},
      clearLocalProfileState: () async {},
    );

    expect((await service.deleteAccount()).isSuccess, isTrue);
    expect(repository.events, contains('private-copy:gone'));
  });

  test(
    'Auth deletion failure can be retried without duplicate effects',
    () async {
      final repository = _Repository();
      final auth = _AuthService()..deleteResult = false;
      final marker = _MarkerStore(repository.events);
      final service = AccountDeletionService(
        authService: auth,
        repository: repository,
        markerStore: marker,
        leavePrivateGub: (_) async {},
        leaveCommunity: (_) async {},
        clearUserCache: () {},
        clearLocalProfileState: () async {},
      );

      expect(
        (await service.deleteAccount()).status,
        AccountDeletionStatus.authDeletionFailed,
      );
      expect(marker.value, 'uid');
      auth.deleteResult = true;
      expect((await service.deleteAccount()).isSuccess, isTrue);
      expect(auth.deleteCalls, 2);
      expect(marker.value, isNull);
    },
  );

  test(
    'pure anonymous member can delete without provider reauthentication',
    () async {
      final repository = _Repository();
      final auth = _AuthService()..anonymous = true;
      final marker = _MarkerStore(repository.events);
      final service = AccountDeletionService(
        authService: auth,
        repository: repository,
        markerStore: marker,
        leavePrivateGub: (_) async {},
        leaveCommunity: (_) async {},
        clearUserCache: () {},
        clearLocalProfileState: () async {},
      );

      expect((await service.deleteAccount()).isSuccess, isTrue);
      expect(repository.profileDeleted, isTrue);
      expect(auth.reauthenticateCalls, 0);
      expect(auth.deleteCalls, 1);
      expect(marker.value, isNull);
      expect(
        repository.events,
        containsAllInOrder([
          'preflight',
          'marker-write:uid',
          'membership-index',
          'anonymize-shared',
          'delete-profile',
          'marker-clear',
        ]),
      );
    },
  );

  test('pure anonymous owner remains blocked before cleanup', () async {
    final repository = _Repository()
      ..preflightValue = const AccountDeletionPreflight(
        privateGubs: [OwnedAccountResource(id: 'g1', name: 'Family')],
      );
    final auth = _AuthService()..anonymous = true;
    final marker = _MarkerStore(repository.events);

    final result = await AccountDeletionService(
      authService: auth,
      repository: repository,
      markerStore: marker,
      leavePrivateGub: (_) async {},
      leaveCommunity: (_) async {},
      clearUserCache: () {},
      clearLocalProfileState: () async {},
    ).deleteAccount();

    expect(result.status, AccountDeletionStatus.ownershipBlocked);
    expect(repository.events, ['preflight']);
    expect(repository.profileDeleted, isFalse);
    expect(auth.reauthenticateCalls, 0);
    expect(auth.deleteCalls, 0);
    expect(marker.value, isNull);
  });

  test('Google-linked account can still delete', () async {
    final repository = _Repository();
    final auth = _AuthService(providerIds: const ['google.com'])
      ..anonymous = true;

    expect(
      (await _service(auth, repository).deleteAccount()).isSuccess,
      isTrue,
    );
    expect(auth.deleteCalls, 1);
  });

  test('email-linked account can still delete', () async {
    final repository = _Repository();
    final auth = _AuthService(providerIds: const ['password'])
      ..anonymous = true;

    expect(
      (await _service(auth, repository).deleteAccount()).isSuccess,
      isTrue,
    );
    expect(auth.deleteCalls, 1);
  });

  test('deleting user A never targets surviving user B', () async {
    final repository = _Repository()
      ..privateIds = ['g1']
      ..profiles.addAll({
        'userA': {'displayName': 'Deleting user'},
        'userB': {'displayName': 'Surviving user', 'stable': true},
      });
    final survivingProfileBefore = Map<String, Object?>.from(
      repository.profiles['userB']!,
    );
    final auth = _AuthService(userId: 'userA');
    final service = AccountDeletionService(
      authService: auth,
      repository: repository,
      markerStore: _MarkerStore(repository.events),
      leavePrivateGub: (gubId) async =>
          repository.events.add('leave-gub:$gubId:userA'),
      leaveCommunity: (_) async {},
      clearUserCache: () {},
      clearLocalProfileState: () async {},
    );

    expect((await service.deleteAccount()).isSuccess, isTrue);
    expect(repository.anonymizedUserIds, ['userA']);
    expect(repository.deletedProfileUserIds, ['userA']);
    expect(repository.profiles.containsKey('userA'), isFalse);
    expect(repository.profiles['userB'], survivingProfileBefore);
    expect(
      repository.events,
      containsAllInOrder(['private-reads:g1:userA', 'leave-gub:g1:userA']),
    );
  });
}

AccountDeletionService _service(_AuthService auth, _Repository repository) {
  return AccountDeletionService(
    authService: auth,
    repository: repository,
    markerStore: _MarkerStore(repository.events),
    leavePrivateGub: (_) async {},
    leaveCommunity: (_) async {},
    clearUserCache: () {},
    clearLocalProfileState: () async {},
  );
}

class _MarkerStore implements AccountDeletionMarkerStore {
  _MarkerStore(this.events);
  final List<String> events;
  String? value;

  @override
  Future<void> clear() async {
    value = null;
    events.add('marker-clear');
  }

  @override
  Future<String?> readUserId() async => value;

  @override
  Future<void> writeUserId(String userId) async {
    value = userId;
    events.add('marker-write:$userId');
  }
}

class _AuthService extends AuthService {
  _AuthService({this.userId = 'uid', List<String> providerIds = const []})
    : super(
        authLinkGateway: _LinkGateway(providerIds),
        authVerificationGateway: const _VerificationGateway(),
      );

  bool anonymous = false;
  AccountDeletionReauthStatus reauthentication =
      AccountDeletionReauthStatus.success;
  bool deleteResult = true;
  int reauthenticateCalls = 0;
  int deleteCalls = 0;
  final List<String?> passwords = [];
  void Function()? onDelete;
  final String userId;

  @override
  String? get currentUserId => userId;

  @override
  bool get isCurrentUserAnonymous => anonymous;

  @override
  Future<AccountDeletionReauthStatus> reauthenticateForDeletion({
    String? password,
  }) async {
    if (anonymous) return AccountDeletionReauthStatus.success;
    reauthenticateCalls++;
    passwords.add(password);
    return reauthentication;
  }

  @override
  Future<bool> deleteCurrentAccountAuthUser() async {
    deleteCalls++;
    onDelete?.call();
    return deleteResult;
  }
}

class _Repository implements AccountDeletionRepositoryContract {
  AccountDeletionPreflight preflightValue = const AccountDeletionPreflight();
  List<String> privateIds = [];
  List<String> communityIds = [];
  bool failReadCleanup = false;
  bool failMembershipDiscovery = false;
  bool profileDeleted = false;
  final List<String> events = [];
  final Map<String, Map<String, Object?>> profiles = {};
  final List<String> anonymizedUserIds = [];
  final List<String> deletedProfileUserIds = [];

  @override
  Future<void> anonymizeSharedContent({
    required String userId,
    required List<String> privateGubIds,
    required List<String> communityIds,
  }) async {
    anonymizedUserIds.add(userId);
    events.add('anonymize-shared');
  }

  @override
  Future<AccountDeletionPreflight> loadPreflight(String userId) async {
    events.add('preflight');
    return preflightValue;
  }

  @override
  Future<AccountDeletionMemberships> loadMemberships(String userId) async {
    events.add('membership-index');
    if (failMembershipDiscovery) throw StateError('discovery failed');
    return AccountDeletionMemberships(
      privateGubIds: privateIds,
      communityIds: communityIds,
    );
  }

  @override
  Future<void> deletePrivateReadState(String gubId, String userId) async {
    events.add('private-reads:$gubId${userId == 'uid' ? '' : ':$userId'}');
    if (failReadCleanup) throw StateError('failed');
  }

  @override
  Future<void> deleteCommunityJoinRequest(
    String communityId,
    String userId,
  ) async => events.add('community-request:$communityId');

  @override
  Future<void> deletePrivateCopy(String gubId, String userId) async =>
      events.add('private-copy:$gubId');

  @override
  Future<void> deleteCommunityCopy(String communityId, String userId) async =>
      events.add('community-copy:$communityId');

  @override
  Future<void> deleteProfile(String userId) async {
    profileDeleted = true;
    deletedProfileUserIds.add(userId);
    profiles.remove(userId);
    events.add('delete-profile');
  }
}

class _LinkGateway implements AuthLinkGateway {
  const _LinkGateway(this.providerIds);
  @override
  String? get currentUserId => 'uid';
  @override
  bool get isCurrentUserAnonymous => false;
  @override
  final List<String> providerIds;
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
  const _VerificationGateway();
  @override
  String? get currentUserEmail => null;
  @override
  String? get currentUserId => 'uid';
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
