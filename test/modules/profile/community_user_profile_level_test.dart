import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_ask_model.dart';
import 'package:gubify/modules/community/services/community_user_xp_cache.dart';
import 'package:gubify/modules/moderation/blocking/models/user_block_model.dart';
import 'package:gubify/modules/moderation/blocking/repositories/user_block_repository.dart';
import 'package:gubify/modules/moderation/blocking/services/user_block_service.dart';
import 'package:gubify/modules/profile/models/user_profile_model.dart';
import 'package:gubify/modules/profile/screens/user_profile_screen.dart';

void main() {
  testWidgets('Community profile shows the derived level and recognition', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UserProfileScreen.community(
          communityId: 'community-1',
          communityName: 'Community',
          userId: 'member-1',
          communityUserXpCache: CommunityUserXpCache(
            loadXp: (_) async => const {'member-1': 3800},
          ),
          profileFuture: Future.value(
            const UserProfileModel(
              userId: 'member-1',
              displayName: 'Alex',
              role: 'member',
              communityXp: 3800,
              isCurrentUser: false,
            ),
          ),
          activeAsksStream: Stream.value(const <CommunityAskModel>[]),
          userBlockService: _userBlockService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lv 20'), findsOneWidget);
    expect(find.text('Level 20'), findsOneWidget);
    expect(find.text('Community Legend'), findsOneWidget);
    expect(find.text('3800+ XP'), findsOneWidget);
    expect(find.textContaining('Max level'), findsOneWidget);
  });

  testWidgets('Community profile shows the XP progress inside a strong bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UserProfileScreen.community(
          communityId: 'community-1',
          communityName: 'Community',
          userId: 'member-1',
          communityUserXpCache: CommunityUserXpCache(
            loadXp: (_) async => const {'member-1': 640},
          ),
          profileFuture: Future.value(
            const UserProfileModel(
              userId: 'member-1',
              displayName: 'Alex',
              role: 'member',
              communityXp: 640,
              isCurrentUser: false,
            ),
          ),
          activeAsksStream: Stream.value(const <CommunityAskModel>[]),
          userBlockService: _userBlockService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('80 / 160 XP'), findsOneWidget);
    expect(find.text('50% to Level 9'), findsOneWidget);
  });

  testWidgets(
    'mounted Community profile rebuilds from authoritative reward XP',
    (tester) async {
      var loads = 0;
      final cache = CommunityUserXpCache(
        loadXp: (_) async {
          loads++;
          return const {'member-1': 40};
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: UserProfileScreen.community(
            communityId: 'community-1',
            communityName: 'Community',
            userId: 'member-1',
            communityUserXpCache: cache,
            profileFuture: Future.value(
              const UserProfileModel(
                userId: 'member-1',
                displayName: 'Alex',
                role: 'member',
                isCurrentUser: false,
              ),
            ),
            activeAsksStream: Stream.value(const <CommunityAskModel>[]),
            userBlockService: _userBlockService,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lv 2'), findsOneWidget);

      cache.prime(const {'member-1': 60});
      await tester.pumpAndSettle();

      expect(find.text('Lv 3'), findsOneWidget);
      expect(find.text('Lv 2'), findsNothing);
      expect(loads, 1);
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
