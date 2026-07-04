import 'package:uuid/uuid.dart';

import 'local_storage_service.dart';
import 'user_service.dart';

class AuthService {
  final UserService _userService = UserService();
  final LocalStorageService _localStorage = LocalStorageService();

  final Uuid _uuid = const Uuid();

  Future<void> registerUser(String displayName) async {
    final userId = _uuid.v4();

    await _userService.createUser(
      userId: userId,
      displayName: displayName,
    );

    await _localStorage.saveUser(
      userId: userId,
      displayName: displayName,
    );
  }
}