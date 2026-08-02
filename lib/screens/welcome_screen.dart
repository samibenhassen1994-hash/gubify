import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../repositories/user_repository.dart';
import '../modules/community/screens/community_explorer_screen.dart';
import '../widgets/gubify_background.dart';
import '../widgets/gubify_logo.dart';
import '../widgets/primary_button.dart';
import '../widgets/user_header.dart';
import 'gub/create_gub_screen.dart';
import 'gub/join_gub_screen.dart';
import 'gub/my_gubs_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  Future<void> _openWebsite() async {
    final uri = Uri.parse('https://www.gubify.com');

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openSupport() async {
    final uri = Uri.parse(
      'https://www.gofundme.com/f/help-bring-gubify-to-everyone?attribution_id=sl:3b8bc3c9-610c-4bdd-8a69-414992484cbc&ts=1784696885&utm_campaign=natman_sharesheet_dash&utm_medium=customer&utm_source=whatsapp',
    );

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _showLinkError();
      }
    } catch (_) {
      if (mounted) {
        _showLinkError();
      }
    }
  }

  void _showLinkError() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Unable to open this link.')));
  }

  void _goToCreateGub() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateGubScreen()),
    );
  }

  void _goToMyGubs() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyGubsScreen()),
    );
  }

  void _goToJoinGub() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const JoinGubScreen()),
    );
  }

  void _goToCommunityExplorer() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CommunityExplorerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GubifyBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              UserHeader(
                darkMode: true,
                personalProfileEnabled: true,
                showCard: true,
                darkCard: true,
                onExploreCommunities: _goToCommunityExplorer,
              ),

              // Il logo resta centrato nella parte libera della schermata.
              Expanded(
                flex: 5,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 190,
                        height: 190,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF3B82F6,
                              ).withValues(alpha: 0.50),
                              blurRadius: 150,
                              spreadRadius: 45,
                            ),
                          ],
                        ),
                      ),

                      // Non cambiare questo valore con clamp o calcoli.
                      // Il PNG ritagliato farà apparire il logo molto grande.
                      const GubifyLogo(width: 260.0),
                    ],
                  ),
                ),
              ),

              _buildGreeting(),

              const SizedBox(height: 10),

              _CommunityExplorerPortal(onPressed: _goToCommunityExplorer),

              const SizedBox(height: 14),

              const Text(
                'Create your Gub or join an existing one\nto collaborate with your group.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Color(0xFFB5BCC9),
                ),
              ),

              const SizedBox(height: 20),

              PrimaryButton(text: 'Create Gub', onPressed: _goToCreateGub),

              const SizedBox(height: 12),

              _outlinedButton(
                icon: Icons.home_work_outlined,
                label: 'My Gubs',
                onPressed: _goToMyGubs,
              ),

              const SizedBox(height: 12),

              _outlinedButton(
                icon: Icons.group_outlined,
                label: 'Join a Gub',
                onPressed: _goToJoinGub,
              ),

              const SizedBox(height: 4),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _openWebsite,
                    icon: const Icon(
                      Icons.language,
                      size: 19,
                      color: Color(0xFF60A5FA),
                    ),
                    label: const Text(
                      'Learn More',
                      style: TextStyle(
                        color: Color(0xFF60A5FA),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _openSupport,
                    icon: const Icon(
                      Icons.favorite_border,
                      size: 19,
                      color: Color(0xFFF87171),
                    ),
                    label: const Text(
                      'Support Us',
                      style: TextStyle(
                        color: Color(0xFFF87171),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Text(
        'Hi, User',
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      );
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: UserRepository.instance.getUser(user.uid),
      builder: (context, snapshot) {
        final name =
            snapshot.data?['displayName'] ?? user.displayName ?? 'User';

        return Text(
          'Hi, $name',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        );
      },
    );
  }

  Widget _outlinedButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.06),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 17,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityExplorerPortal extends StatelessWidget {
  final VoidCallback onPressed;

  const _CommunityExplorerPortal({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Explore communities',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF2563EB).withValues(alpha: 0.42),
                const Color(0xFF06B6D4).withValues(alpha: 0.24),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.22),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onPressed,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  _CommunityPortalIcon(),
                  SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Explore Communities',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Discover public Gubs by interests, language and people.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFFDCEBFF),
                            fontSize: 12,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CommunityPortalIcon extends StatelessWidget {
  const _CommunityPortalIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF93C5FD).withValues(alpha: 0.24),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF60A5FA).withValues(alpha: 0.36),
            blurRadius: 14,
          ),
        ],
      ),
      child: const Icon(Icons.public_rounded, color: Colors.white),
    );
  }
}
