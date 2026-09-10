import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/guidelines/community_guidelines_repository.dart';

void main() {
  test(
    'current accepted version is recognized and stale data is rejected',
    () async {
      final accepted = CommunityGuidelinesRepository.forTesting(
        loadMember: ({required communityId, required userId}) async => {
          'antiSpamRulesAccepted': true,
          'antiSpamRulesVersion': 1,
        },
        writeAcceptance:
            ({required communityId, required userId, required data}) async {},
      );
      expect(
        await accepted.hasAccepted(
          communityId: 'community-1',
          userId: 'member-1',
        ),
        isTrue,
      );

      for (final data in <Map<String, dynamic>?>[
        null,
        const {},
        const {'antiSpamRulesAccepted': true},
        const {'antiSpamRulesAccepted': false, 'antiSpamRulesVersion': 1},
        const {'antiSpamRulesAccepted': true, 'antiSpamRulesVersion': 0},
      ]) {
        final repository = CommunityGuidelinesRepository.forTesting(
          loadMember: ({required communityId, required userId}) async => data,
          writeAcceptance:
              ({required communityId, required userId, required data}) async {},
        );
        expect(
          await repository.hasAccepted(
            communityId: 'community-1',
            userId: 'member-1',
          ),
          isFalse,
        );
      }
    },
  );

  test(
    'acceptance targets the current member and writes only versioned fields',
    () async {
      String? writtenCommunityId;
      String? writtenUserId;
      Map<String, Object?>? writtenData;
      final repository = CommunityGuidelinesRepository.forTesting(
        loadMember: ({required communityId, required userId}) async => {
          'uid': userId,
        },
        writeAcceptance:
            ({
              required String communityId,
              required String userId,
              required Map<String, Object?> data,
            }) async {
              writtenCommunityId = communityId;
              writtenUserId = userId;
              writtenData = data;
            },
      );

      await repository.accept(communityId: 'community-1', userId: 'member-1');

      expect(writtenCommunityId, 'community-1');
      expect(writtenUserId, 'member-1');
      expect(writtenData!.keys, {
        'antiSpamRulesAccepted',
        'antiSpamRulesAcceptedAt',
        'antiSpamRulesVersion',
      });
      expect(writtenData!['antiSpamRulesAccepted'], isTrue);
      expect(writtenData!['antiSpamRulesVersion'], 1);
      expect(writtenData!['antiSpamRulesAcceptedAt'], isA<FieldValue>());
    },
  );

  test('acceptance does not create a missing member', () async {
    var writes = 0;
    final repository = CommunityGuidelinesRepository.forTesting(
      loadMember: ({required communityId, required userId}) async => null,
      writeAcceptance:
          ({required communityId, required userId, required data}) async {
            writes++;
          },
    );

    await expectLater(
      repository.accept(communityId: 'community-1', userId: 'missing-member'),
      throwsStateError,
    );
    expect(writes, 0);
  });
}
