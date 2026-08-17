import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/services/auth_service.dart';

void main() {
  test(
    'password change reauthenticates before updating and preserves UID',
    () async {
      final gateway = _PasswordGateway();
      final service = AuthService(
        authLinkGateway: const _AuthGateway(),
        passwordChangeGateway: gateway,
      );
      final before = gateway.currentUserId;
      final result = await service.changePassword(
        currentPassword: 'current-secret',
        newPassword: 'new-secret',
      );
      expect(result.isSuccess, isTrue);
      expect(gateway.calls, ['reauthenticate', 'update']);
      expect(gateway.currentUserId, before);
    },
  );

  test('wrong current password is controlled and does not update', () async {
    final gateway = _PasswordGateway(errorCode: 'wrong-password');
    final result = await AuthService(
      authLinkGateway: const _AuthGateway(),
      passwordChangeGateway: gateway,
    ).changePassword(currentPassword: 'wrong', newPassword: 'new-secret');
    expect(result.status, PasswordChangeStatus.wrongPassword);
    expect(gateway.calls, ['reauthenticate']);
  });
}

class _PasswordGateway implements PasswordChangeGateway {
  _PasswordGateway({this.errorCode});
  final String? errorCode;
  final List<String> calls = [];
  @override
  String? get currentUserEmail => 'person@example.com';
  @override
  String? get currentUserId => 'stable-uid';
  @override
  Future<void> reauthenticateWithPassword({
    required String email,
    required String password,
  }) async {
    calls.add('reauthenticate');
    if (errorCode != null) throw FirebaseAuthException(code: errorCode!);
  }

  @override
  Future<void> updatePassword(String password) async => calls.add('update');
}

class _AuthGateway implements AuthLinkGateway {
  const _AuthGateway();
  @override
  String? get currentUserId => 'stable-uid';
  @override
  bool get isCurrentUserAnonymous => false;
  @override
  List<String> get providerIds => const ['password'];
  @override
  Future<AuthLinkState> linkEmailPassword({
    required String email,
    required String password,
  }) => throw UnimplementedError();
  @override
  Future<AuthLinkState> linkGoogleIdToken(String idToken) =>
      throw UnimplementedError();
}
