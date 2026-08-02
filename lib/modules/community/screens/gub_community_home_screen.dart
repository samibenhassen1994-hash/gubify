import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../widgets/gub_screen_background.dart';
import '../models/community_model.dart';
import '../services/community_service.dart';
import '../widgets/community_home_content.dart';
import 'community_settings_screen.dart';

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
                  if (community.deletionStatus == 'deleting') {
                    return _CommunityDeletionInProgress(
                      communityId: community.communityId,
                      isOwner:
                          community.ownerId ==
                              FirebaseAuth.instance.currentUser?.uid &&
                          (community.deletionRequestedBy == null ||
                              community.deletionRequestedBy ==
                                  FirebaseAuth.instance.currentUser?.uid),
                    );
                  }

                  return Stack(
                    children: [
                      CommunityHomeContent(community: community),
                      Positioned(
                        top: 12,
                        right: 20,
                        child: Semantics(
                          button: true,
                          label: 'Community settings',
                          child: Material(
                            color: Colors.white.withValues(alpha: 0.84),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CommunitySettingsScreen(
                                    community: community,
                                  ),
                                ),
                              ),
                              child: const SizedBox(
                                width: 48,
                                height: 48,
                                child: Icon(
                                  Icons.settings_rounded,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
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

class _CommunityDeletionInProgress extends StatefulWidget {
  final String communityId;
  final bool isOwner;
  const _CommunityDeletionInProgress({
    required this.communityId,
    required this.isOwner,
  });
  @override
  State<_CommunityDeletionInProgress> createState() =>
      _CommunityDeletionInProgressState();
}

class _CommunityDeletionInProgressState
    extends State<_CommunityDeletionInProgress> {
  bool _running = false;
  Future<void> _resume() async {
    if (_running) return;
    setState(() => _running = true);
    try {
      await CommunityService.instance.resumeDeletion(
        communityId: widget.communityId,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Deletion in progress',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isOwner
                  ? 'Resume the Community cleanup.'
                  : 'This Community is no longer available.',
            ),
            if (widget.isOwner) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _running ? null : _resume,
                child: const Text('Resume deletion'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
