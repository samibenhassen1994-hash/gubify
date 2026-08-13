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
  const EmailPasswordLinkResult._({required this.status, this.uid, this.email});

  final EmailPasswordLinkStatus status;
  final String? uid;
  final String? email;

  bool get isSuccess => status == EmailPasswordLinkStatus.success;

  const EmailPasswordLinkResult.success({
    required String uid,
    required String email,
  }) : this._(status: EmailPasswordLinkStatus.success, uid: uid, email: email);

  const EmailPasswordLinkResult.failure(EmailPasswordLinkStatus status)
    : this._(status: status);
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
    GoogleCredentialProvider? googleCredentialProvider,
  }) : _auth = auth ?? (authLinkGateway == null ? FirebaseAuth.instance : null),
       _authLinkGateway =
           authLinkGateway ??
           FirebaseAuthLinkGateway(auth ?? FirebaseAuth.instance),
       _googleCredentialProvider =
           googleCredentialProvider ?? GoogleSignInCredentialProvider() {
    _userService = userService;
  }

  final FirebaseAuth? _auth;
  late UserService? _userService;
  final AuthLinkGateway _authLinkGateway;
  final GoogleCredentialProvider _googleCredentialProvider;

  User? get currentUser => _auth?.currentUser;

  bool get isCurrentUserAnonymous => _authLinkGateway.isCurrentUserAnonymous;

  bool get isGoogleLinked =>
      _authLinkGateway.providerIds.contains(GoogleAuthProvider.PROVIDER_ID);

  bool get isPasswordLinked =>
      _authLinkGateway.providerIds.contains(EmailAuthProvider.PROVIDER_ID);

  List<String> get providerIds =>
      List.unmodifiable(_authLinkGateway.providerIds);

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
      return EmailPasswordLinkResult.success(uid: uidBeforeLink, email: email);
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
