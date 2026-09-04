import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_ask_model.dart';
import 'package:gubify/modules/community/services/community_user_xp_cache.dart';
import 'package:gubify/modules/moderation/blocking/models/user_block_model.dart';
import 'package:gubify/modules/moderation/blocking/repositories/user_block_repository.dart';
import 'package:gubify/modules/moderation/blocking/screens/blocked_users_screen.dart';
import 'package:gubify/modules/moderation/blocking/services/user_block_service.dart';
import 'package:gubify/modules/profile/models/user_profile_model.dart';
import 'package:gubify/modules/profile/screens/user_profile_screen.dart';

void main() {
  testWidgets('other private Gub profile changes from Block User to Blocked', (
    tester,
  ) async {
    final repository = _FakeRepository();
    final service = _service(repository);
    await tester.pumpWidget(
      MaterialApp(
        home: UserProfileScreen(
          gubId: 'gub-a',
          userId: 'user-b',
          userBlockService: service,
          profileFuture: Future.value(_otherProfile),
        ),
      ),
    );
    await tester.pump();
    repository.emitBlock(null);
    await tester.pump();

    expect(find.text('Block User'), findsOneWidget);
    await tester.tap(find.text('Block User'));
    await tester.pumpAndSettle();
    expect(find.text('Block User?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Block'));
    await tester.pumpAndSettle();

    expect(repository.blockCalls, [('user-a', 'user-b')]);
    expect(find.text('Blocked'), findsOneWidget);
  });

  testWidgets('other Community profile uses the same global block state', (
    tester,
  ) async {
    final repository = _FakeRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: UserProfileScreen.community(
          communityId: 'community-a',
          communityName: 'Community',
          userId: 'user-b',
          userBlockService: _service(repository),
          profileFuture: Future.value(_otherProfile),
          activeAsksStream: Stream.value(const <CommunityAskModel>[]),
          communityUserXpCache: CommunityUserXpCache(
            loadXp: (_) async => const {'user-b': 0},
          ),
        ),
      ),
    );
    await tester.pump();
    repository.emitBlock(null);
    await tester.pumpAndSettle();

    expect(find.text('Block User'), findsOneWidget);
  });

  testWidgets('self profile has no block control', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UserProfileScreen(
          gubId: 'gub-a',
          userId: 'user-a',
          userBlockService: _service(_FakeRepository()),
          profileFuture: Future.value(
            const UserProfileModel(
              userId: 'user-a',
              displayName: 'A',
              isCurrentUser: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Block User'), findsNothing);
    expect(find.text('Blocked'), findsNothing);
  });

  testWidgets(
    'blocked users screen loads names and unblocks after confirmation',
    (tester) async {
      final repository = _FakeRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: BlockedUsersScreen(
            service: _service(repository),
            loadUser: (_) async => {'displayName': 'Blocked person'},
          ),
        ),
      );
      await tester.pump();
      repository.emitList([
        UserBlockModel(
          blockedUserId: 'user-b',
          blockedAt: Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
        ),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('Blocked person'), findsOneWidget);
      await tester.tap(find.text('Unblock'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Unblock'));
      await tester.pumpAndSettle();

      expect(repository.unblockCalls, [('user-a', 'user-b')]);
    },
  );
}

const _otherProfile = UserProfileModel(
  userId: 'user-b',
  displayName: 'B',
  isCurrentUser: false,
);

UserBlockService _service(_FakeRepository repository) =>
    UserBlockService.forTesting(
      currentUserId: () => 'user-a',
      repository: repository,
    );

class _FakeRepository implements UserBlockRepository {
  final _blocks = StreamController<UserBlockModel?>.broadcast();
  final _list = StreamController<List<UserBlockModel>>.broadcast();
  final blockCalls = <(String, String)>[];
  final unblockCalls = <(String, String)>[];

  void emitBlock(UserBlockModel? block) => _blocks.add(block);
  void emitList(List<UserBlockModel> blocks) => _list.add(blocks);

  @override
  Future<void> blockUser({
    required String blockerUserId,
    required String blockedUserId,
  }) async {
    blockCalls.add((blockerUserId, blockedUserId));
    emitBlock(UserBlockModel(blockedUserId: blockedUserId, blockedAt: null));
  }

  @override
  Stream<UserBlockModel?> blockStream({
    required String blockerUserId,
    required String blockedUserId,
  }) => _blocks.stream;

  @override
  Stream<List<UserBlockModel>> blockedUsersStream({
    required String blockerUserId,
  }) => _list.stream;

  @override
  Future<void> unblockUser({
    required String blockerUserId,
    required String blockedUserId,
  }) async => unblockCalls.add((blockerUserId, blockedUserId));
}
