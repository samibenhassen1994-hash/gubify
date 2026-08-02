import 'package:flutter/material.dart';

import '../../../core/models/deletion_context.dart';
import '../../../widgets/delete_item_dialog.dart';
import '../services/shared_budget_service.dart';

Future<bool> showDeleteSharedBudgetDialog({
  required BuildContext context,
  required String gubId,
  required String sharedBudgetId,
  DeletionContext? deletionContext,
}) async {
  final effectiveContext =
      deletionContext ??
      await SharedBudgetService.instance.deletionContext(
        gubId: gubId,
        sharedBudgetId: sharedBudgetId,
      );
  if (!context.mounted || !effectiveContext.canDelete) return false;
  return showDeleteItemDialog(
    context: context,
    title: 'Delete Shared Budget?',
    moduleName: 'shared budget',
    deletionContext: effectiveContext,
    successMessage: 'Shared Budget deleted.',
    onDelete: () => SharedBudgetService.instance.deleteSharedBudget(
      gubId: gubId,
      sharedBudgetId: sharedBudgetId,
    ),
  );
}
