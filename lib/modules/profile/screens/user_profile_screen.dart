import 'package:flutter/material.dart';

import '../../chat/widgets/chat_user_avatar.dart';
import '../../tasks/screens/task_details_screen.dart';
import '../models/user_profile_model.dart';
import '../services/user_profile_service.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FD),
      appBar: AppBar(title: const Text("Profile")),
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

            return StreamBuilder<List<UserTaskActivity>>(
              stream: UserProfileService.instance.taskActivityStream(
                gubId: widget.gubId,
                userId: widget.userId,
              ),
              builder: (context, activitySnapshot) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  children: [
                    _ProfileHeader(profile: profile),
                    const SizedBox(height: 30),
                    Text(
                      "Recent activity",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (activitySnapshot.connectionState ==
                        ConnectionState.waiting)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (activitySnapshot.hasError)
                      const _InlineMessage(
                        message: "Unable to load recent activity.",
                      )
                    else if (activitySnapshot.data?.isEmpty ?? true)
                      const _InlineMessage(message: "No activity yet")
                    else
                      for (final activity in activitySnapshot.data!)
                        _ActivityCard(
                          activity: activity,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TaskDetailsScreen(
                                gubId: activity.task.gubId,
                                taskId: activity.task.taskId,
                              ),
                            ),
                          ),
                        ),
                  ],
                );
              },
            );
          },
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

class _ActivityCard extends StatelessWidget {
  final UserTaskActivity activity;
  final VoidCallback onTap;

  const _ActivityCard({required this.activity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final presentation = _presentationFor(activity.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: presentation.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(presentation.icon, color: presentation.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      presentation.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      activity.task.title.isEmpty
                          ? "Untitled task"
                          : activity.task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        Text(
                          _formatDate(activity.occurredAt.toDate()),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.black54),
                        ),
                        Text(
                          activity.task.status,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFF2563EB),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }

  _ActivityPresentation _presentationFor(UserTaskActivityType type) {
    return switch (type) {
      UserTaskActivityType.created => const _ActivityPresentation(
        label: "Created a task",
        icon: Icons.add_task_rounded,
        color: Color(0xFF2563EB),
      ),
      UserTaskActivityType.assigned => const _ActivityPresentation(
        label: "Was assigned a task",
        icon: Icons.assignment_ind_outlined,
        color: Color(0xFF7C3AED),
      ),
      UserTaskActivityType.completed => const _ActivityPresentation(
        label: "Completed a task",
        icon: Icons.task_alt_rounded,
        color: Color(0xFF059669),
      ),
    };
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, "0");
    final month = date.month.toString().padLeft(2, "0");
    return "$day/$month/${date.year}";
  }
}

class _ActivityPresentation {
  final String label;
  final IconData icon;
  final Color color;

  const _ActivityPresentation({
    required this.label,
    required this.icon,
    required this.color,
  });
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

class _InlineMessage extends StatelessWidget {
  final String message;

  const _InlineMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF64748B)),
        ),
      ),
    );
  }
}
