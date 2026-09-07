import 'package:flutter/material.dart';

import '../../../widgets/gub_screen_background.dart';
import '../../chat/widgets/chat_user_avatar.dart';
import '../../community/moderation/services/community_moderation_service.dart';
import '../../community/moderation/widgets/community_report_dialog.dart';
import '../../community/models/community_ask_model.dart';
import '../../community/leveling/community_level.dart';
import '../../community/widgets/community_active_asks_section.dart';
import '../../community/widgets/community_level_avatar.dart';
import '../../community/widgets/community_profile_asks_section.dart';
import '../../community/services/community_user_xp_cache.dart';
import '../../community/widgets/community_user_xp_scope.dart';
import '../../moderation/blocking/services/user_block_service.dart';
import '../../moderation/gub_reporting/services/gub_user_moderation_service.dart';
import '../models/user_profile_model.dart';
import '../services/user_profile_service.dart';
import 'user_activity_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String? gubId;
  final String? communityId;
  final String? communityName;
  final String userId;
  final Future<UserProfileModel?>? profileFuture;
  final Stream<List<CommunityAskModel>>? activeAsksStream;
  final CommunityUserXpCache? communityUserXpCache;
  final UserBlockService? userBlockService;
  final GubUserModerationService? gubUserModerationService;

  const UserProfileScreen({
    super.key,
    required this.gubId,
    required this.userId,
    this.profileFuture,
    this.activeAsksStream,
    this.communityUserXpCache,
    this.userBlockService,
    this.gubUserModerationService,
  }) : communityId = null,
       communityName = null;

  const UserProfileScreen.community({
    super.key,
    required this.communityId,
    required this.communityName,
    required this.userId,
    this.profileFuture,
    this.activeAsksStream,
    this.communityUserXpCache,
    this.userBlockService,
    this.gubUserModerationService,
  }) : gubId = null;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late final Future<UserProfileModel?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture =
        widget.profileFuture ??
        (widget.communityId == null
            ? UserProfileService.instance.loadProfile(
                gubId: widget.gubId!,
                userId: widget.userId,
              )
            : UserProfileService.instance.loadCommunityProfile(
                communityId: widget.communityId!,
                userId: widget.userId,
              ));
  }

  UserBlockService get _userBlockService =>
      widget.userBlockService ?? UserBlockService.instance;

  GubUserModerationService get _gubUserModerationService =>
      widget.gubUserModerationService ?? GubUserModerationService.instance;

  Future<void> _blockUser(String targetUserId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User?'),
        content: const Text(
          'This user will be added to your blocked users list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      await _userBlockService.blockUser(targetUserId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User blocked.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to block user.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GubScreenBackground(
      variant: GubBackgroundAssignments.profiles,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Profile"),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: SafeArea(
          top: false,
          child: FutureBuilder<UserProfileModel?>(
            future: _profileFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _ProfileMessage(
                  icon: Icons.lock_outline_rounded,
                  message: "Unable to load this profile.",
                );
              }

              final profile = snapshot.data;
              if (profile == null) {
                return _ProfileMessage(
                  icon: Icons.person_off_outlined,
                  message: widget.communityId == null
                      ? "This user is no longer a member of this Gub."
                      : "This user is no longer a member of this Community.",
                );
              }

              Widget content(int? communityXp) => ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                children: [
                  _ProfileHeader(profile: profile, communityXp: communityXp),
                  if (!profile.isCurrentUser) ...[
                    const SizedBox(height: 18),
                    StreamBuilder<bool>(
                      stream: _userBlockService.isUserBlockedStream(
                        profile.userId,
                      ),
                      builder: (context, blockSnapshot) {
                        if (!blockSnapshot.hasData) {
                          return const Center(
                            child: SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        final blocked = blockSnapshot.data!;
                        return Center(
                          child: OutlinedButton.icon(
                            onPressed: blocked
                                ? null
                                : () => _blockUser(profile.userId),
                            icon: Icon(
                              blocked
                                  ? Icons.block_rounded
                                  : Icons.block_outlined,
                            ),
                            label: Text(blocked ? 'Blocked' : 'Block User'),
                          ),
                        );
                      },
                    ),
                  ],
                  if (widget.communityId != null && !profile.isCurrentUser) ...[
                    const SizedBox(height: 18),
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: () => showCommunityReportDialog(
                          context: context,
                          title: 'Report User',
                          onSubmit: (reason, details) =>
                              CommunityModerationService.instance.reportUser(
                                communityId: widget.communityId!,
                                communityName: widget.communityName!,
                                user: profile,
                                reason: reason,
                                details: details,
                              ),
                        ),
                        icon: const Icon(Icons.flag_outlined),
                        label: const Text('Report User'),
                      ),
                    ),
                  ],
                  if (widget.gubId != null && !profile.isCurrentUser) ...[
                    const SizedBox(height: 18),
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: () => showCommunityReportDialog(
                          context: context,
                          title: 'Report User',
                          onSubmit: (reason, details) =>
                              _gubUserModerationService.reportUser(
                                gubId: widget.gubId!,
                                user: profile,
                                reason: reason,
                                details: details,
                              ),
                        ),
                        icon: const Icon(Icons.flag_outlined),
                        label: const Text('Report User'),
                      ),
                    ),
                  ],
                  if (widget.communityId != null) ...[
                    const SizedBox(height: 30),
                    if (widget.activeAsksStream != null)
                      CommunityActiveAsksSection(
                        communityId: widget.communityId!,
                        authorId: widget.userId,
                        asksStream: widget.activeAsksStream,
                      )
                    else
                      CommunityProfileAsksSection(
                        targetUserId: widget.userId,
                        knownCommunities: {
                          widget.communityId!: widget.communityName!,
                        },
                        userXpCache: widget.communityUserXpCache,
                      ),
                  ],
                  if (widget.communityId == null) ...[
                    const SizedBox(height: 30),
                    Text(
                      "Activity",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final category in _activityCategories)
                      _ActivityCategoryCard(
                        category: category,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => UserActivityScreen(
                              gubId: widget.gubId!,
                              userId: widget.userId,
                              type: category.type,
                              initialProfile: profile,
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              );
              if (widget.communityId == null) return content(null);
              return CommunityUserXpScope(
                cache: widget.communityUserXpCache,
                userIds: {profile.userId},
                builder: (context, xpByUserId) =>
                    content(xpByUserId[profile.userId]),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserProfileModel profile;
  final int? communityXp;

  const _ProfileHeader({required this.profile, required this.communityXp});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (communityXp == null)
          ChatUserAvatar(
            displayName: profile.displayName,
            userId: profile.userId,
            photoUrl: profile.photoUrl,
            radius: 42,
          )
        else
          CommunityLevelAvatar(
            displayName: profile.displayName,
            userId: profile.userId,
            photoUrl: profile.photoUrl,
            radius: 42,
            xp: communityXp!,
          ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                profile.displayName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (profile.isCurrentUser) ...[
              const SizedBox(width: 8),
              const Chip(
                visualDensity: VisualDensity.compact,
                label: Text("You"),
              ),
            ],
          ],
        ),
        if (profile.role != null) ...[
          const SizedBox(height: 6),
          Text(
            profile.role!,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
          ),
        ],
        if (communityXp != null) ...[
          const SizedBox(height: 18),
          _CommunityLevelCard(level: CommunityLevel.fromXp(communityXp!)),
        ],
      ],
    );
  }
}

