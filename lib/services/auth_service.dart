import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'user_service.dart';

enum GoogleLinkStatus {
  success,
  noCurrentUser,
  cancelled,
  providerAlreadyLinked,
  credentialAlreadyInUse,
  accountExistsWithDifferentCredential,
  invalidCredential,
  networkRequestFailed,
  operationNotAllowed,
  tooManyRequests,
  uidChanged,
  unknownFailure,
}

class GoogleLinkResult {
  const GoogleLinkResult._({
    required this.status,
    this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.providerIds = const <String>[],
  });

  final GoogleLinkStatus status;
  final String? uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final List<String> providerIds;

  bool get isSuccess => status == GoogleLinkStatus.success;

  factory GoogleLinkResult.success({
    required String uid,
    required GoogleIdentity identity,
    required List<String> providerIds,
  }) {
    return GoogleLinkResult._(
      status: GoogleLinkStatus.success,
      uid: uid,
      email: identity.email,
      displayName: identity.displayName,
      photoUrl: identity.photoUrl,
      providerIds: providerIds,
    );
  }

  const GoogleLinkResult.failure(GoogleLinkStatus status)
    : this._(status: status);
}

class GoogleIdentity {
  const GoogleIdentity({
    required this.idToken,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  final String idToken;
  final String email;
  final String? displayName;
  final String? photoUrl;
}

enum EmailPasswordLinkStatus {
  success,
  noCurrentUser,
  userNotAnonymous,
  providerAlreadyLinked,
  invalidEmail,
  weakPassword,
  emailAlreadyInUse,
  credentialAlreadyInUse,
  requiresRecentLogin,
  networkRequestFailed,
  tooManyRequests,
  uidChanged,
  unknownFailure,
}

class EmailPasswordLinkResult {
  const EmailPasswordLinkResult._({
    required this.status,
    this.uid,
    this.email,
    this.verificationStatus,
  });

  final EmailPasswordLinkStatus status;
  final String? uid;
  final String? email;
  final EmailVerificationStatus? verificationStatus;

  bool get isSuccess => status == EmailPasswordLinkStatus.success;

  const EmailPasswordLinkResult.success({
    required String uid,
    required String email,
    EmailVerificationStatus? verificationStatus,
  }) : this._(
         status: EmailPasswordLinkStatus.success,
         uid: uid,
         email: email,
         verificationStatus: verificationStatus,
       );

  const EmailPasswordLinkResult.failure(EmailPasswordLinkStatus status)
    : this._(status: status);
}

enum AccountAuthStatus {
  success,
  cancelled,
  invalidEmail,
  invalidCredential,
  emailAlreadyInUse,
  weakPassword,
  userDisabled,
  networkRequestFailed,
  tooManyRequests,
  operationNotAllowed,
  unknownFailure,
}

class AccountAuthResult {
  const AccountAuthResult._({required this.status, this.uid});

  final AccountAuthStatus status;
  final String? uid;

  bool get isSuccess => status == AccountAuthStatus.success;

  const AccountAuthResult.success(String uid)
    : this._(status: AccountAuthStatus.success, uid: uid);

  const AccountAuthResult.failure(AccountAuthStatus status)
    : this._(status: status);
}

enum EmailVerificationStatus {
  success,
  notVerified,
  noCurrentUser,
  networkRequestFailed,
  tooManyRequests,
  unknownFailure,
}

enum IncompleteProfileExitStatus {
  success,
  noCurrentUser,
  profileAlreadyExists,
  unknownFailure,
}

enum IncompleteProfileExitAction {
  anonymousUserDeleted,
  anonymousUserSignedOut,
  accountSignedOut,
}

class IncompleteProfileExitResult {
  const IncompleteProfileExitResult._({required this.status, this.action});

  final IncompleteProfileExitStatus status;
  final IncompleteProfileExitAction? action;

  bool get isSuccess => status == IncompleteProfileExitStatus.success;

  const IncompleteProfileExitResult.success(
    IncompleteProfileExitAction action,
  ) : this._(status: IncompleteProfileExitStatus.success, action: action);

  const IncompleteProfileExitResult.failure(
    IncompleteProfileExitStatus status,
  ) : this._(status: status);
}

class EmailVerificationResult {
  const EmailVerificationResult._({
    required this.status,
    this.email,
    this.isVerified = false,
  });

  final EmailVerificationStatus status;
  final String? email;
  final bool isVerified;

  bool get isSuccess => status == EmailVerificationStatus.success;

  const EmailVerificationResult.success({String? email, bool isVerified = false})
    : this._(
        status: EmailVerificationStatus.success,
        email: email,
        isVerified: isVerified,
      );

  const EmailVerificationResult.failure(
    EmailVerificationStatus status, {
    String? email,
    bool isVerified = false,
  }) : this._(status: status, email: email, isVerified: isVerified);
}

enum GoogleCredentialFailure { cancelled, invalidCredential, unknown }

class GoogleCredentialException implements Exception {
  const GoogleCredentialException(this.failure);

  final GoogleCredentialFailure failure;
}

abstract interface class GoogleCredentialProvider {
  Future<GoogleIdentity> authenticate();
}

abstract interface class AuthLinkGateway {
  String? get currentUserId;
  bool get isCurrentUserAnonymous;
  List<String> get providerIds;

  Future<AuthLinkState> linkGoogleIdToken(String idToken);
  Future<AuthLinkState> linkEmailPassword({
    required String email,
    required String password,
  });
}

abstract interface class AuthAccountGateway {
  Future<String> signInWithGoogleIdToken(String idToken);
  Future<String> signInWithEmailPassword({
    required String email,
    required String password,
  });
  Future<String> registerWithEmailPassword({
    required String email,
    required String password,
  });
}

abstract interface class AuthVerificationGateway {
  String? get currentUserId;
  String? get currentUserEmail;
  bool get isCurrentUserAnonymous;
  bool get isCurrentUserEmailVerified;
  List<String> get providerIds;

  Future<void> sendEmailVerification();
  Future<void> reloadCurrentUser();
  Future<void> deleteCurrentUser();
  Future<void> signOut();
}

class AuthLinkState {
  const AuthLinkState({required this.uid, required this.providerIds});

  final String? uid;
  final List<String> providerIds;
}

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    UserService? userService,
    AuthLinkGateway? authLinkGateway,
    AuthAccountGateway? authAccountGateway,
    AuthVerificationGateway? authVerificationGateway,
    GoogleCredentialProvider? googleCredentialProvider,
    this.userProfileExists,
  }) : _auth = auth ?? (authLinkGateway == null ? FirebaseAuth.instance : null),
       _authLinkGateway =
           authLinkGateway ??
           FirebaseAuthLinkGateway(auth ?? FirebaseAuth.instance),
       _authAccountGateway =
           authAccountGateway ??
           (authLinkGateway == null
               ? FirebaseAuthAccountGateway(auth ?? FirebaseAuth.instance)
               : const _UnavailableAuthAccountGateway()),
       _authVerificationGateway =
           authVerificationGateway ??
           (authLinkGateway == null
               ? FirebaseAuthVerificationGateway(auth ?? FirebaseAuth.instance)
               : const _UnavailableAuthVerificationGateway()),
       _googleCredentialProvider =
           googleCredentialProvider ?? GoogleSignInCredentialProvider() {
    _userService = userService;
  }

  final FirebaseAuth? _auth;
  late UserService? _userService;
  final AuthLinkGateway _authLinkGateway;
  final AuthAccountGateway _authAccountGateway;
  final AuthVerificationGateway _authVerificationGateway;
  final GoogleCredentialProvider _googleCredentialProvider;
  final Future<bool> Function(String userId)? userProfileExists;

  User? get currentUser => _auth?.currentUser;

  String? get currentUserId =>
      _auth?.currentUser?.uid ?? _authVerificationGateway.currentUserId;

  String? get currentUserEmail =>
      _auth?.currentUser?.email ?? _authVerificationGateway.currentUserEmail;

  bool get isCurrentUserAnonymous => _authLinkGateway.isCurrentUserAnonymous;

  bool get isGoogleLinked =>
      _authLinkGateway.providerIds.contains(GoogleAuthProvider.PROVIDER_ID);

  bool get isPasswordLinked =>
      _authLinkGateway.providerIds.contains(EmailAuthProvider.PROVIDER_ID);

  List<String> get providerIds =>
      List.unmodifiable(_authLinkGateway.providerIds);

  Stream<User?> get authStateChanges =>
      _auth?.authStateChanges() ?? Stream<User?>.value(null);

  bool requiresEmailVerification(User user) {
    final providerIds = user.providerData
        .map((provider) => provider.providerId)
        .toSet();
    return !user.isAnonymous &&
        providerIds.contains(EmailAuthProvider.PROVIDER_ID) &&
        !providerIds.contains(GoogleAuthProvider.PROVIDER_ID) &&
        !user.emailVerified;
  }

  bool get requiresCurrentUserEmailVerification {
    final providerIds = _authVerificationGateway.providerIds;
    return !_authVerificationGateway.isCurrentUserAnonymous &&
        providerIds.contains(EmailAuthProvider.PROVIDER_ID) &&
        !providerIds.contains(GoogleAuthProvider.PROVIDER_ID) &&
        !_authVerificationGateway.isCurrentUserEmailVerified;
  }

  Future<User> signInAnonymously() async {
    final auth = _auth;
    if (auth == null) {
      throw StateError('FirebaseAuth is unavailable for anonymous sign-in.');
    }
    final credential = await auth.signInAnonymously();
    return credential.user!;
  }

  Future<void> createProfile(String displayName) async {
    final user = currentUser;

    if (user == null) {
      throw Exception('No authenticated user.');
    }

    await (_userService ??= UserService()).createUser(
      userId: user.uid,
      displayName: displayName,
    );
  }

  /// Links Google to the already authenticated Firebase user.
  ///
  /// The link operation, rather than Firebase sign-in, preserves the existing
  /// Firebase UID and therefore keeps the existing Firestore profile intact.
  Future<GoogleLinkResult> linkCurrentAnonymousUserWithGoogle() async {
    final uidBeforeLink = _authLinkGateway.currentUserId;
    if (uidBeforeLink == null) {
      return const GoogleLinkResult.failure(GoogleLinkStatus.noCurrentUser);
    }

    if (isGoogleLinked) {
      return const GoogleLinkResult.failure(
        GoogleLinkStatus.providerAlreadyLinked,
      );
    }

    try {
      final identity = await _googleCredentialProvider.authenticate();
      if (identity.idToken.isEmpty) {
        return const GoogleLinkResult.failure(
          GoogleLinkStatus.invalidCredential,
        );
      }

      final linkedUser = await _authLinkGateway.linkGoogleIdToken(
        identity.idToken,
      );
      if (linkedUser.uid != uidBeforeLink) {
        return const GoogleLinkResult.failure(GoogleLinkStatus.uidChanged);
      }

      return GoogleLinkResult.success(
        uid: uidBeforeLink,
        identity: identity,
        providerIds: linkedUser.providerIds,
      );
    } on GoogleCredentialException catch (error) {
      return GoogleLinkResult.failure(switch (error.failure) {
        GoogleCredentialFailure.cancelled => GoogleLinkStatus.cancelled,
        GoogleCredentialFailure.invalidCredential =>
          GoogleLinkStatus.invalidCredential,
        GoogleCredentialFailure.unknown => GoogleLinkStatus.unknownFailure,
      });
    } on FirebaseAuthException catch (error) {
      return GoogleLinkResult.failure(_firebaseErrorStatus(error.code));
    } catch (_) {
      return const GoogleLinkResult.failure(GoogleLinkStatus.unknownFailure);
    }
  }

  Future<EmailPasswordLinkResult> linkCurrentUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final uidBeforeLink = _authLinkGateway.currentUserId;
    if (uidBeforeLink == null) {
      return const EmailPasswordLinkResult.failure(
        EmailPasswordLinkStatus.noCurrentUser,
      );
    }
    if (!isCurrentUserAnonymous) {
      return const EmailPasswordLinkResult.failure(
        EmailPasswordLinkStatus.userNotAnonymous,
      );
    }
    if (isPasswordLinked) {
      return const EmailPasswordLinkResult.failure(
        EmailPasswordLinkStatus.providerAlreadyLinked,
      );
    }

    try {
      final linkedUser = await _authLinkGateway.linkEmailPassword(
        email: email,
        password: password,
      );
      if (linkedUser.uid != uidBeforeLink) {
        return const EmailPasswordLinkResult.failure(
          EmailPasswordLinkStatus.uidChanged,
        );
      }
      final verification = await sendCurrentUserEmailVerification();
      return EmailPasswordLinkResult.success(
        uid: uidBeforeLink,
        email: email,
        verificationStatus: verification.status,
      );
    } on FirebaseAuthException catch (error) {
      return EmailPasswordLinkResult.failure(
        _emailPasswordErrorStatus(error.code),
      );
    } catch (_) {
      return const EmailPasswordLinkResult.failure(
        EmailPasswordLinkStatus.unknownFailure,
      );
    }
  }

  Future<AccountAuthResult> signInWithGoogle() async {
    try {
      final identity = await _googleCredentialProvider.authenticate();
      if (identity.idToken.isEmpty) {
        return const AccountAuthResult.failure(
          AccountAuthStatus.invalidCredential,
        );
      }
      final uid = await _authAccountGateway.signInWithGoogleIdToken(
        identity.idToken,
      );
      return AccountAuthResult.success(uid);
    } on GoogleCredentialException catch (error) {
      return AccountAuthResult.failure(switch (error.failure) {
        GoogleCredentialFailure.cancelled => AccountAuthStatus.cancelled,
        GoogleCredentialFailure.invalidCredential =>
          AccountAuthStatus.invalidCredential,
        GoogleCredentialFailure.unknown => AccountAuthStatus.unknownFailure,
      });
    } on FirebaseAuthException catch (error) {
      return AccountAuthResult.failure(_accountAuthErrorStatus(error.code));
    } catch (_) {
      return const AccountAuthResult.failure(AccountAuthStatus.unknownFailure);
    }
  }

  Future<AccountAuthResult> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return AccountAuthResult.success(
        await _authAccountGateway.signInWithEmailPassword(
          email: email,
          password: password,
        ),
      );
    } on FirebaseAuthException catch (error) {
      return AccountAuthResult.failure(_accountAuthErrorStatus(error.code));
    } catch (_) {
      return const AccountAuthResult.failure(AccountAuthStatus.unknownFailure);
    }
  }

  Future<AccountAuthResult> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final uid = await _authAccountGateway.registerWithEmailPassword(
          email: email,
          password: password,
        );
      await sendCurrentUserEmailVerification();
      return AccountAuthResult.success(uid);
    } on FirebaseAuthException catch (error) {
      return AccountAuthResult.failure(_accountAuthErrorStatus(error.code));
    } catch (_) {
      return const AccountAuthResult.failure(AccountAuthStatus.unknownFailure);
    }
  }

  Future<EmailVerificationResult> sendCurrentUserEmailVerification() async {
    final email = currentUserEmail;
    if (_authVerificationGateway.currentUserId == null) {
      return EmailVerificationResult.failure(
        EmailVerificationStatus.noCurrentUser,
        email: email,
      );
    }

    try {
      await _authVerificationGateway.sendEmailVerification();
      return EmailVerificationResult.success(email: email);
    } on FirebaseAuthException catch (error) {
      return EmailVerificationResult.failure(
        _emailVerificationErrorStatus(error.code),
        email: email,
      );
    } catch (_) {
      return EmailVerificationResult.failure(
        EmailVerificationStatus.unknownFailure,
        email: email,
      );
    }
  }

  Future<EmailVerificationResult> reloadCurrentUser() async {
    if (_authVerificationGateway.currentUserId == null) {
      return const EmailVerificationResult.failure(
        EmailVerificationStatus.noCurrentUser,
      );
    }

    try {
      await _authVerificationGateway.reloadCurrentUser();
      final isVerified = _authVerificationGateway.isCurrentUserEmailVerified;
      return isVerified
          ? EmailVerificationResult.success(
              email: currentUserEmail,
              isVerified: true,
            )
          : EmailVerificationResult.failure(
              EmailVerificationStatus.notVerified,
              email: currentUserEmail,
            );
    } on FirebaseAuthException catch (error) {
      return EmailVerificationResult.failure(
        _emailVerificationErrorStatus(error.code),
        email: currentUserEmail,
      );
    } catch (_) {
      return EmailVerificationResult.failure(
        EmailVerificationStatus.unknownFailure,
        email: currentUserEmail,
      );
    }
  }

  Future<void> signOutForAuthSwitch() => _authVerificationGateway.signOut();

  Future<IncompleteProfileExitResult>
  exitIncompleteProfileOnboarding() async {
    final uid = _authVerificationGateway.currentUserId;
    if (uid == null) {
      return const IncompleteProfileExitResult.failure(
        IncompleteProfileExitStatus.noCurrentUser,
      );
    }

    try {
      final profileExists = await (userProfileExists?.call(uid) ??
          (_userService ??= UserService()).userExists(uid));
      if (profileExists) {
        return const IncompleteProfileExitResult.failure(
          IncompleteProfileExitStatus.profileAlreadyExists,
        );
      }

      if (_authVerificationGateway.isCurrentUserAnonymous) {
        try {
          await _authVerificationGateway.deleteCurrentUser();
          return const IncompleteProfileExitResult.success(
            IncompleteProfileExitAction.anonymousUserDeleted,
          );
        } catch (_) {
          await _authVerificationGateway.signOut();
          return const IncompleteProfileExitResult.success(
            IncompleteProfileExitAction.anonymousUserSignedOut,
          );
        }
      }

      await _authVerificationGateway.signOut();
      return const IncompleteProfileExitResult.success(
        IncompleteProfileExitAction.accountSignedOut,
      );
    } catch (_) {
      return const IncompleteProfileExitResult.failure(
        IncompleteProfileExitStatus.unknownFailure,
      );
    }
  }

  GoogleLinkStatus _firebaseErrorStatus(String code) {
    return switch (code) {
      'provider-already-linked' => GoogleLinkStatus.providerAlreadyLinked,
      'credential-already-in-use' => GoogleLinkStatus.credentialAlreadyInUse,
      'account-exists-with-different-credential' =>
        GoogleLinkStatus.accountExistsWithDifferentCredential,
      'invalid-credential' => GoogleLinkStatus.invalidCredential,
      'network-request-failed' => GoogleLinkStatus.networkRequestFailed,
      'operation-not-allowed' => GoogleLinkStatus.operationNotAllowed,
      'too-many-requests' => GoogleLinkStatus.tooManyRequests,
      _ => GoogleLinkStatus.unknownFailure,
    };
  }

  EmailPasswordLinkStatus _emailPasswordErrorStatus(String code) {
    return switch (code) {
      'invalid-email' => EmailPasswordLinkStatus.invalidEmail,
      'weak-password' => EmailPasswordLinkStatus.weakPassword,
      'email-already-in-use' => EmailPasswordLinkStatus.emailAlreadyInUse,
      'credential-already-in-use' =>
        EmailPasswordLinkStatus.credentialAlreadyInUse,
      'provider-already-linked' =>
        EmailPasswordLinkStatus.providerAlreadyLinked,
      'requires-recent-login' => EmailPasswordLinkStatus.requiresRecentLogin,
      'network-request-failed' => EmailPasswordLinkStatus.networkRequestFailed,
      'too-many-requests' => EmailPasswordLinkStatus.tooManyRequests,
      _ => EmailPasswordLinkStatus.unknownFailure,
    };
  }

  AccountAuthStatus _accountAuthErrorStatus(String code) {
    return switch (code) {
      'invalid-email' => AccountAuthStatus.invalidEmail,
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => AccountAuthStatus.invalidCredential,
      'email-already-in-use' => AccountAuthStatus.emailAlreadyInUse,
      'weak-password' => AccountAuthStatus.weakPassword,
      'user-disabled' => AccountAuthStatus.userDisabled,
      'network-request-failed' => AccountAuthStatus.networkRequestFailed,
      'too-many-requests' => AccountAuthStatus.tooManyRequests,
      'operation-not-allowed' => AccountAuthStatus.operationNotAllowed,
      _ => AccountAuthStatus.unknownFailure,
    };
  }

  EmailVerificationStatus _emailVerificationErrorStatus(String code) {
    return switch (code) {
      'network-request-failed' => EmailVerificationStatus.networkRequestFailed,
      'too-many-requests' => EmailVerificationStatus.tooManyRequests,
      _ => EmailVerificationStatus.unknownFailure,
    };
  }
}

