import 'package:flutter/material.dart';

class CommunityHomeTopActions extends StatelessWidget {
  const CommunityHomeTopActions({
    super.key,
    required this.isKeyboardOpen,
    this.pendingRequestsAction,
    this.reportAction,
    required this.settingsAction,
  });

  final bool isKeyboardOpen;
  final Widget? pendingRequestsAction;
  final Widget? reportAction;
  final Widget settingsAction;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      ?pendingRequestsAction,
      if (!isKeyboardOpen) ?reportAction,
      if (!isKeyboardOpen) settingsAction,
    ];

    if (actions.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < actions.length; index++) ...[
          if (index > 0) const SizedBox(width: 10),
          actions[index],
        ],
      ],
    );
  }
}
