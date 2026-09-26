import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/push_notifications/navigation/global_push_notification_router.dart';

void main() {
  test('recognizes exactly the six approved global push routes', () {
    expect(GlobalPushNotificationRouter.supportedTypes, {
      'task_assigned',
      'proposal_created',
      'community_answer_created',
      'community_best_answer_selected',
      'community_join_request_created',
      'community_join_request_resolved',
    });
    expect(GlobalPushNotificationRouter.supportedTypes, isNot(contains('unknown')));
  });
}