class FirebaseAuthLinkGateway implements AuthLinkGateway {
  FirebaseAuthLinkGateway(this._auth);

  final FirebaseAuth _auth;

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  bool get isCurrentUserAnonymous => _auth.currentUser?.isAnonymous ?? false;

  @override
  List<String> get providerIds =>
      _auth.currentUser?.providerData
          .map((provider) => provider.providerId)
          .toList(growable: false) ??
      const <String>[];

  @override
  Future<AuthLinkState> linkGoogleIdToken(String idToken) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw StateError('No authenticated user.');
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final linkedCredential = await currentUser.linkWithCredential(credential);
    final linkedUser = linkedCredential.user;
    return AuthLinkState(
      uid: linkedUser?.uid,
      providerIds:
          linkedUser?.providerData
              .map((provider) => provider.providerId)
              .toList(growable: false) ??
          const <String>[],
    );
  }

  @override
  Future<AuthLinkState> linkEmailPassword({
    required String email,
    required String password,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw StateError('No authenticated user.');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    final linkedCredential = await currentUser.linkWithCredential(credential);
    final linkedUser = linkedCredential.user;
    return AuthLinkState(
      uid: linkedUser?.uid,
      providerIds:
          linkedUser?.providerData
              .map((provider) => provider.providerId)
              .toList(growable: false) ??
          const <String>[],
    );
  }
}

