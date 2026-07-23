import 'package:flutter/material.dart';

import '../services/goal_service.dart';

Future<bool> showDeleteGoalDialog({
  required BuildContext context,
  required String gubId,
  required String goalId,
}) async {
  var isDeleting = false;

  final deleted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> deleteGoal() async {
            if (isDeleting) return;

            setDialogState(() {
              isDeleting = true;
            });

            try {
              await GoalService.instance.deleteGoal(
                gubId: gubId,
                goalId: goalId,
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
                  onPressed: isDeleting ? null : deleteGoal,
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
