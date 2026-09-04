import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_model.dart';
import 'package:gubify/modules/community/screens/community_members_screen.dart';
import 'package:gubify/modules/community/services/community_user_xp_cache.dart';
import 'package:gubify/modules/moderation/blocking/models/user_block_model.dart';
import 'package:gubify/modules/moderation/blocking/repositories/user_block_repository.dart';
import 'package:gubify/modules/moderation/blocking/services/user_block_service.dart';
import 'package:gubify/modules/profile/models/user_profile_model.dart';
import 'package:gubify/modules/profile/screens/user_profile_screen.dart';

final _community = CommunityModel(
  communityId: 'community',
  name: 'Community',
  ownerId: 'owner',
  memberCount: 2,
  visibility: CommunityModel.publicVisibility,
  createdAt: null,
  type: CommunityModel.defaultType,
  language: CommunityModel.defaultLanguage,
  description: '',
  accessMode: CommunityModel.openAccessMode,
);

const _owner = CommunityMemberModel(
  userId: 'owner',
  displayName: 'Owner',
  photoUrl: null,
  role: 'owner',
  joinedAt: null,
);

const _member = CommunityMemberModel(
  userId: 'member',
  displayName: 'Alex',
  photoUrl: null,
  role: 'member',
  joinedAt: null,
  xp: 900,
);

Widget _screen({
  required bool owner,
  String currentUserId = 'member',
  Future<void> Function(String)? onRemove,
  Future<void> Function(String)? onBan,
  Future<UserProfileModel?> Function(String)? profileLoader,
}) => MaterialApp(
  home: CommunityMembersScreen(
    community: _community,
    isOwner: owner,
    currentUserId: currentUserId,
    memberStream: Stream.value(const [_owner, _member]),
    userXpCache: CommunityUserXpCache(
      loadXp: (_) async => const {'owner': 0, 'member': 900},
    ),
    onRemove: onRemove,
    onBan: onBan,
    profileLoader: profileLoader,
    userBlockService: _userBlockService,
  ),
);

void main() {
  testWidgets('a member sees the Community member list without admin actions', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(owner: false));
    await tester.pumpAndSettle();

    expect(find.text('Owner'), findsAtLeastNWidgets(1));
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Lv 10'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('owner sees actions only for normal members', (tester) async {
    await tester.pumpWidget(_screen(owner: true, currentUserId: 'owner'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Assign role'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
    expect(find.text('Ban'), findsOneWidget);
  });

  testWidgets('Assign role shows Coming soon', (tester) async {
    await tester.pumpWidget(_screen(owner: true, currentUserId: 'owner'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assign role'));
    await tester.pump();
    expect(find.text('Coming soon'), findsOneWidget);
  });

  testWidgets('tapping a Community member avatar opens the Community profile', (
    tester,
  ) async {
    await tester.pumpWidget(
      _screen(
        owner: false,
        profileLoader: (_) => Future.value(
          const UserProfileModel(
            userId: 'member',
            displayName: 'Alex',
            isCurrentUser: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('member-avatar-member')));
    await tester.pumpAndSettle();
    expect(find.byType(UserProfileScreen), findsOneWidget);
  });

  testWidgets(
    'Remove and Ban use their existing service flows after confirmation',
    (tester) async {
      var removed = false;
      var banned = false;
      await tester.pumpWidget(
        _screen(
          owner: true,
          currentUserId: 'owner',
          onRemove: (_) async => removed = true,
          onBan: (_) async => banned = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-remove')));
      await tester.pumpAndSettle();
      expect(removed, isTrue);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ban'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-ban')));
      await tester.pumpAndSettle();
      expect(banned, isTrue);
    },
  );

  testWidgets('Community profiles show identity and no Gub activity', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UserProfileScreen.community(
          communityId: _community.communityId,
          communityName: _community.name,
          userId: _member.userId,
          communityUserXpCache: CommunityUserXpCache(
            loadXp: (_) async => const {'member': 900},
          ),
          profileFuture: Future.value(
            const UserProfileModel(
              userId: 'member',
              displayName: 'Alex',
              role: 'member',
              isCurrentUser: true,
            ),
          ),
          activeAsksStream: Stream.value(const []),
          userBlockService: _userBlockService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('member'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Activity'), findsNothing);
  });

  testWidgets('Private Gub profiles retain their Activity section', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UserProfileScreen(
          gubId: 'gub',
          userId: _member.userId,
          profileFuture: Future.value(
            const UserProfileModel(
              userId: 'member',
              displayName: 'Alex',
              role: 'member',
              isCurrentUser: false,
            ),
          ),
          userBlockService: _userBlockService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Report User'), findsNothing);
  });

  testWidgets(
    'Report User appears only for another user in Community context',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: UserProfileScreen.community(
            communityId: _community.communityId,
            communityName: _community.name,
            userId: _member.userId,
            communityUserXpCache: CommunityUserXpCache(
              loadXp: (_) async => const {'member': 900},
            ),
            profileFuture: Future.value(
              const UserProfileModel(
                userId: 'member',
                displayName: 'Alex',
                role: 'member',
                isCurrentUser: false,
              ),
            ),
            activeAsksStream: Stream.value(const []),
            userBlockService: _userBlockService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Report User'), findsOneWidget);
    },
  );
}

final _userBlockService = UserBlockService.forTesting(
  currentUserId: () => 'viewer',
  repository: _NoopUserBlockRepository(),
);

class _NoopUserBlockRepository implements UserBlockRepository {
  @override
  Future<void> blockUser({
    required String blockerUserId,
    required String blockedUserId,
  }) async {}

  @override
  Stream<UserBlockModel?> blockStream({
    required String blockerUserId,
    required String blockedUserId,
  }) => Stream.value(null);

  @override
  Stream<List<UserBlockModel>> blockedUsersStream({
    required String blockerUserId,
  }) => Stream.value(const <UserBlockModel>[]);

  @override
  Future<void> unblockUser({
    required String blockerUserId,
    required String blockedUserId,
  }) async {}
}
