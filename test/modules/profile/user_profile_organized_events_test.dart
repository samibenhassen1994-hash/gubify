import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/organized_events/models/gub_event_model.dart';
import 'package:gubify/modules/profile/services/user_profile_service.dart';

void main() {
  GubEventModel event({
    required String id,
    required String creatorId,
    required int createdAtSeconds,
    String status = 'active',
  }) {
    return GubEventModel(
      eventId: id,
      gubId: 'gub-1',
      title: 'Event $id',
      createdBy: creatorId,
      createdByName: creatorId == '__deleted_user__'
          ? 'Deleted user'
          : 'Member',
      createdAt: Timestamp(createdAtSeconds, 0),
      status: status,
      assignments: const [],
    );
  }

  group('organized events in user profile', () {
    test(
      'includes active and completed events created by the profile user',
      () {
        final active = event(
          id: 'active',
          creatorId: 'member-a',
          createdAtSeconds: 10,
        );
        final completed = event(
          id: 'completed',
          creatorId: 'member-a',
          createdAtSeconds: 20,
          status: 'completed',
        );

        final activities =
            UserProfileService.buildOrganizedEventActivityEntries(
              events: [active, completed],
              userId: 'member-a',
            );

        expect(activities.map((activity) => activity.id), [
          'completed',
          'active',
        ]);
        expect(activities.first.organizedEvent, same(completed));
        expect(activities.last.organizedEvent, same(active));
      },
    );

    test('another member profile receives only that member events', () {
      final targetEvent = event(
        id: 'target',
        creatorId: 'member-b',
        createdAtSeconds: 30,
      );
      final viewerEvent = event(
        id: 'viewer',
        creatorId: 'member-a',
        createdAtSeconds: 40,
      );

      final activities = UserProfileService.buildOrganizedEventActivityEntries(
        events: [viewerEvent, targetEvent],
        userId: 'member-b',
      );

      expect(activities, hasLength(1));
      expect(activities.single.id, 'target');
      expect(activities.single.organizedEvent, same(targetEvent));
    });

    test('deleted-user sentinel is never treated as a profile user', () {
      final deletedEvent = event(
        id: 'deleted',
        creatorId: '__deleted_user__',
        createdAtSeconds: 50,
      );

      final activities = UserProfileService.buildOrganizedEventActivityEntries(
        events: [deletedEvent],
        userId: '__deleted_user__',
      );

      expect(activities, isEmpty);
      expect(deletedEvent.createdBy, '__deleted_user__');
      expect(deletedEvent.createdByName, 'Deleted user');
    });

    test('mapping leaves unrelated event data unchanged', () {
      final unrelated = event(
        id: 'unrelated',
        creatorId: 'member-b',
        createdAtSeconds: 60,
      );

      final activities = UserProfileService.buildOrganizedEventActivityEntries(
        events: [unrelated],
        userId: 'member-a',
      );

      expect(activities, isEmpty);
      expect(unrelated.createdBy, 'member-b');
      expect(unrelated.title, 'Event unrelated');
      expect(unrelated.status, 'active');
    });
  });
}
