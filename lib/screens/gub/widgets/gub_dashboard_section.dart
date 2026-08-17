import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/models/creation_availability.dart';
import '../../../core/navigation/creation_gate.dart';
import '../../../modules/shared_budget/models/shared_budget_model.dart';
import '../../../modules/shared_budget/screens/shared_budget_members_screen.dart';
import '../../../modules/shared_budget/screens/shared_budget_screen.dart';
import '../../../modules/shared_budget/widgets/delete_shared_budget_dialog.dart';
import '../../../modules/shared_budget/widgets/shared_budget_empty_card.dart';
import '../../../modules/gub_calendar/screens/gub_calendar_screen.dart';
import '../../../modules/proposals/screens/create_proposal_screen.dart';
import '../../../modules/proposals/screens/proposals_screen.dart';
import '../../../modules/proposals/models/proposal_model.dart';
import '../../../modules/tasks/models/task_model.dart';
import '../../../modules/tasks/screens/task_details_screen.dart';
import '../../../modules/tasks/screens/tasks_screen.dart';
import '../../../modules/organized_events/screens/gub_events_screen.dart';
import '../../../modules/organized_events/services/gub_event_service.dart';
import '../../../services/gub_dashboard_service.dart';

class GubDashboardSection extends StatefulWidget {
  final String gubId;
  final String ownerId;
  final int memberCount;

  const GubDashboardSection({
    super.key,
    required this.gubId,
    required this.ownerId,
    required this.memberCount,
  });

  @visibleForTesting
  static Widget proposalDestination({
    required ProposalModel? activeProposal,
    required String gubId,
    required int memberCount,
  }) => activeProposal == null
      ? CreateProposalScreen(gubId: gubId, memberCount: memberCount)
      : ProposalsScreen(gubId: gubId, memberCount: memberCount);

  @override
  State<GubDashboardSection> createState() => _GubDashboardSectionState();
}

class _GubDashboardSectionState extends State<GubDashboardSection> {
  late Stream<GubDashboardSummary> _summaryStream;

  bool get _isOwner => FirebaseAuth.instance.currentUser?.uid == widget.ownerId;

  @override
  void initState() {
    super.initState();
    _summaryStream = _createSummaryStream();
  }

