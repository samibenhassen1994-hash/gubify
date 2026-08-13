import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/services/auth_service.dart';

void main() {
  const identity = GoogleIdentity(
    idToken: 'google-id-token',
    email: 'person@example.com',
    displayName: 'Google Person',
    photoUrl: 'https://example.com/photo.png',
  );

  AuthService serviceFor({
    required _FakeAuthLinkGateway auth,
    required GoogleCredentialProvider google,
  }) {
    return AuthService(authLinkGateway: auth, googleCredentialProvider: google);
  }

  test('returns a controlled result when there is no current user', () async {
    final auth = _FakeAuthLinkGateway(currentUserId: null);
    final google = _FakeGoogleCredentialProvider(identity: identity);

    final result = await serviceFor(
      auth: auth,
      google: google,
    ).linkCurrentAnonymousUserWithGoogle();

    expect(result.status, GoogleLinkStatus.noCurrentUser);
    expect(google.calls, 0);
    expect(auth.linkCalls, 0);
  });

  test('links Google while preserving the Firebase UID', () async {
    final auth = _FakeAuthLinkGateway(
      currentUserId: 'existing-uid',
      linkedUid: 'existing-uid',
      linkedProviderIds: const ['anonymous', 'google.com'],
    );

    final result = await serviceFor(
      auth: auth,
      google: _FakeGoogleCredentialProvider(identity: identity),
    ).linkCurrentAnonymousUserWithGoogle();

    expect(result.isSuccess, isTrue);
    expect(result.uid, 'existing-uid');
    expect(result.email, identity.email);
    expect(result.providerIds, contains('google.com'));
    expect(auth.linkCalls, 1);
    expect(auth.lastIdToken, identity.idToken);
  });

  test('does not link or modify the user when Google is cancelled', () async {
    final auth = _FakeAuthLinkGateway(currentUserId: 'existing-uid');
    final google = _FakeGoogleCredentialProvider(
      error: const GoogleCredentialException(GoogleCredentialFailure.cancelled),
    );

    final result = await serviceFor(
      auth: auth,
      google: google,
    ).linkCurrentAnonymousUserWithGoogle();

    expect(result.status, GoogleLinkStatus.cancelled);
    expect(auth.linkCalls, 0);
    expect(auth.currentUserId, 'existing-uid');
  });

  test('does not start Google when the provider is already linked', () async {
    final auth = _FakeAuthLinkGateway(
      currentUserId: 'existing-uid',
      providerIds: const ['google.com'],
    );
    final google = _FakeGoogleCredentialProvider(identity: identity);

    final result = await serviceFor(
      auth: auth,
      google: google,
    ).linkCurrentAnonymousUserWithGoogle();

    expect(result.status, GoogleLinkStatus.providerAlreadyLinked);
    expect(google.calls, 0);
    expect(auth.linkCalls, 0);
  });

  test(
    'keeps the existing user when the credential is already in use',
    () async {
      final auth = _FakeAuthLinkGateway(
        currentUserId: 'existing-uid',
        linkError: FirebaseAuthException(code: 'credential-already-in-use'),
      );

      final result = await serviceFor(
        auth: auth,
        google: _FakeGoogleCredentialProvider(identity: identity),
      ).linkCurrentAnonymousUserWithGoogle();

      expect(result.status, GoogleLinkStatus.credentialAlreadyInUse);
      expect(auth.currentUserId, 'existing-uid');
      expect(auth.linkCalls, 1);
    },
  );

  test('returns an invalid credential result without linking', () async {
    final auth = _FakeAuthLinkGateway(currentUserId: 'existing-uid');

    final result = await serviceFor(
      auth: auth,
      google: _FakeGoogleCredentialProvider(
        error: const GoogleCredentialException(
          GoogleCredentialFailure.invalidCredential,
        ),
      ),
    ).linkCurrentAnonymousUserWithGoogle();

    expect(result.status, GoogleLinkStatus.invalidCredential);
    expect(auth.linkCalls, 0);
  });

  test('maps Firebase linking failures to controlled result states', () async {
    final expectedStatuses = <String, GoogleLinkStatus>{
      'account-exists-with-different-credential':
          GoogleLinkStatus.accountExistsWithDifferentCredential,
      'network-request-failed': GoogleLinkStatus.networkRequestFailed,
      'operation-not-allowed': GoogleLinkStatus.operationNotAllowed,
      'too-many-requests': GoogleLinkStatus.tooManyRequests,
    };

    for (final entry in expectedStatuses.entries) {
      final auth = _FakeAuthLinkGateway(
        currentUserId: 'existing-uid',
        linkError: FirebaseAuthException(code: entry.key),
      );

      final result = await serviceFor(
        auth: auth,
        google: _FakeGoogleCredentialProvider(identity: identity),
      ).linkCurrentAnonymousUserWithGoogle();

      expect(result.status, entry.value, reason: entry.key);
      expect(auth.currentUserId, 'existing-uid', reason: entry.key);
    }
  });

  test('returns a controlled failure if linking changes the UID', () async {
    final auth = _FakeAuthLinkGateway(
      currentUserId: 'existing-uid',
      linkedUid: 'unexpected-uid',
    );

    final result = await serviceFor(
      auth: auth,
      google: _FakeGoogleCredentialProvider(identity: identity),
    ).linkCurrentAnonymousUserWithGoogle();

    expect(result.status, GoogleLinkStatus.uidChanged);
  });

  test(
    'initializes Google Sign-In once across repeated authentication',
    () async {
      final client = _FakeGoogleSignInClient(identity: identity);
      final provider = GoogleSignInCredentialProvider(client: client);

      await provider.authenticate();
      await provider.authenticate();

      expect(client.initializeCalls, 1);
      expect(client.authenticateCalls, 2);
    },
  );

  test('links email and password while preserving the Firebase UID', () async {
    final auth = _FakeAuthLinkGateway(
      currentUserId: 'existing-uid',
      linkedProviderIds: const ['password'],
    );

    final result =
        await serviceFor(
          auth: auth,
          google: _FakeGoogleCredentialProvider(identity: identity),
        ).linkCurrentUserWithEmailAndPassword(
          email: 'person@example.com',
          password: 'secure-password',
        );

    expect(result.isSuccess, isTrue);
    expect(result.uid, 'existing-uid');
    expect(result.email, 'person@example.com');
    expect(auth.emailLinkCalls, 1);
  });

  test(
    'returns a controlled result when email binding has no current user',
    () async {
      final auth = _FakeAuthLinkGateway(currentUserId: null);

      final result =
          await serviceFor(
            auth: auth,
            google: _FakeGoogleCredentialProvider(identity: identity),
          ).linkCurrentUserWithEmailAndPassword(
            email: 'person@example.com',
            password: 'secure-password',
          );

      expect(result.status, EmailPasswordLinkStatus.noCurrentUser);
      expect(auth.emailLinkCalls, 0);
    },
  );

  test('maps email binding failures without changing the UID', () async {
    final expectedStatuses = <String, EmailPasswordLinkStatus>{
      'invalid-email': EmailPasswordLinkStatus.invalidEmail,
      'weak-password': EmailPasswordLinkStatus.weakPassword,
      'email-already-in-use': EmailPasswordLinkStatus.emailAlreadyInUse,
      'credential-already-in-use':
          EmailPasswordLinkStatus.credentialAlreadyInUse,
    };

    for (final entry in expectedStatuses.entries) {
      final auth = _FakeAuthLinkGateway(
        currentUserId: 'existing-uid',
        emailLinkError: FirebaseAuthException(code: entry.key),
      );
      final result =
          await serviceFor(
            auth: auth,
            google: _FakeGoogleCredentialProvider(identity: identity),
          ).linkCurrentUserWithEmailAndPassword(
            email: 'person@example.com',
            password: 'secure-password',
          );

      expect(result.status, entry.value, reason: entry.key);
      expect(auth.currentUserId, 'existing-uid', reason: entry.key);
    }
  });

  test('does not bind email credentials for a non-anonymous user', () async {
    final auth = _FakeAuthLinkGateway(
      currentUserId: 'existing-uid',
      anonymous: false,
    );

    final result =
        await serviceFor(
          auth: auth,
          google: _FakeGoogleCredentialProvider(identity: identity),
        ).linkCurrentUserWithEmailAndPassword(
          email: 'person@example.com',
          password: 'secure-password',
        );

    expect(result.status, EmailPasswordLinkStatus.userNotAnonymous);
    expect(auth.emailLinkCalls, 0);
  });
}

