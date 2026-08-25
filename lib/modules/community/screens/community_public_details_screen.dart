import 'package:flutter/material.dart';

import '../../../widgets/gub_content_card.dart';
import '../../../widgets/gub_screen_background.dart';
import '../models/community_access_request_model.dart';
import '../models/community_model.dart';
import '../images/community_image_view.dart';
import '../moderation/widgets/community_report_dialog.dart';
import '../moderation/widgets/community_report_menu.dart';
import '../restrictions/models/community_restriction_model.dart';
import '../restrictions/services/community_restriction_service.dart';
import '../services/community_service.dart';
import 'gub_community_home_screen.dart';

class CommunityPublicDetailsScreen extends StatefulWidget {
  final String communityId;
  final Stream<CommunityPublicAccessState?>? stateStream;
  final Stream<CommunityRestriction>? restrictionStream;
  final CommunityReportSubmit? reportSubmit;

  const CommunityPublicDetailsScreen({
    super.key,
    required this.communityId,
    this.stateStream,
    this.restrictionStream,
    this.reportSubmit,
  });

  @override
  State<CommunityPublicDetailsScreen> createState() =>
      _CommunityPublicDetailsScreenState();
}

class _CommunityPublicDetailsScreenState
    extends State<CommunityPublicDetailsScreen> {
  late final Stream<CommunityPublicAccessState?> _stateStream;
  late final Stream<CommunityRestriction> _restrictionStream;
  bool _operationInProgress = false;
  bool _navigationInProgress = false;

  @override
  void initState() {
    super.initState();
    _stateStream =
        widget.stateStream ??
        CommunityService.instance.publicAccessStateStream(widget.communityId);
    _restrictionStream =
        widget.restrictionStream ??
        CommunityRestrictionService.instance.communityRestrictionStream(
          widget.communityId,
        );
  }

  Future<void> _runOperation(Future<void> Function() operation) async {
    if (_operationInProgress) return;
    setState(() => _operationInProgress = true);
    try {
      await operation();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _operationInProgress = false);
    }
  }

  Future<void> _joinOpenCommunity() async {
    if (_operationInProgress || _navigationInProgress) return;
    setState(() => _operationInProgress = true);
    try {
      final community = await CommunityService.instance.joinCommunity(
        communityId: widget.communityId,
      );
      if (!mounted || _navigationInProgress) return;
      _navigationInProgress = true;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              GubCommunityHomeScreen(communityId: community.communityId),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _operationInProgress = false);
    }
  }

  void _openCommunity() {
    if (_navigationInProgress) return;
    _navigationInProgress = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GubCommunityHomeScreen(communityId: widget.communityId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GubScreenBackground(
      variant: GubBackgroundAssignments.profiles,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Community details"),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: SafeArea(
          top: false,
          child: StreamBuilder<CommunityPublicAccessState?>(
            stream: _stateStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _DetailsState(message: "Unable to load this Community.");
              }
              final state = snapshot.data;
              if (state == null) {
                return const _DetailsState(
                  message: "This Community is no longer available.",
                );
              }
              return StreamBuilder<CommunityRestriction>(
                stream: _restrictionStream,
                builder: (context, restrictionSnapshot) {
                  return _buildCommunity(
                    state,
                    restrictionSnapshot.data ??
                        CommunityRestriction.unrestricted,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCommunity(
    CommunityPublicAccessState state,
    CommunityRestriction restriction,
  ) {
    final community = state.community;
    final deleting = community.deletionStatus == "deleting";
    final memberLabel = community.memberCount == 1 ? "member" : "members";
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        GubContentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!state.isOwner)
                Align(
                  alignment: Alignment.centerRight,
                  child: CommunityReportMenu(
                    community: community,
                    isOwner: state.isOwner,
                    reportSubmit: widget.reportSubmit,
                  ),
                ),
              CommunityImageView(imageUrl: community.imageUrl, size: 96),
              const SizedBox(height: 16),
              Text(
                community.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (community.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  community.description,
                  style: const TextStyle(color: Color(0xFF475569), height: 1.4),
                ),
              ],
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DetailChip(
                    icon: Icons.people_outline,
                    label: "${community.memberCount} $memberLabel",
                  ),
                  _DetailChip(
                    icon: Icons.lock_open_rounded,
                    label: community.accessMode == CommunityModel.openAccessMode
                        ? "Open"
                        : "Approval required",
                  ),
                  _DetailChip(
                    icon: Icons.category_outlined,
                    label: community.type,
                  ),
                  _DetailChip(
                    icon: Icons.language_outlined,
                    label: community.language,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (deleting)
                const Text(
                  "This Community is no longer accepting members.",
                  style: TextStyle(
                    color: Color(0xFFB91C1C),
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                _buildAction(state, restriction),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAction(
    CommunityPublicAccessState state,
    CommunityRestriction restriction,
  ) {
    if (state.isMember || state.isOwner) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _operationInProgress ? null : _openCommunity,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text("Open Community"),
        ),
      );
    }

    if (restriction.joiningRestricted) {
      return const Text(
        'New members are not being accepted right now.',
        style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
      );
    }

    final community = state.community;
    if (community.accessMode == CommunityModel.openAccessMode) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _operationInProgress ? null : _joinOpenCommunity,
          icon: _operationInProgress
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.group_add_rounded),
          label: const Text("Join Community"),
        ),
      );
    }

    final request = state.request;
    if (request?.status == CommunityAccessRequestModel.pendingStatus) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FilledButton(onPressed: null, child: Text("Request Pending")),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _operationInProgress
                ? null
                : () => _runOperation(
                    () => CommunityService.instance.cancelJoinRequest(
                      community.communityId,
                    ),
                  ),
            child: const Text("Cancel Request"),
          ),
        ],
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _operationInProgress
            ? null
            : () => _runOperation(
                () => CommunityService.instance.requestToJoin(
                  community.communityId,
                ),
              ),
        icon: const Icon(Icons.how_to_reg_rounded),
        label: const Text("Request to Join"),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: const Color(0xFF2563EB)),
        const SizedBox(width: 5),
        Text(label),
      ],
    ),
  );
}

class _DetailsState extends StatelessWidget {
  final String message;

  const _DetailsState({required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [Text(message, textAlign: TextAlign.center)],
      ),
    ),
  );
}
