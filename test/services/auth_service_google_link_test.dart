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
    AuthAccountGateway? account,
    AuthVerificationGateway? verification,
    PasswordResetGateway? passwordReset,
    GoogleSignOutGateway? googleSignOut,
    void Function()? clearUserCache,
    Future<bool> Function(String userId)? userProfileExists,
  }) {
    return AuthService(
      authLinkGateway: auth,
      authAccountGateway: account,
      authVerificationGateway: verification,
      passwordResetGateway: passwordReset,
      googleSignOutGateway: googleSignOut,
      clearUserCache: clearUserCache,
      googleCredentialProvider: google,
      userProfileExists: userProfileExists,
    );
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

  test(
    'signs in with Google without using the account-linking gateway',
    () async {
      final auth = _FakeAuthLinkGateway(currentUserId: null);
      final account = _FakeAuthAccountGateway(googleUid: 'google-user');

      final result = await serviceFor(
        auth: auth,
        google: _FakeGoogleCredentialProvider(identity: identity),
        account: account,
      ).signInWithGoogle();

      expect(result, isA<AccountAuthResult>());
      expect(result.isSuccess, isTrue);
      expect(result.uid, 'google-user');
      expect(account.googleSignInCalls, 1);
      expect(auth.linkCalls, 0);
    },
  );

  test(
    'keeps the session unchanged when Google sign-in is cancelled',
    () async {
      final account = _FakeAuthAccountGateway();
      final result = await serviceFor(
        auth: _FakeAuthLinkGateway(currentUserId: null),
        google: _FakeGoogleCredentialProvider(
          error: const GoogleCredentialException(
            GoogleCredentialFailure.cancelled,
          ),
        ),
        account: account,
      ).signInWithGoogle();

      expect(result.status, AccountAuthStatus.cancelled);
      expect(account.googleSignInCalls, 0);
    },
  );

  test('maps email sign-in failures to controlled result states', () async {
    final expectedStatuses = <String, AccountAuthStatus>{
      'wrong-password': AccountAuthStatus.invalidCredential,
      'user-disabled': AccountAuthStatus.userDisabled,
      'network-request-failed': AccountAuthStatus.networkRequestFailed,
    };

    for (final entry in expectedStatuses.entries) {
      final result =
          await serviceFor(
            auth: _FakeAuthLinkGateway(currentUserId: null),
            google: _FakeGoogleCredentialProvider(identity: identity),
            account: _FakeAuthAccountGateway(
              emailSignInError: FirebaseAuthException(code: entry.key),
            ),
          ).signInWithEmailAndPassword(
            email: 'person@example.com',
            password: 'wrong-password',
          );

      expect(result.status, entry.value, reason: entry.key);
    }
  });

  test(
    'registers a new email account without using credential linking',
    () async {
      final auth = _FakeAuthLinkGateway(currentUserId: null);
      final account = _FakeAuthAccountGateway(registrationUid: 'new-user');
      final result =
          await serviceFor(
            auth: auth,
            google: _FakeGoogleCredentialProvider(identity: identity),
            account: account,
          ).registerWithEmailAndPassword(
            email: 'new@example.com',
            password: 'secure-password',
          );

      expect(result.isSuccess, isTrue);
      expect(result.uid, 'new-user');
      expect(account.registrationCalls, 1);
      expect(auth.emailLinkCalls, 0);
    },
  );

  test('new email registration sends a verification email', () async {
    final account = _FakeAuthAccountGateway(registrationUid: 'new-user');
    final verification = _FakeAuthVerificationGateway();
    final result =
        await serviceFor(
          auth: _FakeAuthLinkGateway(currentUserId: null),
          google: _FakeGoogleCredentialProvider(identity: identity),
          account: account,
          verification: verification,
        ).registerWithEmailAndPassword(
          email: 'new@example.com',
          password: 'secure-password',
        );

    expect(result.isSuccess, isTrue);
    expect(result.uid, 'new-user');
    expect(account.registrationCalls, 1);
    expect(verification.sendCalls, 1);
  });

  test(
    'maps weak registration passwords without changing an existing user',
    () async {
      final expectedStatuses = <String, AccountAuthStatus>{
        'weak-password': AccountAuthStatus.weakPassword,
        'email-already-in-use': AccountAuthStatus.emailAlreadyInUse,
        'invalid-email': AccountAuthStatus.invalidEmail,
      };

      for (final entry in expectedStatuses.entries) {
        final result =
            await serviceFor(
              auth: _FakeAuthLinkGateway(currentUserId: null),
              google: _FakeGoogleCredentialProvider(identity: identity),
              account: _FakeAuthAccountGateway(
                registrationError: FirebaseAuthException(code: entry.key),
              ),
            ).registerWithEmailAndPassword(
              email: 'new@example.com',
              password: 'short',
            );

        expect(result.status, entry.value, reason: entry.key);
      }
    },
  );

  test('requires verification only for unverified password accounts', () {
    AuthService serviceForVerification(_FakeAuthVerificationGateway gateway) {
      return serviceFor(
        auth: _FakeAuthLinkGateway(currentUserId: gateway.currentUserId),
        google: _FakeGoogleCredentialProvider(identity: identity),
        verification: gateway,
      );
    }

    expect(
      serviceForVerification(
        _FakeAuthVerificationGateway(providerIds: const ['password']),
      ).requiresCurrentUserEmailVerification,
      isTrue,
    );
    expect(
      serviceForVerification(
        _FakeAuthVerificationGateway(
          providerIds: const ['password'],
          emailVerified: true,
        ),
      ).requiresCurrentUserEmailVerification,
      isFalse,
    );
    expect(
      serviceForVerification(
        _FakeAuthVerificationGateway(anonymous: true),
      ).requiresCurrentUserEmailVerification,
      isFalse,
    );
    expect(
      serviceForVerification(
        _FakeAuthVerificationGateway(providerIds: const ['google.com']),
      ).requiresCurrentUserEmailVerification,
      isFalse,
    );
    expect(
      serviceForVerification(
        _FakeAuthVerificationGateway(
          providerIds: const ['password', 'google.com'],
        ),
      ).requiresCurrentUserEmailVerification,
      isFalse,
    );
  });

  test(
    'sends and reloads email verification through the auth gateway',
    () async {
      final verification = _FakeAuthVerificationGateway(
        providerIds: const ['password'],
        becomesVerifiedOnReload: true,
      );
      final service = serviceFor(
        auth: _FakeAuthLinkGateway(currentUserId: 'existing-uid'),
        google: _FakeGoogleCredentialProvider(identity: identity),
        verification: verification,
      );

      final sent = await service.sendCurrentUserEmailVerification();
      final reloaded = await service.reloadCurrentUser();

      expect(sent.isSuccess, isTrue);
      expect(verification.sendCalls, 1);
      expect(reloaded.isVerified, isTrue);
      expect(verification.reloadCalls, 1);
    },
  );

  test('maps verification send failures to controlled result states', () async {
    final service = serviceFor(
      auth: _FakeAuthLinkGateway(currentUserId: 'existing-uid'),
      google: _FakeGoogleCredentialProvider(identity: identity),
      verification: _FakeAuthVerificationGateway(
        sendError: FirebaseAuthException(code: 'network-request-failed'),
      ),
    );

    final result = await service.sendCurrentUserEmailVerification();

    expect(result.status, EmailVerificationStatus.networkRequestFailed);
  });

  test('email binding preserves UID and sends a verification email', () async {
    final verification = _FakeAuthVerificationGateway();
    final result =
        await serviceFor(
          auth: _FakeAuthLinkGateway(
            currentUserId: 'existing-uid',
            linkedUid: 'existing-uid',
          ),
          google: _FakeGoogleCredentialProvider(identity: identity),
          verification: verification,
        ).linkCurrentUserWithEmailAndPassword(
          email: 'person@example.com',
          password: 'secure-password',
        );

    expect(result.isSuccess, isTrue);
    expect(result.uid, 'existing-uid');
    expect(result.verificationStatus, EmailVerificationStatus.success);
    expect(verification.sendCalls, 1);
  });

  group('incomplete profile onboarding exit', () {
    test('deletes a new anonymous user without a Firestore profile', () async {
      final verification = _FakeAuthVerificationGateway(anonymous: true);
      final result = await serviceFor(
        auth: _FakeAuthLinkGateway(currentUserId: 'anonymous-uid'),
        google: _FakeGoogleCredentialProvider(identity: identity),
        verification: verification,
        userProfileExists: (_) async => false,
      ).exitIncompleteProfileOnboarding();

      expect(result.isSuccess, isTrue);
      expect(result.action, IncompleteProfileExitAction.anonymousUserDeleted);
      expect(verification.deleteCalls, 1);
      expect(verification.signOutCalls, 0);
    });

    test('signs out an anonymous user when deletion fails', () async {
      final verification = _FakeAuthVerificationGateway(
        anonymous: true,
        deleteError: FirebaseAuthException(code: 'requires-recent-login'),
      );
      final result = await serviceFor(
        auth: _FakeAuthLinkGateway(currentUserId: 'anonymous-uid'),
        google: _FakeGoogleCredentialProvider(identity: identity),
        verification: verification,
        userProfileExists: (_) async => false,
      ).exitIncompleteProfileOnboarding();

      expect(result.isSuccess, isTrue);
      expect(result.action, IncompleteProfileExitAction.anonymousUserSignedOut);
      expect(verification.deleteCalls, 1);
      expect(verification.signOutCalls, 1);
    });

    test('signs out email and Google accounts without deleting them', () async {
      for (final providers in const <List<String>>[
        <String>['password'],
        <String>['google.com'],
      ]) {
        final verification = _FakeAuthVerificationGateway(
          providerIds: providers,
        );
        final result = await serviceFor(
          auth: _FakeAuthLinkGateway(currentUserId: 'account-uid'),
          google: _FakeGoogleCredentialProvider(identity: identity),
          verification: verification,
          userProfileExists: (_) async => false,
        ).exitIncompleteProfileOnboarding();

        expect(result.isSuccess, isTrue, reason: providers.single);
        expect(
          result.action,
          IncompleteProfileExitAction.accountSignedOut,
          reason: providers.single,
        );
        expect(verification.deleteCalls, 0, reason: providers.single);
        expect(verification.signOutCalls, 1, reason: providers.single);
      }
    });

    test('does nothing when the profile lookup cannot be completed', () async {
      final verification = _FakeAuthVerificationGateway(anonymous: true);
      final result = await serviceFor(
        auth: _FakeAuthLinkGateway(currentUserId: 'profile-owner'),
        google: _FakeGoogleCredentialProvider(identity: identity),
        verification: verification,
        userProfileExists: (_) async => throw StateError('lookup failed'),
      ).exitIncompleteProfileOnboarding();

      expect(result.status, IncompleteProfileExitStatus.unknownFailure);
      expect(verification.deleteCalls, 0);
      expect(verification.signOutCalls, 0);
    });

    test('refuses cleanup when the Firestore profile already exists', () async {
      final verification = _FakeAuthVerificationGateway(anonymous: true);
      final result = await serviceFor(
        auth: _FakeAuthLinkGateway(currentUserId: 'existing-uid'),
        google: _FakeGoogleCredentialProvider(identity: identity),
        verification: verification,
        userProfileExists: (_) async => true,
      ).exitIncompleteProfileOnboarding();

      expect(result.status, IncompleteProfileExitStatus.profileAlreadyExists);
      expect(verification.deleteCalls, 0);
      expect(verification.signOutCalls, 0);
    });

    test('sends a password reset without changing authentication state', () async {
      final reset = _FakePasswordResetGateway();
      final result = await serviceFor(
        auth: _FakeAuthLinkGateway(currentUserId: 'existing-uid'),
        google: _FakeGoogleCredentialProvider(identity: identity),
        passwordReset: reset,
      ).sendPasswordResetEmail(email: '  person@example.com  ');

      expect(result.isSuccess, isTrue);
      expect(reset.emails, ['person@example.com']);
    });

    test('maps controlled password reset failures', () async {
      final reset = _FakePasswordResetGateway(
        error: FirebaseAuthException(code: 'too-many-requests'),
      );
      final result = await serviceFor(
        auth: _FakeAuthLinkGateway(currentUserId: 'existing-uid'),
        google: _FakeGoogleCredentialProvider(identity: identity),
        passwordReset: reset,
      ).sendPasswordResetEmail(email: 'person@example.com');

      expect(result.status, PasswordResetStatus.tooManyRequests);
    });

    test('does not disclose a missing password reset account', () async {
      final reset = _FakePasswordResetGateway(
        error: FirebaseAuthException(code: 'user-not-found'),
      );
      final result = await serviceFor(
        auth: _FakeAuthLinkGateway(currentUserId: 'existing-uid'),
        google: _FakeGoogleCredentialProvider(identity: identity),
        passwordReset: reset,
      ).sendPasswordResetEmail(email: 'person@example.com');

      expect(result.isSuccess, isTrue);
    });

    test('does not log a pure anonymous user out', () async {
      final verification = _FakeAuthVerificationGateway();
      final result = await serviceFor(
        auth: _FakeAuthLinkGateway(currentUserId: 'anonymous-uid'),
        google: _FakeGoogleCredentialProvider(identity: identity),
        verification: verification,
      ).logOut();

      expect(result.status, LogoutStatus.anonymousUser);
      expect(verification.signOutCalls, 0);
    });

    test('logs out a Google account and clears cached profile data', () async {
      final verification = _FakeAuthVerificationGateway();
      final googleSignOut = _FakeGoogleSignOutGateway();
      var cacheClearCalls = 0;
      final result = await serviceFor(
        auth: _FakeAuthLinkGateway(
          currentUserId: 'google-uid',
          anonymous: false,
          providerIds: const ['google.com'],
        ),
        google: _FakeGoogleCredentialProvider(identity: identity),
        verification: verification,
        googleSignOut: googleSignOut,
        clearUserCache: () => cacheClearCalls += 1,
      ).logOut();

      expect(result.isSuccess, isTrue);
      expect(googleSignOut.calls, 1);
      expect(verification.signOutCalls, 1);
      expect(cacheClearCalls, 1);
    });
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

class _FakePasswordResetGateway implements PasswordResetGateway {
  _FakePasswordResetGateway({this.error});

  final FirebaseAuthException? error;
  final List<String> emails = [];

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    emails.add(email);
    final failure = error;
    if (failure != null) throw failure;
  }
}

class _FakeGoogleSignOutGateway implements GoogleSignOutGateway {
  int calls = 0;

  @override
  Future<void> signOut() async {
    calls += 1;
  }
}

class _FakeAuthVerificationGateway implements AuthVerificationGateway {
  _FakeAuthVerificationGateway({
    this.anonymous = false,
    this.emailVerified = false,
    this.providerIds = const ['password'],
    this.becomesVerifiedOnReload = false,
    this.sendError,
    this.deleteError,
  });

  @override
  String? currentUserId = 'existing-uid';

  @override
  String? currentUserEmail = 'person@example.com';

  final bool anonymous;

  bool emailVerified;

  @override
  final List<String> providerIds;

  final bool becomesVerifiedOnReload;
  final FirebaseAuthException? sendError;
  final FirebaseAuthException? deleteError;
  int sendCalls = 0;
  int reloadCalls = 0;
  int deleteCalls = 0;
  int signOutCalls = 0;

  @override
  bool get isCurrentUserAnonymous => anonymous;

  @override
  bool get isCurrentUserEmailVerified => emailVerified;

  @override
  Future<void> reloadCurrentUser() async {
    reloadCalls += 1;
    if (becomesVerifiedOnReload) emailVerified = true;
  }

  @override
  Future<void> deleteCurrentUser() async {
    deleteCalls += 1;
    final error = deleteError;
    if (error != null) throw error;
    currentUserId = null;
    currentUserEmail = null;
  }

  @override
  Future<void> sendEmailVerification() async {
    sendCalls += 1;
    final error = sendError;
    if (error != null) throw error;
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    currentUserId = null;
    currentUserEmail = null;
  }
}

class _FakeAuthAccountGateway implements AuthAccountGateway {
  _FakeAuthAccountGateway({
    this.googleUid = 'google-user',
    this.registrationUid = 'registered-user',
    this.emailSignInError,
    this.registrationError,
  });

  final String googleUid;
  final String registrationUid;
  final FirebaseAuthException? emailSignInError;
  final FirebaseAuthException? registrationError;
  int googleSignInCalls = 0;
  int emailSignInCalls = 0;
  int registrationCalls = 0;

  @override
  Future<String> registerWithEmailPassword({
    required String email,
    required String password,
  }) async {
    registrationCalls += 1;
    final error = registrationError;
    if (error != null) throw error;
    return registrationUid;
  }

  @override
  Future<String> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    emailSignInCalls += 1;
    final error = emailSignInError;
    if (error != null) throw error;
    return 'email-user';
  }

  @override
  Future<String> signInWithGoogleIdToken(String idToken) async {
    googleSignInCalls += 1;
    return googleUid;
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
