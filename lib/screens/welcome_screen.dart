import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../repositories/user_repository.dart';
import '../modules/community/screens/community_explorer_screen.dart';
import '../modules/community/screens/global_best_answer_ranking_screen.dart';
import '../modules/community/widgets/global_best_answer_ranking_preview.dart';
import '../widgets/gubify_background.dart';
import '../widgets/gubify_logo.dart';
import '../widgets/user_header.dart';
import 'gub/create_gub_screen.dart';
import 'gub/join_gub_screen.dart';
import 'gub/my_gubs_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    this.headerOverride,
    this.greetingOverride,
    this.onExploreCommunities,
    this.onOpenPersonalProfile,
    this.onCreateGub,
    this.onOpenMyGubs,
    this.onOpenJoinGub,
    this.globalRankingLoader,
    this.globalRankingScreenBuilder,
    this.compactForBottomNavigation = false,
  });

  final Widget? headerOverride;
  final Widget? greetingOverride;
  final VoidCallback? onExploreCommunities;
  final VoidCallback? onOpenPersonalProfile;
  final VoidCallback? onCreateGub;
  final VoidCallback? onOpenMyGubs;
  final VoidCallback? onOpenJoinGub;
  final GlobalRankingLoader? globalRankingLoader;
  final WidgetBuilder? globalRankingScreenBuilder;
  final bool compactForBottomNavigation;

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
    final onCreateGub = widget.onCreateGub;
    if (onCreateGub != null) {
      onCreateGub();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateGubScreen()),
    );
  }

  void _goToMyGubs() {
    final onOpenMyGubs = widget.onOpenMyGubs;
    if (onOpenMyGubs != null) {
      onOpenMyGubs();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyGubsScreen()),
    );
  }

  void _goToJoinGub() {
    final onOpenJoinGub = widget.onOpenJoinGub;
    if (onOpenJoinGub != null) {
      onOpenJoinGub();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const JoinGubScreen()),
    );
  }

  void _goToCommunityExplorer() {
    final onExploreCommunities = widget.onExploreCommunities;
    if (onExploreCommunities != null) {
      onExploreCommunities();
      return;
    }
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
            final compactActionHeight =
                veryCompact && widget.compactForBottomNavigation ? 30.0 : 44.0;
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
                            onOpenPersonalProfile:
                                widget.onOpenPersonalProfile,
                            onLearnMore: _openWebsite,
                            onSupport: _openSupport,
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
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 190,
                              child: Center(
                                child: _buildLogo(
                                  glowSize: 190,
                                  logoWidth: 260,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),

                      widget.greetingOverride ??
                          _buildGreeting(
                            compact: compact,
                            veryCompact: veryCompact,
                          ),

              SizedBox(height: veryCompact ? 4 : (compact ? 8 : 16)),

              _CreateGubGlassAction(
                onPressed: _goToCreateGub,
                size: veryCompact ? 48 : 52,
              ),

              SizedBox(height: veryCompact ? 4 : (compact ? 8 : 16)),

              _outlinedButton(
                icon: Icons.home_work_outlined,
                label: 'My Gubs',
                onPressed: _goToMyGubs,
                height: veryCompact
                    ? compactActionHeight
                    : (compact ? 44 : 54),
              ),

              SizedBox(height: veryCompact ? 2 : (compact ? 4 : 12)),

              _outlinedButton(
                icon: Icons.group_outlined,
                label: 'Join a Gub',
                onPressed: _goToJoinGub,
                height: veryCompact
                    ? compactActionHeight
                    : (compact ? 44 : 54),
              ),

              SizedBox(height: veryCompact ? 2 : 6),
              GlobalBestAnswerRankingPreview(
                compact: compact,
                loadPage: widget.globalRankingLoader,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: widget.globalRankingScreenBuilder ??
                        (_) => const GlobalBestAnswerRankingScreen(),
                  ),
                ),
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

class _CreateGubGlassAction extends StatelessWidget {
  final VoidCallback onPressed;
  final double size;

  const _CreateGubGlassAction({
    required this.onPressed,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Create Gub',
      child: Semantics(
        button: true,
        label: 'Create Gub',
        child: SizedBox(
          width: size,
          height: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: const Key('welcome-create-gub-glass-action'),
                      customBorder: const CircleBorder(),
                      onTap: onPressed,
                      child: const Center(
                        child: Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
