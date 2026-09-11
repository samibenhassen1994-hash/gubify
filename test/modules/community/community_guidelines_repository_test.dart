import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/guidelines/community_guidelines_repository.dart';

void main() {
  test('global acceptance recognizes only accepted current version', () async {
    for (final entry in <(Map<String, dynamic>?, bool)>[
      (null, false),
      (const {}, false),
      (const {'accepted': true}, false),
      (const {'accepted': false, 'version': 1}, false),
      (const {'accepted': true, 'version': 0}, false),
      (const {'accepted': true, 'version': 2}, false),
      (const {'accepted': true, 'version': 1}, true),
    ]) {
      final repository = CommunityGuidelinesRepository.forTesting(
        loadAcceptance: ({required userId}) async => entry.$1,
        writeAcceptance: ({required userId, required data}) async {},
      );
      expect(await repository.hasAccepted(userId: 'member-1'), entry.$2);
    }
  });

  test('accept writes only the global versioned acceptance fields', () async {
    String? writtenUserId;
    Map<String, Object?>? writtenData;
    final repository = CommunityGuidelinesRepository.forTesting(
      loadAcceptance: ({required userId}) async => null,
      writeAcceptance:
          ({required String userId, required Map<String, Object?> data}) async {
            writtenUserId = userId;
            writtenData = data;
          },
    );

    await repository.accept(userId: 'member-1');

    expect(writtenUserId, 'member-1');
    expect(writtenData!.keys, {'accepted', 'acceptedAt', 'version'});
    expect(writtenData!['accepted'], isTrue);
    expect(
      writtenData!['version'],
      CommunityGuidelinesRepository.currentVersion,
    );
    expect(writtenData!['acceptedAt'], isA<FieldValue>());
  });
}