class _CommunityLevelCard extends StatelessWidget {
  const _CommunityLevelCard({required this.level});

  final CommunityLevel level;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final barText = level.isMaxLevel
        ? '${CommunityLevel.maxXp}+ XP'
        : '${level.xpWithinCurrentLevel} / '
              '${level.xpRequiredForNextLevel} XP';
    final detail = level.isMaxLevel
        ? 'Max level'
        : '${level.percentage}% to Level ${level.nextLevel}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'Level ${level.level}',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (level.recognition != null) ...[
            const SizedBox(height: 3),
            Text(
              level.recognition!,
              style: textTheme.bodyMedium?.copyWith(color: Colors.black54),
            ),
          ],
          const SizedBox(height: 10),
          const SizedBox(height: 12),
          SizedBox(
            height: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.primary),
                  ),
                  child: const SizedBox.expand(),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: level.progress,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                Text(
                  barText,
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(child: Text(detail, style: textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _ActivityCategoryCard extends StatelessWidget {
  final _ActivityCategory category;
  final VoidCallback onTap;

  const _ActivityCategoryCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(category.icon, color: const Color(0xFF2563EB)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      category.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _ProfileMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: const Color(0xFF64748B)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ActivityCategory {
  final UserActivityType type;
  final String title;
  final String description;
  final IconData icon;

  const _ActivityCategory({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
  });
}

const _activityCategories = [
  _ActivityCategory(
    type: UserActivityType.tasks,
    title: "Tasks",
    description: "Created, assigned and completed tasks",
    icon: Icons.task_alt_rounded,
  ),
  _ActivityCategory(
    type: UserActivityType.proposals,
    title: "Proposals",
    description: "Created proposals",
    icon: Icons.how_to_vote_outlined,
  ),
  _ActivityCategory(
    type: UserActivityType.events,
    title: "Events",
    description: "Created events",
    icon: Icons.event_outlined,
  ),
  _ActivityCategory(
    type: UserActivityType.sharedBudget,
    title: "Shared budget",
    description: "Created Shared Budgets",
    icon: Icons.savings_outlined,
  ),
];
