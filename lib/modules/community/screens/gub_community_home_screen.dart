import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../screens/gub/my_gubs_screen.dart';
import '../../../services/app_sound_service.dart';
import '../../../widgets/gub_screen_background.dart';
import '../models/community_access_request_model.dart';
import '../models/community_model.dart';
import '../repositories/community_repository.dart';
import '../services/community_service.dart';
import '../widgets/community_home_content.dart';
import '../widgets/community_pending_requests_button.dart';
import 'community_join_requests_screen.dart';
import 'community_public_details_screen.dart';
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
  late final Stream<CommunityModel?> _communityStream;
  late final Stream<int> _pendingRequestCountStream;
  bool _unavailableNavigationScheduled = false;
  bool _pendingRequestCountInitialized = false;
  int _previousPendingRequestCount = 0;

  @override
  void initState() {
    super.initState();
    _communityStream = CommunityService.instance.currentMemberCommunityStream(
      widget.communityId,
    );
    _pendingRequestCountStream = CommunityService.instance
        .pendingJoinRequestCountStream(widget.communityId)
        .map((count) {
          _observePendingRequestCount(count);
          return count;
        });
    unawaited(_playApprovalJoinSoundIfNeeded());
  }

  Future<void> _playApprovalJoinSoundIfNeeded() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final state = await CommunityService.instance.loadPublicAccessState(
        widget.communityId,
      );
      final request = state?.request;

      if (state == null ||
          state.isOwner ||
          !state.isMember ||
          request?.status != CommunityAccessRequestModel.approvedStatus) {
        return;
      }

      final requestVersion =
          request!.createdAt?.millisecondsSinceEpoch.toString() ?? 'unknown';
      final preferenceKey =
          'communityApprovalJoinSound:${user.uid}:${widget.communityId}:$requestVersion';
      final preferences = await SharedPreferences.getInstance();

      if (preferences.getBool(preferenceKey) == true) return;

      await preferences.setBool(preferenceKey, true);
      await AppSoundService.instance.playJoined();
    } catch (error) {
      debugPrint('Unable to play Community approval join sound: $error');
    }
  }

  void _observePendingRequestCount(int count) {
    if (!_pendingRequestCountInitialized) {
      _pendingRequestCountInitialized = true;
      _previousPendingRequestCount = count;
      return;
    }

    if (count > _previousPendingRequestCount) {
      unawaited(AppSoundService.instance.playNotification());
    }

    _previousPendingRequestCount = count;
  }

  void _leaveUnavailableCommunity() {
    if (_unavailableNavigationScheduled) return;
    _unavailableNavigationScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) {
        _unavailableNavigationScheduled = false;
        return;
      }

      final userId = FirebaseAuth.instance.currentUser?.uid;
      var message = 'This Community is no longer available.';
      var showPublicDetails = false;
      if (userId != null) {
        try {
          final banned = await CommunityRepository.instance.isUserBanned(
            communityId: widget.communityId,
            userId: userId,
          );
          if (banned) {
            message =
                'You were banned from this Community by an administrator.';
          } else {
            final access = await CommunityService.instance
                .loadPublicAccessState(widget.communityId);
            showPublicDetails =
                access != null && access.community.deletionStatus != 'deleting';
          }
        } catch (_) {}
      }
      if (!mounted) {
        return;
      }
      if (showPublicDetails) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                CommunityPublicDetailsScreen(communityId: widget.communityId),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));

      final navigator = Navigator.of(context);
      final didPop = await navigator.maybePop();

      if (!didPop && mounted) {
        await navigator.pushReplacement(
          MaterialPageRoute(builder: (_) => const MyGubsScreen()),
        );
      }

      if (mounted) {
        _unavailableNavigationScheduled = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return GubScreenBackground(
      variant: GubBackgroundAssignments.createGub,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              StreamBuilder<CommunityModel?>(
                stream: _communityStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return CommunityStateMessage(
                      icon: Icons.error_outline,
                      message: 'Unable to load this community.',
                      details: snapshot.error.toString(),
                    );
                  }

                  final community = snapshot.data;

                  if (community == null) {
                    _leaveUnavailableCommunity();
                    return const CommunityStateMessage(
                      icon: Icons.groups_outlined,
                      message: 'This Community is no longer available.',
                    );
                  }

                  if (community.deletionStatus == 'deleting') {
                    final currentUserId =
                        FirebaseAuth.instance.currentUser?.uid;
                    final isDeletingOwner =
                        community.ownerId == currentUserId &&
                        (community.deletionRequestedBy == null ||
                            community.deletionRequestedBy == currentUserId);

                    if (!isDeletingOwner) {
                      _leaveUnavailableCommunity();
                    }

                    return _CommunityDeletionInProgress(
                      communityId: community.communityId,
                      isOwner: isDeletingOwner,
                    );
                  }

                  final isOwner =
                      community.ownerId ==
                      FirebaseAuth.instance.currentUser?.uid;

                  return Stack(
                    children: [
                      CommunityHomeContent(
                        community: community,
                        isKeyboardOpen: isKeyboardOpen,
                      ),
                      Positioned(
                        top: 12,
                        right: 20,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CommunityPendingRequestsButton(
                              isVisible: isOwner,
                              countStream: _pendingRequestCountStream,
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CommunityJoinRequestsScreen(
                                    community: community,
                                  ),
                                ),
                              ),
                            ),
                            if (isOwner) const SizedBox(width: 10),
                            Semantics(
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
                          ],
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
                  label: 'Back',
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

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _running = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
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
}
