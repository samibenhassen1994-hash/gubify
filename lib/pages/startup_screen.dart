import 'package:flutter/material.dart';

import '../pages/name_screen.dart';
import '../screens/welcome_screen.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  final AuthService _auth = AuthService();
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }

    final uid = _auth.currentUser!.uid;
    final exists = await _userService.userExists(uid);

    if (!mounted) return;

    if (exists) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const NameScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF04091A),
      body: Center(
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2.5,
        ),
      ),
    );
  }
}