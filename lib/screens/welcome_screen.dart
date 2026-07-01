import 'package:flutter/material.dart';

import '../widgets/homyou_logo.dart';
import '../widgets/primary_button.dart';
import 'create_home_screen.dart';
import 'join_home_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF3F8FF),
              Colors.white,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Pianta
            Positioned(
              left: -140,
              bottom: 600,
              child: Opacity(
                opacity: 0.18,
                child: Image.asset(
                  'assets/illustrations/plant.png',
                  width: 500,
                ),
              ),
            ),

            // Divano
            Positioned(
              right: -280,
              bottom: 600,
              child: Opacity(
                opacity: 0.28,
                child: Image.asset(
                  'assets/illustrations/sofa.png',
                  width: 600,
                ),
              ),
            ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    children: [
                      // Luce dietro al logo
                      Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                               color: const Color(0xFF2563EB).withOpacity(0.18),
                              blurRadius: 120,
                              spreadRadius: 45,
                            ),
                          ],
                        ),
                      ),

                      Transform.translate(
                        offset: const Offset(0, -145),
                        child: Column(
                          children: [
                            const HomyouLogo(width: 400),

                            const SizedBox(height: 20),

                            const Text(
                              "Homyou",
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),

                            const SizedBox(height: 18),

                            const Text(
                              "La casa, organizzata.\nIn un unico posto.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                height: 1.5,
                                color: Color(0xFF6B7280),
                              ),
                            ),

                            const SizedBox(height: 45),

                            PrimaryButton(
                              text: "Crea una casa",
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const CreateHomeScreen(),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 25),

                            Row(
                              children: const [
                                Expanded(child: Divider()),
                                Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    "oppure",
                                    style: TextStyle(
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider()),
                              ],
                            ),

                            const SizedBox(height: 25),

                            SizedBox(
                              width: double.infinity,
                              height: 60,
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const JoinHomeScreen(),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFFE5E7EB),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(18),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Ho già un invito",
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Color(0xFF2563EB),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}