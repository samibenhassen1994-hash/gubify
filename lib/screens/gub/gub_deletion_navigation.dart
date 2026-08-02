import 'package:flutter/material.dart';

import 'my_gubs_screen.dart';

enum GubDeletionRouteAction { stay, exitSilently, exitWithOwnerMessage }

GubDeletionRouteAction resolveGubDeletionRouteAction({
  required Map<String, dynamic>? gubData,
  required String? currentUserId,
}) {
  if (gubData == null) return GubDeletionRouteAction.exitSilently;
  if (gubData['deletionStatus'] != 'deleting') {
    return GubDeletionRouteAction.stay;
  }
  return gubData['ownerId'] == currentUserId
      ? GubDeletionRouteAction.stay
      : GubDeletionRouteAction.exitWithOwnerMessage;
}

class GubDeletionNavigationController {
  final WidgetBuilder _destinationBuilder;
  bool _navigationScheduled = false;

  GubDeletionNavigationController({WidgetBuilder? destinationBuilder})
    : _destinationBuilder = destinationBuilder ?? _buildMyGubs;

  bool get navigationScheduled => _navigationScheduled;

  bool scheduleExit(BuildContext context, {String? message}) {
    if (_navigationScheduled || !context.mounted) return false;
    _navigationScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;

      final navigator = Navigator.of(context, rootNavigator: true);
      final messenger = ScaffoldMessenger.maybeOf(context);
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: buildDestination),
        (_) => false,
      );

      if (message != null && messenger != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!messenger.mounted) return;
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        });
      }
    });
    return true;
  }

  @visibleForTesting
  Widget buildDestination(BuildContext context) => _destinationBuilder(context);

  static Widget _buildMyGubs(BuildContext context) => const MyGubsScreen();
}
