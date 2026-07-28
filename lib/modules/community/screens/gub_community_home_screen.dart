import 'package:flutter/material.dart';

import '../../../widgets/gub_screen_background.dart';
import '../models/community_model.dart';
import '../services/community_service.dart';
import '../widgets/community_home_content.dart';

class GubCommunityHomeScreen extends StatefulWidget {
  final String communityId;
  final CommunityModel? initialCommunity;

  const GubCommunityHomeScreen({
    super.key,
    required this.communityId,
    this.initialCommunity,
  });

  @override
  State<GubCommunityHomeScreen> createState() => _GubCommunityHomeScreenState();
}

class _GubCommunityHomeScreenState extends State<GubCommunityHomeScreen> {
  late final Future<CommunityModel?> _communityFuture;

  @override
  void initState() {
    super.initState();
    _communityFuture = widget.initialCommunity != null
        ? Future.value(widget.initialCommunity)
        : CommunityService.instance.loadCommunity(widget.communityId);
  }

  @override
  Widget build(BuildContext context) {
    return GubScreenBackground(
      variant: GubBackgroundAssignments.createGub,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              FutureBuilder<CommunityModel?>(
                future: _communityFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return CommunityStateMessage(
                      icon: Icons.error_outline,
                      message: "Unable to load this community.",
                      details: snapshot.error.toString(),
                    );
                  }

                  final community = snapshot.data;
                  if (community == null) {
                    return const CommunityStateMessage(
                      icon: Icons.groups_outlined,
                      message: "Community not found.",
                    );
                  }

                  return CommunityHomeContent(community: community);
                },
              ),
              Positioned(
                top: 12,
                left: 20,
                child: Semantics(
                  button: true,
                  label: "Back",
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.84),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.maybePop(context),
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
