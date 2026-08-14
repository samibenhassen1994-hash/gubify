import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/services/auth_service.dart';

void main() {
  test(
    'Google deletion uses fresh identity and Firebase reauthentication',
    () async {
      final google = _GoogleProvider();
      final deletion = _DeletionGateway();
      final service = _service(google: google, deletion: deletion);

      final result = await service.reauthenticateForDeletion();

      expect(result, AccountDeletionReauthStatus.success);
      expect(google.calls, 1);
      expect(deletion.reauthenticateTokens, ['fresh-id-token']);
      expect(service.currentUserId, 'uid');
      expect(deletion.deleteCalls, 0);
    },
  );

  test(
    'a different Google account stops before Firebase reauthentication',
    () async {
      final google = _GoogleProvider(email: 'other@example.com');
      final deletion = _DeletionGateway();
      final service = _service(google: google, deletion: deletion);

      final result = await service.reauthenticateForDeletion();

      expect(result, AccountDeletionReauthStatus.wrongGoogleAccount);
      expect(google.calls, 1);
      expect(deletion.reauthenticateTokens, isEmpty);
      expect(deletion.deleteCalls, 0);
      expect(service.currentUserId, 'uid');
    },
  );

  test(
    'Firebase user-mismatch is a controlled Google account mismatch',
    () async {
      final deletion = _DeletionGateway(
        reauthenticationError: FirebaseAuthException(code: 'user-mismatch'),
      );
      final service = _service(deletion: deletion);

      final result = await service.reauthenticateForDeletion();

      expect(result, AccountDeletionReauthStatus.wrongGoogleAccount);
      expect(deletion.deleteCalls, 0);
      expect(service.currentUserId, 'uid');
    },
  );

  test('Firebase Auth deletion remains a separate final operation', () async {
    final deletion = _DeletionGateway();
    final service = _service(deletion: deletion);

    expect(
      await service.reauthenticateForDeletion(),
      AccountDeletionReauthStatus.success,
    );
    expect(deletion.deleteCalls, 0);
    expect(await service.deleteCurrentAccountAuthUser(), isTrue);
    expect(deletion.events, ['reauthenticate', 'delete-auth']);
  });

  test('failed Auth deletion is reported and can be retried', () async {
    final deletion = _DeletionGateway(
      deleteError: FirebaseAuthException(code: 'requires-recent-login'),
    );
    final service = _service(deletion: deletion);

    expect(
      await service.reauthenticateForDeletion(),
      AccountDeletionReauthStatus.success,
    );
    expect(await service.deleteCurrentAccountAuthUser(), isFalse);
    expect(service.currentUserId, 'uid');
    deletion.deleteError = null;
    expect(await service.deleteCurrentAccountAuthUser(), isTrue);
    expect(deletion.deleteCalls, 2);
  });
}

AuthService _service({_GoogleProvider? google, _DeletionGateway? deletion}) {
  return AuthService(
    authLinkGateway: _LinkGateway(),
    authVerificationGateway: _VerificationGateway(),
    googleCredentialProvider: google ?? _GoogleProvider(),
    accountDeletionAuthGateway: deletion ?? _DeletionGateway(),
    clearUserCache: () {},
  );
}

class _GoogleProvider implements GoogleCredentialProvider {
  _GoogleProvider({this.email = 'person@example.com'});

  final String email;
  int calls = 0;

  @override
  Future<GoogleIdentity> authenticate() async {
    calls++;
    return GoogleIdentity(idToken: 'fresh-id-token', email: email);
  }
}

class _DeletionGateway implements AccountDeletionAuthGateway {
  _DeletionGateway({this.reauthenticationError, this.deleteError});

  final Object? reauthenticationError;
  Object? deleteError;
  final List<String> reauthenticateTokens = [];
  final List<String> events = [];
  int deleteCalls = 0;

  @override
  Future<void> reauthenticateWithGoogleIdToken(String idToken) async {
    reauthenticateTokens.add(idToken);
    events.add('reauthenticate');
    if (reauthenticationError case final error?) throw error;
  }

  @override
  Future<void> reauthenticateWithPassword({
    required String email,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteCurrentUser() async {
    deleteCalls++;
    events.add('delete-auth');
    if (deleteError case final error?) throw error;
  }
}

class _LinkGateway implements AuthLinkGateway {
  @override
  String? get currentUserId => 'uid';

  @override
  bool get isCurrentUserAnonymous => false;

  @override
  List<String> get providerIds => const ['google.com'];

  @override
  Future<AuthLinkState> linkEmailPassword({
    required String email,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<AuthLinkState> linkGoogleIdToken(String idToken) async =>
      throw UnimplementedError();
}

class _VerificationGateway implements AuthVerificationGateway {
  @override
  String? get currentUserEmail => 'person@example.com';

  @override
  String? get currentUserId => 'uid';

  @override
  bool get isCurrentUserAnonymous => false;

  @override
  bool get isCurrentUserEmailVerified => true;

  @override
  List<String> get providerIds => const ['google.com'];

  @override
  Future<void> deleteCurrentUser() async {}

  @override
  Future<void> reloadCurrentUser() async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> signOut() async {}
}
