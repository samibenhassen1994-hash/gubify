import 'package:flutter/material.dart';

import '../core/models/deletion_context.dart';

Future<bool> showDeleteItemDialog({
  required BuildContext context,
  required String title,
  required String moduleName,
  required DeletionContext deletionContext,
  required Future<void> Function() onDelete,
  required String successMessage,
}) async {
  final message = _deletionMessage(moduleName, deletionContext);
  final deleteLabel =
      deletionContext.startsCooldown && !deletionContext.currentUserIsOwner
      ? 'Delete and start cooldown'
      : 'Delete';
  var deleting = false;
  final deleted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        Future<void> delete() async {
          if (deleting) return;
          setDialogState(() => deleting = true);
          try {
            await onDelete();
            if (dialogContext.mounted) {
              Navigator.pop(dialogContext, true);
            }
          } catch (error) {
            if (dialogContext.mounted) {
              setDialogState(() => deleting = false);
            }
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
            }
          }
        }

        return PopScope(
          canPop: !deleting,
          child: AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: deleting
                    ? null
                    : () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: deleting ? null : delete,
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: deleting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(deleteLabel),
              ),
            ],
          ),
        );
      },
    ),
  );

  if (deleted == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(successMessage)));
  }
  return deleted ?? false;
}

String _deletionMessage(String moduleName, DeletionContext deletionContext) {
  if (!deletionContext.startsCooldown) {
    return 'This item will be removed for everyone.';
  }
  if (deletionContext.cooldownAppliesToOriginalCreator) {
    return 'The original creator won’t be able to create another '
        '$moduleName in this Gub for 12 hours.';
  }
  return 'This $moduleName will be removed for everyone. After deleting it, '
      'you won’t be able to create another $moduleName in this Gub for '
      '12 hours.';
}

String _errorMessage(Object error) {
  final message = error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
  return message.isEmpty ? 'Unable to delete this item.' : message;
}
