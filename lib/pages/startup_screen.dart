import 'package:flutter/material.dart';

import 'name_screen.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 300), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const NameScreen(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF04091A),
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}