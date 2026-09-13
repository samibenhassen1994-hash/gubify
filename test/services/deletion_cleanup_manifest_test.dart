import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/repositories/community_repository.dart';
import 'package:gubify/modules/profile/repositories/account_deletion_repository.dart';
import 'package:gubify/repositories/gub_deletion_repository.dart';

void main() {
  test(
    'account deletion removes user-owned nested state before profile root',
    () {
      expect(AccountDeletionRepository.profileSubcollectionsForDeletion, [
        'gubs',
        'communities',
        'blockedUsers',
      ]);
    },
  );

  test('account deletion discovers external user join requests', () {
    expect(AccountDeletionRepository.externalCollectionGroupsForDeletion, [
      'joinRequests',
    ]);
  });

  test('Gub deletion includes every direct subcollection without children', () {
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
      'members',
    ]);
  });

  test('Gub deletion recursively removes nested Firestore children', () {
    expect(GubDeletionRepository.nestedCollectionsForDeletion, {
      'proposals': ['votes'],
      'goals': ['members'],
      'posts': ['comments', 'likes'],
    });
  });

  test('Community deletion clears reward pointers to deleted content', () {
    expect(CommunityRepository.rewardReferenceFieldsForDeletion, [
      'lastRewardCommunityId',
      'lastRewardAskId',
      'lastRewardRole',
    ]);
  });
}
