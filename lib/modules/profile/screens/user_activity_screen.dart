import 'package:flutter/material.dart';

import '../../../widgets/gub_screen_background.dart';
import '../../shared_budget/screens/shared_budget_members_screen.dart';
import '../../proposals/screens/proposal_details_screen.dart';
import '../../tasks/screens/task_details_screen.dart';
import '../models/user_profile_model.dart';
import '../services/user_profile_service.dart';

class UserActivityScreen extends StatefulWidget {
  final String gubId;
  final String userId;
  final UserActivityType type;
  final UserProfileModel? initialProfile;

  const UserActivityScreen({
    super.key,
    required this.gubId,
    required this.userId,
    required this.type,
    this.initialProfile,
  });

  @override
  State<UserActivityScreen> createState() => _UserActivityScreenState();
}

class _UserActivityScreenState extends State<UserActivityScreen> {
  Future<UserProfileModel?>? _profileFuture;
  late Stream<List<UserActivityEntry>> _activityStream;

  @override
  void initState() {
    super.initState();
    _initializeLoads();
  }

  @override
  void didUpdateWidget(covariant UserActivityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gubId != widget.gubId ||
        oldWidget.userId != widget.userId ||
        oldWidget.type != widget.type ||
        oldWidget.initialProfile != widget.initialProfile) {
      _initializeLoads();
    }
  }

  void _initializeLoads() {
    _profileFuture = widget.initialProfile == null
        ? UserProfileService.instance.loadProfile(
            gubId: widget.gubId,
            userId: widget.userId,
          )
        : null;
    _activityStream = UserProfileService.instance.activityStream(
      gubId: widget.gubId,
      userId: widget.userId,
      type: widget.type,
    );
  }

  @override
  Widget build(BuildContext context) {
    final presentation = _presentationFor(widget.type);

    return GubScreenBackground(
      variant: _backgroundFor(widget.type),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(presentation.title),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: SafeArea(
          top: false,
          child: widget.initialProfile != null
              ? _buildActivity()
              : FutureBuilder<UserProfileModel?>(
                  future: _profileFuture,
                  builder: (context, profileSnapshot) {
                    if (profileSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (profileSnapshot.hasError ||
                        profileSnapshot.data == null) {
                      return const _ActivityMessage(
                        icon: Icons.lock_outline_rounded,
                        message: "Unable to load this activity.",
                      );
                    }
                    return _buildActivity();
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildActivity() {
    return StreamBuilder<List<UserActivityEntry>>(
      stream: _activityStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const _ActivityMessage(
            icon: Icons.error_outline_rounded,
            message: "Unable to load this activity.",
          );
        }

        final activities = snapshot.data ?? const [];
        if (activities.isEmpty) {
          return const _ActivityMessage(
            icon: Icons.inbox_outlined,
            message: "No activity available yet",
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          itemCount: activities.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final activity = activities[index];
            return _ActivityCard(
              activity: activity,
              onTap: _canOpen(activity) ? () => _openActivity(activity) : null,
            );
          },
        );
      },
    );
  }

  bool _canOpen(UserActivityEntry activity) {
    return activity.task != null ||
        activity.proposal != null ||
        activity.sharedBudget != null;
  }

  void _openActivity(UserActivityEntry activity) {
    final task = activity.task;
    final proposal = activity.proposal;
    final sharedBudget = activity.sharedBudget;

    if (task != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              TaskDetailsScreen(gubId: task.gubId, taskId: task.taskId),
        ),
      );
    } else if (proposal != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProposalDetailsScreen(proposal: proposal),
        ),
      );
    } else if (sharedBudget != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SharedBudgetMembersScreen(
            gubId: widget.gubId,
            sharedBudgetId: sharedBudget.sharedBudgetId,
            ownerId: sharedBudget.ownerId,
          ),
        ),
      );
    }
  }
}

class _ActivityCard extends StatelessWidget {
  final UserActivityEntry activity;
  final VoidCallback? onTap;

  const _ActivityCard({required this.activity, this.onTap});

  @override
  Widget build(BuildContext context) {
    final presentation = _entryPresentation(activity.kind);
    final sourceLabel = activity.task?.sourceType.trim().toLowerCase() == "chat"
        ? "From chat"
        : null;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
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
                      activity.title.trim().isEmpty
                          ? presentation.untitledLabel
                          : activity.title,
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
                              ?.copyWith(color: const Color(0xFF64748B)),
                        ),
                        Text(
                          activity.status,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFF2563EB),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        if (sourceLabel != null)
                          Text(
                            sourceLabel,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: const Color(0xFF7C3AED),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _ActivityMessage({required this.icon, required this.message});

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

({String title, IconData icon}) _presentationFor(UserActivityType type) {
  return switch (type) {
    UserActivityType.tasks => (title: "Tasks", icon: Icons.task_alt_rounded),
    UserActivityType.proposals => (
      title: "Proposals",
      icon: Icons.how_to_vote_outlined,
    ),
    UserActivityType.events => (title: "Events", icon: Icons.event_outlined),
    UserActivityType.sharedBudget => (
      title: "Shared budget",
      icon: Icons.savings_outlined,
    ),
  };
}

GubBackgroundVariant _backgroundFor(UserActivityType type) {
  return switch (type) {
    UserActivityType.tasks => GubBackgroundAssignments.tasks,
    UserActivityType.proposals => GubBackgroundAssignments.proposals,
    UserActivityType.events => GubBackgroundAssignments.events,
    UserActivityType.sharedBudget => GubBackgroundAssignments.sharedBudget,
  };
}

({String label, String untitledLabel, IconData icon, Color color})
_entryPresentation(UserActivityKind kind) {
  return switch (kind) {
    UserActivityKind.taskCreated => (
      label: "Created a task",
      untitledLabel: "Untitled task",
      icon: Icons.add_task_rounded,
      color: const Color(0xFF2563EB),
    ),
    UserActivityKind.taskAssigned => (
      label: "Was assigned a task",
      untitledLabel: "Untitled task",
      icon: Icons.assignment_ind_outlined,
      color: const Color(0xFF7C3AED),
    ),
    UserActivityKind.taskCompleted => (
      label: "Completed a task",
      untitledLabel: "Untitled task",
      icon: Icons.task_alt_rounded,
      color: const Color(0xFF059669),
    ),
    UserActivityKind.proposalCreated => (
      label: "Created a proposal",
      untitledLabel: "Untitled proposal",
      icon: Icons.how_to_vote_outlined,
      color: const Color(0xFF2563EB),
    ),
    UserActivityKind.eventCreated => (
      label: "Created an event",
      untitledLabel: "Untitled event",
      icon: Icons.event_outlined,
      color: const Color(0xFF0891B2),
    ),
    UserActivityKind.sharedBudgetCreated => (
      label: "Created a Shared Budget",
      untitledLabel: "Untitled Shared Budget",
      icon: Icons.savings_outlined,
      color: const Color(0xFF059669),
    ),
  };
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, "0");
  final month = date.month.toString().padLeft(2, "0");
  return "$day/$month/${date.year}";
}
