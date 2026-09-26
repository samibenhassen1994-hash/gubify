import 'package:flutter/material.dart';

/// Validates the six Worker-issued notification kinds before navigation.
class GlobalPushNotificationRouter {
  static const supportedTypes = {
    'task_assigned', 'proposal_created', 'community_answer_created',
    'community_best_answer_selected', 'community_join_request_created',
    'community_join_request_resolved',
  };

  Future<void> open(BuildContext context, Map<String, String> data) async {
    if (!supportedTypes.contains(data['type'])) return;
    // Destination screens are resolved from authoritative IDs by their normal
    // entry flows; do not trust a client-supplied route name or URL.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
