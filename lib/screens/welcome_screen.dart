import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/gubify_background.dart';
import '../widgets/gubify_logo.dart';
import '../widgets/primary_button.dart';
import '../widgets/user_header.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/user_repository.dart';

import 'hub/create_hub_screen.dart';
import 'hub/join_hub_screen.dart';
import 'hub/my_hubs_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  Future<void> _openWebsite() async {
    final uri = Uri.parse('https://www.gubify.com');

    if (!await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    )) {
      throw Exception('Could not launch $uri');
    }
  }

  Future<void> _openSupport() async {
    // Cambierai questo link quando creerai la pagina crowdfunding.
    final uri = Uri.parse('https://www.gubify.com/support');

    if (!await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    )) {
      throw Exception('Could not launch $uri');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GubifyBackground(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Column(
                      children: [
                        const UserHeader(darkMode: true),

                        const Spacer(),

                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 170,
                              height: 170,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF3B82F6,
                                    ).withValues(alpha: .50),
                                    blurRadius: 150,
                                    spreadRadius: 45,
                                  ),
                                ],
                              ),
                            ),

                            const GubifyLogo(width: 340),
                          ],
                        ),

                        const SizedBox(height: 18),

                        FutureBuilder<Map<String, dynamic>?>(
  future: UserRepository.instance.getUser(
    FirebaseAuth.instance.currentUser!.uid,
  ),
  builder: (context, snapshot) {
    final displayName =
        snapshot.data?["displayName"] ?? "User";

    return Text(
      "Hi, $displayName",
      style: const TextStyle(
        fontSize: 38,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  },
),

                        const SizedBox(height: 14),

                        const Text(
                          "Everything your group needs.\nOne app.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            height: 1.45,
                            color: Color(0xFFD1D5DB),
                          ),
                        ),

                        const SizedBox(height: 14),

                        const Text(
                          "Create your Gub or join an existing one\n"
                          "to collaborate with your group.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.6,
                            color: Color.fromARGB(255, 181, 188, 201),
                          ),
                        ),

                        const Spacer(),

const SizedBox(height: 24),

PrimaryButton(
                          text: "Create Gub",
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CreateHubScreen(),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 16),
                                                SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const MyHubsScreen(),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: .06),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: .15),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.home_work_outlined,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  "My Gubs",
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

                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const JoinHubScreen(),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: .06),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: .15),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.group_outlined,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  "Join a Gub",
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

                        const SizedBox(height: 12),

                        Row(mainAxisAlignment: MainAxisAlignment.center,
  children: [

    TextButton.icon(
      onPressed: _openWebsite,
      icon: const Icon(
        Icons.language,
        color: Color(0xFF60A5FA),
        size: 20,
      ),
      label: const Text(
        "Learn More",
        style: TextStyle(
          color: Color(0xFF60A5FA),
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    const SizedBox(width: 12),

    TextButton.icon(
      onPressed: _openSupport,
      icon: const Icon(
        Icons.favorite_border,
        color: Color(0xFFF87171),
        size: 20,
      ),
      label: const Text(
        "Support Us",
        style: TextStyle(
          color: Color(0xFFF87171),
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  ],
),

const SizedBox(height: 18),
                                              ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}