  @override
  void didUpdateWidget(covariant GubDashboardSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gubId != widget.gubId) {
      _summaryStream = _createSummaryStream();
    }
  }

  Stream<GubDashboardSummary> _createSummaryStream() {
    return GubDashboardService.instance.summaryStream(widget.gubId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GubDashboardSummary>(
      stream: _summaryStream,
      initialData: const GubDashboardSummary.loading(),
      builder: (context, snapshot) {
        final summary = snapshot.data ?? const GubDashboardSummary.loading();

        return Column(
          children: [
            _TodayCard(
              taskText: _taskText(summary, compact: false),
              myTaskText: _myTaskText(summary),
              proposalText: _proposalText(summary, compact: false),
              eventText: _nextEventText(summary),
              onTasksTap: _openTasks,
              onMyTaskTap: () => _showMyActiveTask(summary),
              onProposalsTap: () => _openProposals(summary.activeProposal),
              onCalendarTap: _openCalendar,
            ),
            const SizedBox(height: 12),
            StreamBuilder<int>(
              stream: GubEventService.instance.activeCountStream(widget.gubId),
              builder: (context, eventSnapshot) => _ModuleGrid(
                taskText: _taskText(summary, compact: true),
                proposalText: _proposalText(summary, compact: true),
                calendarText: _calendarText(summary),
                eventText: _activeEventText(eventSnapshot.data ?? 0),
                onTasksTap: _openTasks,
                onProposalsTap: () => _openProposals(summary.activeProposal),
                onCalendarTap: _openCalendar,
                onEventTap: _openEvents,
              ),
            ),
            const SizedBox(height: 12),
            _SharedBudgetSummaryCard(
              summary: summary,
              gubId: widget.gubId,
              isOwner: _isOwner,
              onTap: summary.latestBudget == null
                  ? _openBudgets
                  : () => _openBudget(summary.latestBudget!),
              onArchive: _openBudgetArchive,
              onActiveBudgets: _openActiveBudgets,
            ),
          ],
        );
      },
    );
  }

  String _taskText(GubDashboardSummary summary, {required bool compact}) {
    if (!summary.tasksLoaded) return "Loading...";
    if (summary.tasksFailed) return "Unable to load tasks";

    final count = summary.activeTaskCount;
    if (count == 0) return "No active tasks";
    if (compact) return "$count active";
    return "$count active task${count == 1 ? "" : "s"}";
  }

  String _myTaskText(GubDashboardSummary summary) {
    if (!summary.tasksLoaded || (!_isOwner && !summary.taskCooldownLoaded)) {
      return "Loading...";
    }
    if (summary.tasksFailed || (!_isOwner && summary.taskCooldownFailed)) {
      return "Unable to load task availability";
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return "Unavailable";
    final assignedCount = summary.activeTasks
        .where((task) => task.assignedUserId == userId)
        .length;
    if (_isOwner) return "$assignedCount assigned to you · Unlimited";
    final hasCreatedTask = summary.activeTasks.any(
      (task) => task.creatorId == userId,
    );
    final cooldownActive = summary.taskCreationCooldown?.isActive == true;
    final slotStatus = hasCreatedTask
        ? "In use"
        : cooldownActive
        ? "Cooldown"
        : "Available";
    return "$assignedCount assigned to you · $slotStatus";
  }

  Future<void> _showMyActiveTask(GubDashboardSummary summary) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null ||
        !summary.tasksLoaded ||
        (!_isOwner && !summary.taskCooldownLoaded)) {
      return;
    }

    final assignedTasks = summary.activeTasks
        .where((task) => task.assignedUserId == userId)
        .toList(growable: false);
    final createdTasks = summary.activeTasks
        .where((task) => task.creatorId == userId)
        .toList(growable: false);
    final relevantTasks = <String, TaskModel>{
      for (final task in assignedTasks) task.taskId: task,
      for (final task in createdTasks) task.taskId: task,
    }.values.toList(growable: false);
    final cooldown = summary.taskCreationCooldown;
    final cooldownActive = cooldown?.isActive == true;
    final availabilityUnknown =
        summary.tasksFailed || (!_isOwner && summary.taskCooldownFailed);
    final slotUnavailable =
        !_isOwner &&
        (createdTasks.isNotEmpty || cooldownActive || availabilityUnknown);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          children: [
            Text(
              "My active task",
              style: Theme.of(
                sheetContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            Text("Active tasks assigned to you: ${assignedTasks.length}"),
            Text("Active tasks created by you: ${createdTasks.length}"),
            if (_isOwner)
              const Text("Task creation: Unlimited")
            else ...[
              Text("Available creation slots: ${slotUnavailable ? 0 : 1}/1"),
              Text("Unavailable creation slots: ${slotUnavailable ? 1 : 0}/1"),
            ],
            if (!_isOwner && createdTasks.isNotEmpty)
              const Text("Reason: You already have an active task."),
            if (!_isOwner && createdTasks.isEmpty && cooldownActive) ...[
              const Text("Reason: Cooldown after a deleted task."),
              Text(
                "Time remaining: "
                "${formatCooldownRemaining(cooldown!.remaining)}",
              ),
            ],
            if (!_isOwner && availabilityUnknown)
              const Text("Reason: Availability could not be verified."),
            if (relevantTasks.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                "Active tasks",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              for (final task in relevantTasks)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(task.title),
                  subtitle: Text(
                    task.creatorId == userId
                        ? "Created by you"
                        : "Assigned to you",
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TaskDetailsScreen(
                          gubId: task.gubId,
                          taskId: task.taskId,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _proposalText(GubDashboardSummary summary, {required bool compact}) {
    if (!summary.proposalsLoaded) return "Loading...";
    if (summary.proposalsFailed) return "Unable to load proposals";

    final count = summary.pendingProposalCount;
    if (count == 0) {
      return compact ? "No pending votes" : "No proposals to vote";
    }
    if (compact) return "Vote now · $count";
    return "$count proposal${count == 1 ? "" : "s"} to vote";
  }

  String _nextEventText(GubDashboardSummary summary) {
    if (!summary.eventsLoaded) return "Loading...";
    if (summary.eventsFailed) return "Unable to load events";

    final event = summary.nextEvent;
    if (event == null) return "No upcoming events";

    final date = event.eventDate.toDate();
    final time =
        "${date.hour.toString().padLeft(2, "0")}:"
        "${date.minute.toString().padLeft(2, "0")}";
    return "${event.title} · $time";
  }

  String _calendarText(GubDashboardSummary summary) {
    if (!summary.eventsLoaded) return "Loading...";
    if (summary.eventsFailed) return "Unable to load events";

    final count = summary.upcomingEventCount;
    if (count == 0) return "No upcoming events";
    return "$count upcoming";
  }

  String _activeEventText(int count) {
    if (count == 0) return 'No active events';
    return '$count active event${count == 1 ? '' : 's'}';
  }

  void _openTasks() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => TasksScreen(gubId: widget.gubId)));
  }

  Future<void> _openProposals(ProposalModel? activeProposal) async {
    if (activeProposal == null) {
      final allowed = await CreationGate.ensureAvailable(
        context: context,
        gubId: widget.gubId,
        moduleType: CreationModuleType.proposal,
      );
      if (!allowed || !mounted) return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GubDashboardSection.proposalDestination(
          activeProposal: activeProposal,
          gubId: widget.gubId,
          memberCount: widget.memberCount,
        ),
      ),
    );
  }

  void _openCalendar() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            GubCalendarScreen(gubId: widget.gubId, ownerId: widget.ownerId),
      ),
    );
  }

  void _openEvents() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GubEventsScreen(gubId: widget.gubId)),
    );
  }

  void _openBudgets() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            SharedBudgetScreen(gubId: widget.gubId, canCreateBudget: _isOwner),
      ),
    );
  }

  void _openBudget(SharedBudgetModel budget) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SharedBudgetMembersScreen(
          gubId: widget.gubId,
          sharedBudgetId: budget.sharedBudgetId,
          ownerId: widget.ownerId,
        ),
      ),
    );
  }

  void _openBudgetArchive() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SharedBudgetScreen(
          gubId: widget.gubId,
          initialTab: SharedBudgetInitialTab.archive,
          canCreateBudget: _isOwner,
        ),
      ),
    );
  }

  void _openActiveBudgets() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SharedBudgetScreen(
          gubId: widget.gubId,
          initialTab: SharedBudgetInitialTab.active,
          canCreateBudget: _isOwner,
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final String taskText;
  final String myTaskText;
  final String proposalText;
  final String? eventText;
  final VoidCallback onTasksTap;
  final VoidCallback onMyTaskTap;
  final VoidCallback onProposalsTap;
  final VoidCallback? onCalendarTap;

  const _TodayCard({
    required this.taskText,
    required this.myTaskText,
    required this.proposalText,
    required this.eventText,
    required this.onTasksTap,
    required this.onMyTaskTap,
    required this.onProposalsTap,
    required this.onCalendarTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Today in the Gub",
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            _TodayRow(
              icon: Icons.checklist_rounded,
              iconColor: const Color(0xFF2563EB),
              iconBackground: const Color(0xFFDBEAFE),
              text: taskText,
              onTap: onTasksTap,
            ),
            const Divider(height: 1, indent: 52),
            _TodayRow(
              icon: Icons.person_search_rounded,
              iconColor: const Color(0xFF7C3AED),
              iconBackground: const Color(0xFFEDE9FE),
              title: "My active task",
              text: myTaskText,
              onTap: onMyTaskTap,
            ),
            const Divider(height: 1, indent: 52),
            _TodayRow(
              icon: Icons.how_to_vote_outlined,
              iconColor: const Color(0xFF16A34A),
              iconBackground: const Color(0xFFDCFCE7),
              text: proposalText,
              onTap: onProposalsTap,
            ),
            if (eventText != null) ...[
              const Divider(height: 1, indent: 52),
              _TodayRow(
                icon: Icons.event_outlined,
                iconColor: const Color(0xFFEA580C),
                iconBackground: const Color(0xFFFFEDD5),
                text: eventText!,
                onTap: onCalendarTap,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TodayRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String text;
  final String? title;
  final VoidCallback? onTap;

  const _TodayRow({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.text,
    this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 58),
        child: Row(
          children: [
            _PastelIcon(
              icon: icon,
              color: iconColor,
              backgroundColor: iconBackground,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: onTap == null
                          ? const Color(0xFF94A3B8)
                          : title == null
                          ? const Color(0xFF1E293B)
                          : const Color(0xFF64748B),
                      fontSize: title == null ? 15 : 13,
                      fontWeight: title == null
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: onTap == null
                  ? const Color(0xFFCBD5E1)
                  : const Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleGrid extends StatelessWidget {
  final String taskText;
  final String calendarText;
  final String proposalText;
  final String eventText;
  final VoidCallback onTasksTap;
  final VoidCallback onCalendarTap;
  final VoidCallback onProposalsTap;
  final VoidCallback onEventTap;

  const _ModuleGrid({
    required this.taskText,
    required this.calendarText,
    required this.proposalText,
    required this.eventText,
    required this.onTasksTap,
    required this.onCalendarTap,
    required this.onProposalsTap,
    required this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _ModuleCard(
        icon: Icons.task_alt_outlined,
        iconColor: const Color(0xFF2563EB),
        iconBackground: const Color(0xFFDBEAFE),
        title: "Tasks",
        subtitle: taskText,
        onTap: onTasksTap,
      ),
      _ModuleCard(
        icon: Icons.calendar_month_outlined,
        iconColor: const Color(0xFF2563EB),
        iconBackground: const Color(0xFFDBEAFE),
        title: "Calendar",
        subtitle: calendarText,
        onTap: onCalendarTap,
      ),
      _ModuleCard(
        icon: Icons.how_to_vote_outlined,
        iconColor: const Color(0xFF16A34A),
        iconBackground: const Color(0xFFDCFCE7),
        title: "Proposals",
        subtitle: proposalText,
        onTap: onProposalsTap,
      ),
      _ModuleCard(
        icon: Icons.event_outlined,
        iconColor: const Color(0xFFEA580C),
        iconBackground: const Color(0xFFFFEDD5),
        title: "Event",
        subtitle: eventText,
        onTap: onEventTap,
      ),
    ];

    return Column(
      children: [
        for (var index = 0; index < cards.length; index += 2) ...[
          if (index > 0) const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cards[index]),
                if (index + 1 < cards.length) ...[
                  const SizedBox(width: 12),
                  Expanded(child: cards[index + 1]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ModuleCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _PastelIcon(
                    icon: icon,
                    color: iconColor,
                    backgroundColor: iconBackground,
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: onTap == null
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF64748B),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: onTap == null ? const Color(0xFF94A3B8) : iconColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SharedBudgetSummaryCard extends StatelessWidget {
  final GubDashboardSummary summary;
  final String gubId;
  final bool isOwner;
  final VoidCallback onTap;
  final VoidCallback onArchive;
  final VoidCallback onActiveBudgets;

  const _SharedBudgetSummaryCard({
    required this.summary,
    required this.gubId,
    required this.isOwner,
    required this.onTap,
    required this.onArchive,
    required this.onActiveBudgets,
  });

  @override
  Widget build(BuildContext context) {
    final budget = summary.latestBudget;
    final canDelete =
        budget != null &&
        FirebaseAuth.instance.currentUser?.uid == budget.ownerId &&
        !budget.isCompleted;
    final progress = budget == null || budget.targetAmount <= 0
        ? 0.0
        : budget.isCompleted
        ? 1.0
        : (budget.currentAmount / budget.targetAmount).clamp(0.0, 1.0);
    final percentage = (progress * 100).round();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        child: Column(
          children: [
            Row(
              children: [
                const _PastelIcon(
                  icon: Icons.track_changes_rounded,
                  color: Color(0xFF2563EB),
                  backgroundColor: Color(0xFFDBEAFE),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Shared Budget",
                    style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (canDelete)
                  PopupMenuButton<String>(
                    tooltip: "Shared Budget actions",
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    onSelected: (value) {
                      if (value == "delete") {
                        showDeleteSharedBudgetDialog(
                          context: context,
                          gubId: gubId,
                          sharedBudgetId: budget.sharedBudgetId,
                        );
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: "delete",
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red),
                            SizedBox(width: 10),
                            Text("Delete"),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (summary.budgetsFailed)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: Text("Unable to load Shared Budgets.")),
              )
            else if (!summary.budgetsLoaded)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (budget == null)
              SharedBudgetEmptyCard(isOwner: isOwner, gubId: gubId)
            else ...[
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              budget.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF1E293B),
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (budget.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                budget.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                            const SizedBox(height: 13),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 9,
                                      backgroundColor: const Color(0xFFE2E8F0),
                                      color: const Color(0xFF2563EB),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  "$percentage%",
                                  style: const TextStyle(
                                    color: Color(0xFF2563EB),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),
              ),
              if (summary.activeBudgetCount > 1) ...[
                const Divider(height: 24),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onActiveBudgets,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.view_list_rounded,
                          size: 21,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _remainingBudgetText(summary.activeBudgetCount - 1),
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: onArchive,
                  icon: const Icon(Icons.archive_outlined, size: 19),
                  label: const Text("Archive"),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _remainingBudgetText(int remainingCount) {
    return remainingCount == 1
        ? "1 more active Shared Budget"
        : "$remainingCount more active Shared Budgets";
  }
}

class _PastelIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const _PastelIcon({
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: 22),
    );
  }
}
