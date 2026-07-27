import 'package:flutter/material.dart';

import '../services/shared_budget_service.dart';

Future<bool> showDeleteSharedBudgetDialog({
  required BuildContext context,
  required String gubId,
  required String sharedBudgetId,
}) async {
  var isDeleting = false;

  final deleted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> deleteSharedBudget() async {
            if (isDeleting) return;

            setDialogState(() {
              isDeleting = true;
            });

            try {
              await SharedBudgetService.instance.deleteSharedBudget(
                gubId: gubId,
                sharedBudgetId: sharedBudgetId,
              );

              if (!dialogContext.mounted) return;

              Navigator.of(dialogContext).pop(true);
            } catch (error) {
              if (dialogContext.mounted) {
                setDialogState(() {
                  isDeleting = false;
                });
              }

              if (context.mounted) {
                final message = error
                    .toString()
                    .replaceFirst("Bad state: ", "")
                    .replaceFirst("Exception: ", "");

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      message.isEmpty
                          ? "Unable to delete the Shared Budget."
                          : message,
                    ),
                  ),
                );
              }
            }
          }

          return PopScope(
            canPop: !isDeleting,
            child: AlertDialog(
              title: const Text("Delete Shared Budget?"),
              content: const Text(
                "This will permanently delete the Shared Budget and all "
                "member contributions. This action cannot be undone.",
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: isDeleting ? null : deleteSharedBudget,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Delete"),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  if (deleted == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Shared Budget deleted.")));
  }

  return deleted ?? false;
}
