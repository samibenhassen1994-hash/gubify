import 'package:flutter/material.dart';

import 'community_guidelines_screen.dart';
import 'community_guidelines_service.dart';

typedef CommunityGuidelinesPreAction =
    Future<bool> Function(BuildContext context);

Future<bool> ensureCommunityGuidelinesAccepted(
  BuildContext context, {
  CommunityGuidelinesService? service,
}) async {
  final guidelinesService = service ?? CommunityGuidelinesService.instance;
  if (await guidelinesService.hasCurrentUserAccepted()) return true;
  if (!context.mounted) return false;

  return await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (routeContext) => CommunityGuidelinesScreen(
            onAccept: guidelinesService.acceptForCurrentUser,
            onAccepted: () => Navigator.of(routeContext).pop(true),
          ),
        ),
      ) ??
      false;
}
