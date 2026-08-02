import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../modules/organized_events/models/gub_event_model.dart';
import '../../modules/organized_events/screens/gub_event_details_screen.dart';
import '../../modules/organized_events/services/gub_event_service.dart';
import '../../modules/proposals/models/proposal_model.dart';
import '../../modules/proposals/screens/proposal_details_screen.dart';
import '../../modules/proposals/services/proposal_service.dart';
import '../../modules/shared_budget/services/shared_budget_service.dart';
import '../../modules/tasks/models/task_model.dart';
import '../../modules/tasks/screens/task_details_screen.dart';
import '../../modules/tasks/services/task_service.dart';
import '../models/creation_availability.dart';

class CreationGate {
  CreationGate._();

  static final Set<String> _checksInProgress = {};

  static Future<bool> ensureAvailable({
    required BuildContext context,
    required String gubId,
    required CreationModuleType moduleType,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      _showError(context, 'You must be signed in to create this item.');
      return false;
    }

    final key = '$gubId/$userId/${moduleType.firestoreValue}';
    if (!_checksInProgress.add(key)) return false;

    NavigatorState? loadingNavigator;
    final loadingReady = Completer<void>();
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          loadingNavigator = Navigator.of(dialogContext);
          if (!loadingReady.isCompleted) loadingReady.complete();
          return const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),
          );
        },
      ),
    );

    try {
      await loadingReady.future;
      final availability = await _loadAvailability(
        gubId: gubId,
        moduleType: moduleType,
      );
      _closeLoading(loadingNavigator);
      loadingNavigator = null;
      if (!context.mounted) return false;
      if (availability.isUnlimited) return true;
      if (availability.canCreate) return true;

      await _showBlockedSheet(
        context: context,
        gubId: gubId,
        moduleType: moduleType,
        availability: availability,
      );
      return false;
    } catch (error) {
      _closeLoading(loadingNavigator);
      loadingNavigator = null;
      if (context.mounted) {
        _showError(context, _errorMessage(error));
      }
      return false;
    } finally {
      _closeLoading(loadingNavigator);
      _checksInProgress.remove(key);
    }
  }

  static Future<CreationAvailability> _loadAvailability({
    required String gubId,
    required CreationModuleType moduleType,
  }) {
    return switch (moduleType) {
      CreationModuleType.task => TaskService.instance.creationAvailability(
        gubId: gubId,
      ),
      CreationModuleType.organizedEvent =>
        GubEventService.instance.creationAvailability(gubId: gubId),
      CreationModuleType.proposal =>
        ProposalService.instance.creationAvailability(gubId: gubId),
      CreationModuleType.sharedBudget =>
        SharedBudgetService.instance.creationAvailability(gubId: gubId),
    };
  }

  static Future<void> _showBlockedSheet({
    required BuildContext context,
    required String gubId,
    required CreationModuleType moduleType,
    required CreationAvailability availability,
  }) async {
    final openDetails = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _blockedTitle(moduleType),
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(_blockedMessage(moduleType, availability)),
              if (availability.activeItemTitle?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(
                  availability.activeItemTitle!,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
              const SizedBox(height: 20),
              if (availability.hasActiveItem)
                FilledButton(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: const Text('Open details'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext, false),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );

    if (openDetails == true && context.mounted) {
      await _openActiveItem(
        context: context,
        gubId: gubId,
        availability: availability,
      );
    }
  }

  static Future<void> _openActiveItem({
    required BuildContext context,
    required String gubId,
    required CreationAvailability availability,
  }) async {
    final item = availability.activeItem;
    final route = switch (item) {
      TaskModel task => MaterialPageRoute<void>(
        builder: (_) =>
            TaskDetailsScreen(gubId: task.gubId, taskId: task.taskId),
      ),
      GubEventModel event => MaterialPageRoute<void>(
        builder: (_) =>
            GubEventDetailsScreen(gubId: event.gubId, eventId: event.eventId),
      ),
      ProposalModel proposal => MaterialPageRoute<void>(
        builder: (_) => ProposalDetailsScreen(proposal: proposal),
      ),
      _ => null,
    };
    if (route != null) {
      await Navigator.of(context).push(route);
    }
  }

  static String _blockedTitle(CreationModuleType moduleType) {
    return switch (moduleType) {
      CreationModuleType.task => 'Task creation unavailable',
      CreationModuleType.organizedEvent => 'Event creation unavailable',
      CreationModuleType.proposal => 'Proposal creation unavailable',
      CreationModuleType.sharedBudget => 'Shared Budget creation unavailable',
    };
  }

  static String _blockedMessage(
    CreationModuleType moduleType,
    CreationAvailability availability,
  ) {
    if (availability.hasActiveItem) {
      return switch (moduleType) {
        CreationModuleType.task =>
          'You already have an active task. Complete it before creating another one.',
        CreationModuleType.organizedEvent =>
          'You already have an active event. Complete it before creating another one.',
        CreationModuleType.proposal =>
          'You already have an active proposal. Close it before creating another one.',
        CreationModuleType.sharedBudget => '',
      };
    }

    final remaining = formatCooldownRemaining(
      availability.cooldown?.remaining ?? Duration.zero,
    );
    final itemName = switch (moduleType) {
      CreationModuleType.task => 'task',
      CreationModuleType.organizedEvent => 'event',
      CreationModuleType.proposal => 'proposal',
      CreationModuleType.sharedBudget => 'Shared Budget',
    };
    return 'You can create another $itemName in $remaining.';
  }

  static void _closeLoading(NavigatorState? navigator) {
    if (navigator != null && navigator.mounted) {
      navigator.pop();
    }
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _errorMessage(Object error) {
    return error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Exception: ', '');
  }
}
