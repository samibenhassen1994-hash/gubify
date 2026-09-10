import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/guidelines/community_guidelines_service.dart';

void main() {
  test(
    'service checks acceptance for the current user and Community',
    () async {
      String? checkedCommunityId;
      String? checkedUserId;
      final service = CommunityGuidelinesService.forTesting(
        currentUserId: () => 'member-1',
        hasAccepted: ({required communityId, required userId}) async {
          checkedCommunityId = communityId;
          checkedUserId = userId;
          return true;
        },
        accept: ({required communityId, required userId}) async {},
      );

      expect(await service.hasCurrentUserAccepted('community-1'), isTrue);
      expect(checkedCommunityId, 'community-1');
      expect(checkedUserId, 'member-1');
    },
  );

  test('concurrent duplicate acceptance submissions are prevented', () async {
    final pending = Completer<void>();
    var writes = 0;
    final service = CommunityGuidelinesService.forTesting(
      currentUserId: () => 'member-1',
      hasAccepted: ({required communityId, required userId}) async => false,
      accept: ({required communityId, required userId}) {
        writes++;
        return pending.future;
      },
    );

    final first = service.acceptForCurrentUser('community-1');
    await expectLater(
      service.acceptForCurrentUser('community-1'),
      throwsStateError,
    );
    expect(writes, 1);

    pending.complete();
    await first;
  });

  test('service requires an authenticated user', () async {
    final service = CommunityGuidelinesService.forTesting(
      currentUserId: () => null,
      hasAccepted: ({required communityId, required userId}) async => false,
      accept: ({required communityId, required userId}) async {},
    );

    await expectLater(
      service.hasCurrentUserAccepted('community-1'),
      throwsStateError,
    );
    await expectLater(
      service.acceptForCurrentUser('community-1'),
      throwsStateError,
    );
  });
}