class _FakeAuthLinkGateway implements AuthLinkGateway {
  _FakeAuthLinkGateway({
    required this.currentUserId,
    this.providerIds = const <String>['anonymous'],
    String? linkedUid,
    List<String>? linkedProviderIds,
    this.linkError,
    this.emailLinkError,
    this.anonymous = true,
  }) {
    _linkedUid = linkedUid;
    _linkedProviderIds = linkedProviderIds;
  }

  @override
  String? currentUserId;

  @override
  bool get isCurrentUserAnonymous => anonymous;

  @override
  final List<String> providerIds;

  late final String? _linkedUid;
  late final List<String>? _linkedProviderIds;
  final FirebaseAuthException? linkError;
  final FirebaseAuthException? emailLinkError;
  final bool anonymous;
  int linkCalls = 0;
  int emailLinkCalls = 0;
  String? lastIdToken;

  @override
  Future<AuthLinkState> linkGoogleIdToken(String idToken) async {
    linkCalls += 1;
    lastIdToken = idToken;
    final error = linkError;
    if (error != null) throw error;
    return AuthLinkState(
      uid: _linkedUid ?? currentUserId,
      providerIds: _linkedProviderIds ?? providerIds,
    );
  }

  @override
  Future<AuthLinkState> linkEmailPassword({
    required String email,
    required String password,
  }) async {
    emailLinkCalls += 1;
    final error = emailLinkError;
    if (error != null) throw error;
    return AuthLinkState(
      uid: _linkedUid ?? currentUserId,
      providerIds: _linkedProviderIds ?? const ['password'],
    );
  }
}

class _FakeGoogleCredentialProvider implements GoogleCredentialProvider {
  _FakeGoogleCredentialProvider({this.identity, this.error});

  final GoogleIdentity? identity;
  final Object? error;
  int calls = 0;

  @override
  Future<GoogleIdentity> authenticate() async {
    calls += 1;
    final failure = error;
    if (failure != null) throw failure;
    return identity!;
  }
}

class _FakeGoogleSignInClient implements GoogleSignInClient {
  _FakeGoogleSignInClient({required this.identity});

  final GoogleIdentity identity;
  int initializeCalls = 0;
  int authenticateCalls = 0;

  @override
  Future<void> initialize() async {
    initializeCalls += 1;
  }

  @override
  bool supportsAuthenticate() => true;

  @override
  Future<GoogleIdentity> authenticate() async {
    authenticateCalls += 1;
    return identity;
  }
}
