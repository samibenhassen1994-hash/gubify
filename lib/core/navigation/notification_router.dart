import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../modules/goals/screens/goal_members_screen.dart';
import '../../modules/goals/screens/goals_screen.dart';
import '../../modules/goals/services/goal_service.dart';
import '../../modules/gub_calendar/repositories/event_repository.dart';
import '../../modules/gub_calendar/screens/gub_calendar_screen.dart';
import '../../modules/proposals/repositories/proposal_repository.dart';
import '../../modules/proposals/screens/proposal_details_screen.dart';
import '../../modules/proposals/screens/proposals_screen.dart';
import '../../modules/tasks/repositories/task_repository.dart';
import '../../modules/tasks/screens/task_details_screen.dart';
import '../../modules/tasks/screens/tasks_screen.dart';
import '../../repositories/gub_repository.dart';
import '../../screens/gub/board_screen.dart';

class NotificationRouter {
  NotificationRouter._();

  static Future<void> navigate({
    required BuildContext context,
    required String gubId,
    required Map<String, dynamic> data,
  }) async {
    final effectiveGubId = _stringValue(data["gubId"]) ?? gubId;
    final type = (_stringValue(data["type"]) ?? "").toLowerCase();
    final destination =
        (_stringValue(data["module"]) ?? _stringValue(data["screen"]) ?? "")
            .toLowerCase();

    final goalId = _stringValue(data["goalId"]);
    final proposalId = _stringValue(data["proposalId"]);
    final taskId = _stringValue(data["taskId"]);
    final eventId = _stringValue(data["eventId"]);
    final postId = _stringValue(data["postId"]);

    if (goalId != null) {
      await _openGoal(context: context, gubId: effectiveGubId, goalId: goalId);
      return;
    }

    if (proposalId != null) {
      await _openProposal(
        context: context,
        gubId: effectiveGubId,
        proposalId: proposalId,
      );
      return;
    }

    if (taskId != null) {
      await _openTask(context: context, gubId: effectiveGubId, taskId: taskId);
      return;
    }

    if (eventId != null) {
      await _openCalendarEvent(
        context: context,
        gubId: effectiveGubId,
        eventId: eventId,
      );
      return;
    }

    if (postId != null) {
      _openBoard(context: context, gubId: effectiveGubId);
      return;
    }

    if (type.startsWith("goal_")) {
      await _openGoals(context: context, gubId: effectiveGubId);
      return;
    }

    if (type.startsWith("proposal_")) {
      await _openProposals(context: context, gubId: effectiveGubId);
      return;
    }

    if (type.startsWith("task_")) {
      _openTasks(context: context, gubId: effectiveGubId);
      return;
    }

    if (type.startsWith("calendar_") || type.startsWith("event_")) {
      await _openCalendar(context: context, gubId: effectiveGubId);
      return;
    }

    if (type.startsWith("board_") || type.startsWith("post_")) {
      _openBoard(context: context, gubId: effectiveGubId);
      return;
    }

    switch (destination) {
      case "goal":
      case "goals":
      case "shared_budget":
      case "sharedbudget":
        await _openGoals(context: context, gubId: effectiveGubId);
        return;

      case "proposal":
      case "proposals":
        await _openProposals(context: context, gubId: effectiveGubId);
        return;

      case "task":
      case "tasks":
        _openTasks(context: context, gubId: effectiveGubId);
        return;

      case "calendar":
      case "event":
      case "events":
        await _openCalendar(context: context, gubId: effectiveGubId);
        return;

      case "board":
      case "post":
      case "posts":
        _openBoard(context: context, gubId: effectiveGubId);
        return;
    }

    if (context.mounted) {
      _showMessage(context, "This notification is no longer available.");
    }
  }

  static Future<void> _openGoal({
    required BuildContext context,
    required String gubId,
    required String goalId,
  }) async {
    final goal = await GoalService.instance.getGoalById(
      gubId: gubId,
      goalId: goalId,
    );

    if (!context.mounted) return;

    if (goal == null) {
      _showMessage(context, "This Shared Budget is no longer available.");
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GoalMembersScreen(
          gubId: gubId,
          goalId: goal.goalId,
          ownerId: goal.ownerId,
        ),
      ),
    );
  }

  static Future<void> _openProposal({
    required BuildContext context,
    required String gubId,
    required String proposalId,
  }) async {
    final proposal = await ProposalRepository.instance.getProposal(
      gubId: gubId,
      proposalId: proposalId,
    );

    if (!context.mounted) return;

    if (proposal == null) {
      _showMessage(context, "This proposal is no longer available.");
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProposalDetailsScreen(proposal: proposal),
      ),
    );
  }

  static Future<void> _openTask({
    required BuildContext context,
    required String gubId,
    required String taskId,
  }) async {
    final task = await TaskRepository.instance.getTask(
      gubId: gubId,
      taskId: taskId,
    );

    if (!context.mounted) return;

    if (task == null) {
      _showMessage(context, "This task is no longer available.");
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailsScreen(gubId: gubId, taskId: taskId),
      ),
    );
  }

  static Future<void> _openCalendarEvent({
    required BuildContext context,
    required String gubId,
    required String eventId,
  }) async {
    final event = await EventRepository.instance.getEvent(
      gubId: gubId,
      eventId: eventId,
    );

    if (!context.mounted) return;

    if (event == null) {
      _showMessage(context, "This calendar event is no longer available.");
      return;
    }

    await _openCalendar(context: context, gubId: gubId);
  }

  static Future<void> _openGoals({
    required BuildContext context,
    required String gubId,
  }) async {
    final gub = await GubRepository.instance.getHub(gubId);

    if (!context.mounted) return;

    if (gub == null) {
      _showMessage(context, "This Gub is no longer available.");
      return;
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final canCreateBudget =
        currentUserId != null && currentUserId == gub["ownerId"];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            GoalsScreen(gubId: gubId, canCreateBudget: canCreateBudget),
      ),
    );
  }

  static Future<void> _openProposals({
    required BuildContext context,
    required String gubId,
  }) async {
    final gub = await GubRepository.instance.getHub(gubId);

    if (!context.mounted) return;

    if (gub == null) {
      _showMessage(context, "This Gub is no longer available.");
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProposalsScreen(gubId: gubId, memberCount: gub["memberCount"] ?? 1),
      ),
    );
  }

  static void _openTasks({
    required BuildContext context,
    required String gubId,
  }) {
    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TasksScreen(gubId: gubId)),
    );
  }

  static Future<void> _openCalendar({
    required BuildContext context,
    required String gubId,
  }) async {
    final gub = await GubRepository.instance.getHub(gubId);

    if (!context.mounted) return;

    if (gub == null) {
      _showMessage(context, "This Gub is no longer available.");
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            GubCalendarScreen(gubId: gubId, ownerId: gub["ownerId"] ?? ""),
      ),
    );
  }

  static void _openBoard({
    required BuildContext context,
    required String gubId,
  }) {
    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BoardScreen(gubId: gubId)),
    );
  }

  static String? _stringValue(dynamic value) {
    if (value is! String) return null;

    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  static void _showMessage(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