class FirebaseAuthAccountGateway implements AuthAccountGateway {
  FirebaseAuthAccountGateway(this._auth);

  final FirebaseAuth _auth;

  @override
  Future<String> signInWithGoogleIdToken(String idToken) async {
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final result = await _auth.signInWithCredential(credential);
    final user = result.user;
    if (user == null) throw StateError('Google sign-in did not return a user.');
    return user.uid;
  }

  @override
  Future<String> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = result.user;
    if (user == null) throw StateError('Email sign-in did not return a user.');
    return user.uid;
  }

  @override
  Future<String> registerWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = result.user;
    if (user == null) throw StateError('Registration did not return a user.');
    return user.uid;
  }
}

class FirebaseAuthVerificationGateway implements AuthVerificationGateway {
  FirebaseAuthVerificationGateway(this._auth);

  final FirebaseAuth _auth;

  User? get _currentUser => _auth.currentUser;

  @override
  String? get currentUserId => _currentUser?.uid;

  @override
  String? get currentUserEmail => _currentUser?.email;

  @override
  bool get isCurrentUserAnonymous => _currentUser?.isAnonymous ?? false;

  @override
  bool get isCurrentUserEmailVerified => _currentUser?.emailVerified ?? false;

  @override
  List<String> get providerIds =>
      _currentUser?.providerData
          .map((provider) => provider.providerId)
          .toList(growable: false) ??
      const <String>[];

