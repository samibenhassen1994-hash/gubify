import 'package:firebase_auth/firebase_auth.dart';

import 'user_service.dart';

class AuthService {
  AuthService();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();

  User? get currentUser => _auth.currentUser;

  Future<User> signInAnonymously() async {
    final credential = await _auth.signInAnonymously();
    return credential.user!;
  }

  Future<void> createProfile(String displayName) async {
    final user = currentUser;

    if (user == null) {
      throw Exception("No authenticated user.");
    }

    await _userService.createUser(
      userId: user.uid,
      displayName: displayName,
    );
  }
}