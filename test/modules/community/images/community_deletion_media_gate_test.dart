import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/images/community_deletion_media_gate.dart';

void main() {
  test(
    'image cleanup completes before the remaining deletion lifecycle',
    () async {
      final calls = <String>[];

      await runCommunityDeletionAfterMediaCleanup(
        communityId: 'abc123',
        hasImage: true,
        deleteImageAsset: (communityId) async {
          calls.add('worker:$communityId');
        },
        continueDeletion: () async => calls.add('finalize'),
      );

      expect(calls, ['worker:abc123', 'finalize']);
    },
  );

  test('Community without image skips Worker and continues deletion', () async {
    var workerCalls = 0;
    var finalized = false;

    await runCommunityDeletionAfterMediaCleanup(
      communityId: 'abc123',
      hasImage: false,
      deleteImageAsset: (_) async => workerCalls++,
      continueDeletion: () async => finalized = true,
    );

    expect(workerCalls, 0);
    expect(finalized, isTrue);
  });

  test('Worker failure prevents the remaining deletion lifecycle', () async {
    var finalized = false;

    await expectLater(
      runCommunityDeletionAfterMediaCleanup(
        communityId: 'abc123',
        hasImage: true,
        deleteImageAsset: (_) async => throw StateError('network'),
        continueDeletion: () async => finalized = true,
      ),
      throwsStateError,
    );

    expect(finalized, isFalse);
  });

  for (final workerResult in ['ok', 'not found']) {
    test('Worker $workerResult result permits deletion to continue', () async {
      var finalized = false;

      await runCommunityDeletionAfterMediaCleanup(
        communityId: 'abc123',
        hasImage: true,
        deleteImageAsset: (_) async {},
        continueDeletion: () async => finalized = true,
      );

      expect(finalized, isTrue);
    });
  }

  test('retry continues when media was already deleted previously', () async {
    var cleanupCalls = 0;
    var continuationCalls = 0;

    Future<void> run() => runCommunityDeletionAfterMediaCleanup(
      communityId: 'abc123',
      hasImage: true,
      deleteImageAsset: (_) async => cleanupCalls++,
      continueDeletion: () async {
        continuationCalls++;
        if (continuationCalls == 1) throw StateError('finalization failed');
      },
    );

    await expectLater(run(), throwsStateError);
    await run();

    expect(cleanupCalls, 2);
    expect(continuationCalls, 2);
  });
}
