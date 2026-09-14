import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/repositories/community_repository.dart';
import 'package:gubify/modules/profile/repositories/account_deletion_repository.dart';
import 'package:gubify/repositories/gub_deletion_repository.dart';

void main() {
  test('account deletion collection-group queries have explicit indexes', () {
    final repositorySource = File(
      'lib/modules/profile/repositories/account_deletion_repository.dart',
    ).readAsStringSync();
    expect('.collectionGroup('.allMatches(repositorySource), hasLength(8));

    const requiredIndexes = <(String, String)>[
      ('members', 'uid'),
      ('comments', 'authorId'),
      ('asks', 'authorId'),
      ('likes', 'userId'),
      ('votes', 'uid'),
      ('asks', 'bestAnswerAuthorId'),
      ('answers', 'authorId'),
      ('activeAskSlots', 'authorId'),
      ('joinRequests', 'userId'),
    ];
    final manifest =
        jsonDecode(File('firestore.indexes.json').readAsStringSync())
            as Map<String, dynamic>;
    final overrides = (manifest['fieldOverrides'] as List)
        .cast<Map<String, dynamic>>();

    for (final (collectionGroup, fieldPath) in requiredIndexes) {
      final override = overrides.singleWhere(
        (entry) =>
            entry['collectionGroup'] == collectionGroup &&
            entry['fieldPath'] == fieldPath,
      );
      final indexes = (override['indexes'] as List)
          .cast<Map<String, dynamic>>();
      for (final scope in const ['COLLECTION', 'COLLECTION_GROUP']) {
        for (final order in const ['ASCENDING', 'DESCENDING']) {
          expect(
            indexes.any(
              (index) =>
                  index['order'] == order && index['queryScope'] == scope,
            ),
            isTrue,
            reason: '$collectionGroup.$fieldPath needs $scope $order',
          );
        }
      }
    }
  });

  test('legacy Organized Event fallback is limited to current members', () {
    final repositorySource = File(
      'lib/modules/profile/repositories/account_deletion_repository.dart',
    ).readAsStringSync();
    expect(
      repositorySource,
      contains('includeLegacyDocuments: joinedAt != null'),
    );
    expect(
      repositorySource,
      contains(".where('assignmentUserIds', arrayContains: userId)"),
    );
  });

  test(
    'account deletion removes nested profile state and external requests',
    () {
      expect(AccountDeletionRepository.profileSubcollectionsForDeletion, [
        'gubs',
        'communities',
        'blockedUsers',
      ]);
      expect(AccountDeletionRepository.externalCollectionGroupsForDeletion, [
        'joinRequests',
      ]);
    },
  );

  test('Gub deletion covers direct and nested collections', () {
    expect(GubDeletionRepository.directCollectionsForDeletion, [
      'messages',
      'chatReads',
      'boardReads',
      'tasks',
      'events',
      'organizedEvents',
      'notifications',
      'creationCooldowns',
      'bans',
    ]);
    expect(GubDeletionRepository.nestedCollectionsForDeletion, {
      'proposals': ['votes'],
      'goals': ['members'],
      'posts': ['comments', 'likes'],
    });
  });

  for (final memberCount in [200, 201, 451]) {
    test(
      'Gub member cleanup drains $memberCount members in bounded pages',
      () async {
        final remaining = {
          for (var index = 0; index < memberCount; index++) 'member-$index',
        };
        final pageSizes = <int>[];
        var ownerCopyDeleted = false;
        var completed = false;

        await GubDeletionRepository.drainMemberCleanupForTesting(
          loadPage: (limit) async => remaining.take(limit).toList(),
          deletePage: (uids) async {
            expect(completed, isFalse);
            expect(uids.length * 2, lessThanOrEqualTo(400));
            pageSizes.add(uids.length);
            remaining.removeAll(uids);
          },
          deleteOwnerCopy: () async => ownerCopyDeleted = true,
          onDrained: () async {
            expect(remaining, isEmpty);
            completed = true;
          },
        );

        expect(pageSizes, everyElement(lessThanOrEqualTo(200)));
        expect(pageSizes.length, (memberCount / 200).ceil());
        expect(ownerCopyDeleted, isTrue);
        expect(completed, isTrue);
      },
    );
  }

  test(
    'Gub member cleanup retry starts from remaining membership documents',
    () async {
      final remaining = {'member-200', 'member-201'};
      final deleted = <String>[];

      await GubDeletionRepository.drainMemberCleanupForTesting(
        loadPage: (limit) async => remaining.take(limit).toList(),
        deletePage: (uids) async {
          deleted.addAll(uids);
          remaining.removeAll(uids);
        },
        deleteOwnerCopy: () async {},
        onDrained: () async {},
      );

      expect(deleted, ['member-200', 'member-201']);
    },
  );

  test(
    'Gub member cleanup removes owner copy without owner membership',
    () async {
      var ownerCopyDeleted = false;
      await GubDeletionRepository.drainMemberCleanupForTesting(
        loadPage: (_) async => const [],
        deletePage: (_) async => fail('No membership page should be deleted.'),
        deleteOwnerCopy: () async => ownerCopyDeleted = true,
        onDrained: () async {},
      );
      expect(ownerCopyDeleted, isTrue);
    },
  );

  test('Community deletion clears reward pointers to deleted content', () {
    expect(CommunityRepository.rewardReferenceFieldsForDeletion, [
      'lastRewardCommunityId',
      'lastRewardAskId',
      'lastRewardRole',
    ]);
  });
}
