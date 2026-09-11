import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/guidelines/community_guidelines_service.dart';

void main() {
  test('service checks global acceptance for the current user', () async {
    String? checkedUserId;
    final service = CommunityGuidelinesService.forTesting(
      currentUserId: () => 'member-1',
      hasAccepted: ({required userId}) async {
        checkedUserId = userId;
        return true;
      },
      accept: ({required userId}) async {},
    );
    expect(await service.hasCurrentUserAccepted(), isTrue);
    expect(checkedUserId, 'member-1');
  });

  test('acceptance writes once for the current user', () async {
    final writtenUsers = <String>[];
    final service = CommunityGuidelinesService.forTesting(
      currentUserId: () => 'member-1',
      hasAccepted: ({required userId}) async => false,
      accept: ({required userId}) async => writtenUsers.add(userId),
    );
    await service.acceptForCurrentUser();
    expect(writtenUsers, ['member-1']);
  });

  test(
    'concurrent duplicate acceptance submissions are prevented globally',
    () async {
      final pending = Completer<void>();
      var writes = 0;
      final service = CommunityGuidelinesService.forTesting(
        currentUserId: () => 'member-1',
        hasAccepted: ({required userId}) async => false,
        accept: ({required userId}) {
          writes++;
          return pending.future;
        },
      );
      final first = service.acceptForCurrentUser();
      await expectLater(service.acceptForCurrentUser(), throwsStateError);
      expect(writes, 1);
      pending.complete();
      await first;
    },
  );

  test('service requires an authenticated user', () async {
    final service = CommunityGuidelinesService.forTesting(
      currentUserId: () => null,
      hasAccepted: ({required userId}) async => false,
      accept: ({required userId}) async {},
    );
    await expectLater(service.hasCurrentUserAccepted(), throwsStateError);
    await expectLater(service.acceptForCurrentUser(), throwsStateError);
  });
}
