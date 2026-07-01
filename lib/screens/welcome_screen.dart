import 'package:flutter/material.dart';

import '../widgets/primary_button.dart';
import 'create_home_screen.dart';
import 'join_home_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.home_rounded,
              size: 80,
              color: Color(0xFF2563EB),
            ),

            const SizedBox(height: 20),

            const Text(
              "Homyou",
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              "Organizza la tua casa.\nInsieme.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Color(0xFF6B7280),
              ),
            ),

            const SizedBox(height: 50),

            PrimaryButton(
              text: "Crea una casa",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateHomeScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const JoinHomeScreen(),
                  ),
                );
              },
              child: const Text(
                "Ho un invito",
                style: TextStyle(
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}