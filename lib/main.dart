import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'screens/welcome_screen.dart';
import 'theme/app_theme.dart';
import 'pages/startup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
      home: const StartupScreen(),
    );
  }
}