import 'dart:async';

import '../modules/shared_budget/models/shared_budget_model.dart';
import '../modules/shared_budget/services/shared_budget_service.dart';
import '../modules/gub_calendar/models/event_model.dart';
import '../modules/gub_calendar/services/event_service.dart';
import '../modules/proposals/models/proposal_model.dart';
import '../modules/proposals/services/proposal_service.dart';
import '../modules/tasks/models/task_model.dart';
import '../modules/tasks/services/task_service.dart';

class GubDashboardSummary {
  final bool tasksLoaded;
  final bool proposalsLoaded;
  final bool eventsLoaded;
  final bool budgetsLoaded;
  final bool tasksFailed;
  final bool proposalsFailed;
  final bool eventsFailed;
  final bool budgetsFailed;
  final int activeTaskCount;
  final int pendingProposalCount;
  final ProposalModel? activeProposal;
  final int upcomingEventCount;
  final EventModel? nextEvent;
  final int activeBudgetCount;
  final SharedBudgetModel? latestBudget;

  const GubDashboardSummary({
    required this.tasksLoaded,
    required this.proposalsLoaded,
    required this.eventsLoaded,
    required this.budgetsLoaded,
    required this.tasksFailed,
    required this.proposalsFailed,
    required this.eventsFailed,
    required this.budgetsFailed,
    required this.activeTaskCount,
    required this.pendingProposalCount,
    required this.activeProposal,
    required this.upcomingEventCount,
    required this.nextEvent,
    required this.activeBudgetCount,
    required this.latestBudget,
  });

  const GubDashboardSummary.loading()
    : tasksLoaded = false,
      proposalsLoaded = false,
      eventsLoaded = false,
      budgetsLoaded = false,
      tasksFailed = false,
      proposalsFailed = false,
      eventsFailed = false,
      budgetsFailed = false,
      activeTaskCount = 0,
      pendingProposalCount = 0,
      activeProposal = null,
      upcomingEventCount = 0,
      nextEvent = null,
      activeBudgetCount = 0,
      latestBudget = null;
}

class GubDashboardService {
  GubDashboardService._();

  static final GubDashboardService instance = GubDashboardService._();

  Stream<GubDashboardSummary> summaryStream(String gubId) {
    late final StreamController<GubDashboardSummary> controller;

    StreamSubscription<List<TaskModel>>? taskSubscription;
    StreamSubscription<List<ProposalModel>>? proposalSubscription;
    StreamSubscription<List<EventModel>>? eventSubscription;
    StreamSubscription<List<SharedBudgetModel>>? budgetSubscription;

    var summary = const GubDashboardSummary.loading();

    void emit(GubDashboardSummary nextSummary) {
      summary = nextSummary;
      if (!controller.isClosed) controller.add(summary);
    }

    void update({
      bool? tasksLoaded,
      bool? proposalsLoaded,
      bool? eventsLoaded,
      bool? budgetsLoaded,
      bool? tasksFailed,
      bool? proposalsFailed,
      bool? eventsFailed,
      bool? budgetsFailed,
      int? activeTaskCount,
      int? pendingProposalCount,
      ProposalModel? activeProposal,
      bool clearActiveProposal = false,
      int? upcomingEventCount,
      EventModel? nextEvent,
      bool clearNextEvent = false,
      int? activeBudgetCount,
      SharedBudgetModel? latestBudget,
      bool clearLatestBudget = false,
    }) {
      emit(
        GubDashboardSummary(
          tasksLoaded: tasksLoaded ?? summary.tasksLoaded,
          proposalsLoaded: proposalsLoaded ?? summary.proposalsLoaded,
          eventsLoaded: eventsLoaded ?? summary.eventsLoaded,
          budgetsLoaded: budgetsLoaded ?? summary.budgetsLoaded,
          tasksFailed: tasksFailed ?? summary.tasksFailed,
          proposalsFailed: proposalsFailed ?? summary.proposalsFailed,
          eventsFailed: eventsFailed ?? summary.eventsFailed,
          budgetsFailed: budgetsFailed ?? summary.budgetsFailed,
          activeTaskCount: activeTaskCount ?? summary.activeTaskCount,
          pendingProposalCount:
              pendingProposalCount ?? summary.pendingProposalCount,
          activeProposal: clearActiveProposal
              ? null
              : activeProposal ?? summary.activeProposal,
          upcomingEventCount: upcomingEventCount ?? summary.upcomingEventCount,
          nextEvent: clearNextEvent ? null : nextEvent ?? summary.nextEvent,
          activeBudgetCount: activeBudgetCount ?? summary.activeBudgetCount,
          latestBudget: clearLatestBudget
              ? null
              : latestBudget ?? summary.latestBudget,
        ),
      );
    }

    Future<void> cancelSubscriptions() async {
      await Future.wait([
        if (taskSubscription != null) taskSubscription!.cancel(),
        if (proposalSubscription != null) proposalSubscription!.cancel(),
        if (eventSubscription != null) eventSubscription!.cancel(),
        if (budgetSubscription != null) budgetSubscription!.cancel(),
      ]);
    }

    controller = StreamController<GubDashboardSummary>(
      onListen: () {
        controller.add(summary);

        taskSubscription = TaskService.instance
            .tasksStream(gubId)
            .listen(
              (tasks) {
                update(
                  tasksLoaded: true,
                  tasksFailed: false,
                  activeTaskCount: tasks
                      .where(
                        (task) => task.status == "active" && !task.archived,
                      )
                      .length,
                );
              },
              onError: (Object _) {
                update(tasksLoaded: true, tasksFailed: true);
              },
            );

        proposalSubscription = ProposalService.instance
            .proposalsStream(gubId)
            .listen(
              (proposals) {
                ProposalModel? activeProposal;
                for (final proposal in proposals) {
                  if (proposal.status == "voting") {
                    activeProposal = proposal;
                    break;
                  }
                }

                update(
                  proposalsLoaded: true,
                  proposalsFailed: false,
                  pendingProposalCount: activeProposal == null
                      ? 0
                      : proposals
                            .where((proposal) => proposal.status == "voting")
                            .length,
                  activeProposal: activeProposal,
                  clearActiveProposal: activeProposal == null,
                );
              },
              onError: (Object _) {
                update(
                  proposalsLoaded: true,
                  proposalsFailed: true,
                  pendingProposalCount: 0,
                  clearActiveProposal: true,
                );
              },
            );

        eventSubscription = EventService.instance
            .eventsStream(gubId)
            .listen(
              (events) {
                update(
                  eventsLoaded: true,
                  eventsFailed: false,
                  upcomingEventCount: events.length,
                  nextEvent: events.isEmpty ? null : events.first,
                  clearNextEvent: events.isEmpty,
                );
              },
              onError: (Object _) {
                update(
                  eventsLoaded: true,
                  eventsFailed: true,
                  upcomingEventCount: 0,
                  clearNextEvent: true,
                );
              },
            );

        budgetSubscription = SharedBudgetService.instance
            .activeSharedBudgetsStream(gubId)
            .listen(
              (budgets) {
                update(
                  budgetsLoaded: true,
                  budgetsFailed: false,
                  activeBudgetCount: budgets.length,
                  latestBudget: budgets.isEmpty ? null : budgets.first,
                  clearLatestBudget: budgets.isEmpty,
                );
              },
              onError: (Object _) {
                update(
                  budgetsLoaded: true,
                  budgetsFailed: true,
                  activeBudgetCount: 0,
                  clearLatestBudget: true,
                );
              },
            );
      },
      onCancel: cancelSubscriptions,
    );

    return controller.stream;
  }
}
