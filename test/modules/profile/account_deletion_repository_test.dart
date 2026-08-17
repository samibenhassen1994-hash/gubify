import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/profile/repositories/account_deletion_repository.dart';

void main() {
  test('canonical memberships are merged with personal membership copies', () {
    final memberships = AccountDeletionRepository.mergeMembershipIds(
      userId: 'user-a',
      privateCopyIds: const ['copy-gub'],
      communityCopyIds: const ['copy-community'],
      canonicalMembershipPaths: const [
        'gubs/canonical-gub/members/user-a',
        'communities/canonical-community/members/user-a',
        'gubs/canonical-gub/members/user-a',
        'other/unknown/members/user-a',
        'nested/path/gubs/id/members/user-a',
        'gubs/other-user/members/user-b',
      ],
    );

    expect(memberships.privateGubIds, ['canonical-gub', 'copy-gub']);
    expect(memberships.communityIds, ['canonical-community', 'copy-community']);
  });

  test('only the deleting user assignment identity is anonymized', () {
    final assignments = <Object?>[
      {
        'userId': 'deleting-user',
        'userName': 'Original Name',
        'taskText': 'Keep task',
        'isCompleted': true,
        'completedAt': 'preserved timestamp',
      },
      {
        'userId': 'surviving-user',
        'userName': 'Surviving Name',
        'taskText': 'Keep other task',
        'isCompleted': false,
        'completedAt': null,
      },
    ];

    final result =
        AccountDeletionRepository.anonymizeOrganizedEventAssignmentsData(
          assignments,
          'deleting-user',
        );

    expect(result, [
      {
        'userId': '__deleted_user__',
        'userName': 'Deleted user',
        'taskText': 'Keep task',
        'isCompleted': true,
        'completedAt': 'preserved timestamp',
      },
      assignments[1],
    ]);
    expect(assignments[0], containsPair('userId', 'deleting-user'));
  });
}
