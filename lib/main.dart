import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';

void main() {
  runApp(const HomyouApp());
}

class HomyouApp extends StatelessWidget {
  const HomyouApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Homyou',
      home: const WelcomeScreen(),
    );
  }
}