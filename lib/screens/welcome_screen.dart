import 'package:flutter/material.dart';

import '../widgets/hubfy_background.dart';
import '../widgets/hubfy_logo.dart';
import '../widgets/primary_button.dart';

import 'create_home_screen.dart';
import 'join_home_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return HubfyBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              children: [

                // Glow dietro al logo
                Stack(
                  alignment: Alignment.center,
                  children: [

                    Container(
                      width: 180,
                      height: 1,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB)
                                .withValues(alpha: .45),
                            blurRadius: 120,
                            spreadRadius: 30,
                          ),
                        ],
                      ),
                    ),

                    const HubfyLogo(width: 500),
                  ],
                ),

                const SizedBox(height: 0),

                const Text(
                  "Welcome",
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 255, 255, 255),
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  "Organizza tutto.\nIn un unico posto.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    height: 1.45,
                    color: Color(0xFFD1D5DB),
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  "Crea il tuo Hub o unisciti ad uno esistente\nper collaborare con il tuo gruppo.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: Color(0xFF9CA3AF),
                  ),
                ),

                const SizedBox(height: 45),

                PrimaryButton(
                  text: "Crea un Hub",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateHomeScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const JoinHomeScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: .18),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [

                        Icon(
                          Icons.group_outlined,
                          color: Colors.white,
                        ),

                        SizedBox(width: 12),

                        Text(
                          "Unisciti ad un Hub",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                TextButton(
                  onPressed: () {},
                  child: const Text(
                    "Scopri di più",
                    style: TextStyle(
                      color: Color(0xFF3B82F6),
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}