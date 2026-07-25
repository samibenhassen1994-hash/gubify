import 'package:flutter/material.dart';

import '../../../widgets/gub_screen_background.dart';
import '../../chat/widgets/chat_user_avatar.dart';
import '../models/user_profile_model.dart';
import '../services/user_profile_service.dart';
import 'user_activity_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String gubId;
  final String userId;

  const UserProfileScreen({
    super.key,
    required this.gubId,
    required this.userId,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late final Future<UserProfileModel?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = UserProfileService.instance.loadProfile(
      gubId: widget.gubId,
      userId: widget.userId,
    );
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
                return const _ProfileMessage(
                  icon: Icons.lock_outline_rounded,
                  message: "Unable to load this profile.",
                );
              }

              final profile = snapshot.data;
              if (profile == null) {
                return const _ProfileMessage(
                  icon: Icons.person_off_outlined,
                  message: "This user is no longer a member of this Gub.",
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                children: [
                  _ProfileHeader(profile: profile),
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
                            gubId: widget.gubId,
                            userId: widget.userId,
                            type: category.type,
                          ),
                        ),
                      ),
                    ),
                ],
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

  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ChatUserAvatar(
          displayName: profile.displayName,
          userId: profile.userId,
          photoUrl: profile.photoUrl,
          radius: 42,
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
      ],
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
    type: UserActivityType.groupGoals,
    title: "Group goals",
    description: "Activity is not attributable yet",
    icon: Icons.flag_outlined,
  ),
  _ActivityCategory(
    type: UserActivityType.sharedBudget,
    title: "Shared budget",
    description: "Created Shared Budgets",
    icon: Icons.savings_outlined,
  ),
];