  @override
  Future<void> sendEmailVerification() async {
    final user = _currentUser;
    if (user == null) throw StateError('No authenticated user.');
    await user.sendEmailVerification();
  }

  @override
  Future<void> reloadCurrentUser() async {
    final user = _currentUser;
    if (user == null) throw StateError('No authenticated user.');
    await user.reload();
  }

  @override
  Future<void> deleteCurrentUser() async {
    final user = _currentUser;
    if (user == null) throw StateError('No authenticated user.');
    await user.delete();
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

class _UnavailableAuthAccountGateway implements AuthAccountGateway {
  const _UnavailableAuthAccountGateway();

  Never _unavailable() => throw StateError('FirebaseAuth is unavailable.');

  @override
  Future<String> registerWithEmailPassword({
    required String email,
    required String password,
  }) async => _unavailable();

  @override
  Future<String> signInWithEmailPassword({
    required String email,
    required String password,
  }) async => _unavailable();

  @override
  Future<String> signInWithGoogleIdToken(String idToken) async =>
      _unavailable();
}

class _UnavailableAuthVerificationGateway implements AuthVerificationGateway {
  const _UnavailableAuthVerificationGateway();

  Never _unavailable() => throw StateError('FirebaseAuth is unavailable.');

  @override
  String? get currentUserEmail => null;

  @override
  String? get currentUserId => null;

  @override
  bool get isCurrentUserAnonymous => false;

  @override
  bool get isCurrentUserEmailVerified => false;

  @override
  List<String> get providerIds => const <String>[];

  @override
  Future<void> reloadCurrentUser() async => _unavailable();

  @override
  Future<void> deleteCurrentUser() async => _unavailable();

  @override
  Future<void> sendEmailVerification() async => _unavailable();

  @override
  Future<void> signOut() async => _unavailable();
}

abstract interface class GoogleSignInClient {
  Future<void> initialize();
  bool supportsAuthenticate();
  Future<GoogleIdentity> authenticate();
}

class GoogleSignInCredentialProvider implements GoogleCredentialProvider {
  GoogleSignInCredentialProvider({GoogleSignInClient? client})
    : _client = client ?? _productionClient,
      _usesProductionClient = client == null;

  static final GoogleSignInClient _productionClient =
      GoogleSignInClientAdapter();
  static Future<void>? _productionInitialization;

  final GoogleSignInClient _client;
  final bool _usesProductionClient;
  Future<void>? _initialization;

  Future<void> _ensureInitialized() {
    if (_usesProductionClient) {
      return _productionInitialization ??= _client.initialize();
    }
    return _initialization ??= _client.initialize();
  }

  @override
  Future<GoogleIdentity> authenticate() async {
    try {
      await _ensureInitialized();
      if (!_client.supportsAuthenticate()) {
        throw const GoogleCredentialException(GoogleCredentialFailure.unknown);
      }

      return await _client.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        throw const GoogleCredentialException(
          GoogleCredentialFailure.cancelled,
        );
      }
      throw const GoogleCredentialException(GoogleCredentialFailure.unknown);
    }
  }
}

class GoogleSignInClientAdapter implements GoogleSignInClient {
  GoogleSignInClientAdapter({GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final GoogleSignIn _googleSignIn;

  @override
  Future<void> initialize() => _googleSignIn.initialize();

  @override
  bool supportsAuthenticate() => _googleSignIn.supportsAuthenticate();

  @override
  Future<GoogleIdentity> authenticate() async {
    final account = await _googleSignIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const GoogleCredentialException(
        GoogleCredentialFailure.invalidCredential,
      );
    }

    return GoogleIdentity(
      idToken: idToken,
      email: account.email,
      displayName: account.displayName,
      photoUrl: account.photoUrl,
    );
  }
}
