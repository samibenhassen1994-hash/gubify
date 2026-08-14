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
  const WelcomeScreen({
    super.key,
    this.headerOverride,
    this.greetingOverride,
  });

  final Widget? headerOverride;
  final Widget? greetingOverride;

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 560;
            final veryCompact = constraints.maxHeight < 480;
            final compactLogoSize = (constraints.maxHeight *
                    (veryCompact ? 0.06 : 0.105))
                .clamp(veryCompact ? 22.0 : 40.0, veryCompact ? 32.0 : 52.0)
                .toDouble();
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 20),
              child: Column(
                    children: [
                      widget.headerOverride ??
                          UserHeader(
                            darkMode: true,
                            personalProfileEnabled: true,
                            showCard: !compact,
                            darkCard: !compact,
                        bottomPadding: compact ? (veryCompact ? 0 : 4) : null,
                            onExploreCommunities: _goToCommunityExplorer,
                          ),

                      if (compact)
                        Flexible(
                          fit: FlexFit.loose,
                          child: Center(
                            child: SizedBox(
                              height: compactLogoSize,
                              child: Center(
                                child: _buildLogo(
                                  glowSize: compactLogoSize,
                                  logoWidth: compactLogoSize,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          flex: 5,
                          child: Center(
                            child: _buildLogo(glowSize: 190, logoWidth: 260),
                          ),
                        ),

                      widget.greetingOverride ??
                          _buildGreeting(
                            compact: compact,
                            veryCompact: veryCompact,
                          ),

                      SizedBox(height: veryCompact ? 0 : (compact ? 2 : 10)),

                      _CommunityExplorerPortal(
                        onPressed: _goToCommunityExplorer,
                        compact: compact,
                        veryCompact: veryCompact,
                      ),

                      SizedBox(height: veryCompact ? 2 : (compact ? 4 : 14)),

              Text(
                'Create your Gub or join an existing one\nto collaborate with your group.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: veryCompact ? 11 : (compact ? 12 : 15),
                  height: veryCompact ? 1.1 : (compact ? 1.2 : 1.5),
                  color: const Color(0xFFB5BCC9),
                ),
              ),

              SizedBox(height: veryCompact ? 2 : (compact ? 6 : 20)),

              PrimaryButton(
                text: 'Create Gub',
                onPressed: _goToCreateGub,
                height: compact ? 44 : 55,
              ),

              SizedBox(height: veryCompact ? 2 : (compact ? 4 : 12)),

              _outlinedButton(
                icon: Icons.home_work_outlined,
                label: 'My Gubs',
                onPressed: _goToMyGubs,
                height: compact ? 44 : 54,
              ),

              SizedBox(height: veryCompact ? 2 : (compact ? 4 : 12)),

              _outlinedButton(
                icon: Icons.group_outlined,
                label: 'Join a Gub',
                onPressed: _goToJoinGub,
                height: compact ? 44 : 54,
              ),

              SizedBox(height: veryCompact ? 0 : (compact ? 2 : 4)),

              Wrap(
                alignment: WrapAlignment.center,
                spacing: veryCompact ? 4 : 8,
                children: [
                  TextButton.icon(
                    onPressed: _openWebsite,
                    style: compact
                        ? TextButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            padding: EdgeInsets.symmetric(
                              horizontal: veryCompact ? 2 : 4,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          )
                        : null,
                    icon: Icon(
                      Icons.language,
                      size: veryCompact ? 16 : (compact ? 17 : 19),
                      color: const Color(0xFF60A5FA),
                    ),
                    label: Text(
                      'Learn More',
                      style: TextStyle(
                        color: const Color(0xFF60A5FA),
                        fontSize: veryCompact ? 12 : (compact ? 13 : 14),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _openSupport,
                    style: compact
                        ? TextButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            padding: EdgeInsets.symmetric(
                              horizontal: veryCompact ? 2 : 4,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          )
                        : null,
                    icon: Icon(
                      Icons.favorite_border,
                      size: veryCompact ? 16 : (compact ? 17 : 19),
                      color: const Color(0xFFF87171),
                    ),
                    label: Text(
                      'Support Us',
                      style: TextStyle(
                        color: const Color(0xFFF87171),
                        fontSize: veryCompact ? 12 : (compact ? 13 : 14),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: veryCompact ? 0 : (compact ? 2 : 4)),
            ],
          ),
        );
          },
        ),
      ),
    );
  }

  Widget _buildLogo({required double glowSize, required double logoWidth}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: glowSize,
          height: glowSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.50),
                blurRadius: glowSize * 0.79,
                spreadRadius: glowSize * 0.24,
              ),
            ],
          ),
        ),
        GubifyLogo(width: logoWidth),
      ],
    );
  }

  Widget _buildGreeting({
    required bool compact,
    required bool veryCompact,
  }) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Text(
        'Hi, User',
        style: TextStyle(
          fontSize: veryCompact ? 24 : (compact ? 26 : 30),
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
          style: TextStyle(
            fontSize: veryCompact ? 24 : (compact ? 26 : 30),
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
    required double height,
  }) {
    return SizedBox(
      width: double.infinity,
      height: height,
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
  final bool compact;
  final bool veryCompact;

  const _CommunityExplorerPortal({
    required this.onPressed,
    this.compact = false,
    this.veryCompact = false,
  });

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
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: veryCompact ? 12 : (compact ? 14 : 16),
                vertical: veryCompact ? 2 : (compact ? 5 : 13),
              ),
              child: Row(
                children: [
                  _CommunityPortalIcon(
                    size: veryCompact ? 28 : (compact ? 34 : 42),
                  ),
                  SizedBox(width: veryCompact ? 8 : (compact ? 10 : 13)),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Explore Communities',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: veryCompact ? 14 : (compact ? 15 : 16),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: veryCompact ? 1 : (compact ? 2 : 3)),
                        Text(
                          'Discover public Gubs by interests, language and people.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFFDCEBFF),
                            fontSize: veryCompact ? 10 : (compact ? 11 : 12),
                            height: veryCompact ? 1 : (compact ? 1.15 : 1.25),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: veryCompact ? 4 : (compact ? 6 : 8)),
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
  const _CommunityPortalIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
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
        child: Icon(
          Icons.public_rounded,
          color: Colors.white,
          size: size * 0.57,
        ),
    );
  }
}
