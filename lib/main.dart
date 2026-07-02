import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const HubfyApp());
}

class HubfyApp extends StatelessWidget {
  const HubfyApp({super.key});

  @override
  Widget build(BuildContext context) {
   return MaterialApp(
  debugShowCheckedModeBanner: false,
  title: 'Hubfy',
  theme: AppTheme.lightTheme,
  home: const WelcomeScreen(),
);
  }
}