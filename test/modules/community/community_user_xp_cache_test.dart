import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/leveling/community_level.dart';
import 'package:gubify/modules/community/models/community_ask_answer_model.dart';
import 'package:gubify/modules/community/models/community_ask_model.dart';
import 'package:gubify/modules/community/repositories/community_ask_answer_repository.dart';
import 'package:gubify/modules/community/services/community_ask_answer_service.dart';
import 'package:gubify/modules/community/services/community_ask_service.dart';
import 'package:gubify/modules/community/services/community_user_xp_cache.dart';
import 'package:gubify/modules/community/widgets/community_user_xp_scope.dart';

void main() {
  test(
    'deduplicates overlapping UID loads and evicts after final release',
    () async {
      final load = Completer<Map<String, int>>();
      var calls = 0;
      final cache = CommunityUserXpCache(
        loadXp: (userIds) {
          calls++;
          expect(userIds, {'user-1', 'user-2'});
          return load.future;
        },
      );

      final first = cache.acquire({'user-1', 'user-2'});
      final second = cache.acquire({'user-2'});
      addTearDown(first.release);
      addTearDown(second.release);

      final firstValue = first.stream.firstWhere((value) => value.length == 2);
      final secondValue = second.stream.firstWhere(valueContainsUser2);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);

      load.complete({'user-1': 640});
      expect(await firstValue, {'user-1': 640, 'user-2': 0});
      expect(await secondValue, {'user-2': 0});

      await first.release();
      expect(cache.cachedUserCount, 1);
      await second.release();
      expect(cache.cachedUserCount, 0);
    },
  );

  test('prime publishes transaction XP without another load', () async {
    var calls = 0;
    final cache = CommunityUserXpCache(
      loadXp: (_) async {
        calls++;
        return {'winner': 100};
      },
    );
    final lease = cache.acquire({'winner'});
    addTearDown(lease.release);
    await lease.stream.firstWhere((value) => value['winner'] == 100);

    final primed = lease.stream.firstWhere((value) => value['winner'] == 120);
    cache.prime({'winner': 120});

    expect(await primed, {'winner': 120});
    expect(calls, 1);
  });

  test(
    'authoritative reward survives an older in-flight load for all consumers',
    () async {
      final load = Completer<Map<String, int>>();
      var calls = 0;
      final cache = CommunityUserXpCache(
        loadXp: (_) {
          calls++;
          return load.future;
        },
      );
      final first = cache.acquire({'winner', 'asker'});
      final second = cache.acquire({'winner', 'asker'});
      final firstValues = <Map<String, int>>[];
      final secondValues = <Map<String, int>>[];
      final firstSubscription = first.stream.listen(firstValues.add);
      final secondSubscription = second.stream.listen(secondValues.add);
      addTearDown(firstSubscription.cancel);
      addTearDown(secondSubscription.cancel);
      addTearDown(first.release);
      addTearDown(second.release);
      await Future<void>.delayed(Duration.zero);

      cache.prime({'winner': 60, 'asker': 12});
      await Future<void>.delayed(Duration.zero);
      expect(firstValues.last, {'winner': 60, 'asker': 12});
      expect(secondValues.last, {'winner': 60, 'asker': 12});

      load.complete({'winner': 40, 'asker': 10});
      await load.future;
      await Future<void>.delayed(Duration.zero);

      expect(firstValues.last, {'winner': 60, 'asker': 12});
      expect(secondValues.last, {'winner': 60, 'asker': 12});
      expect(calls, 1);

      final later = cache.acquire({'winner', 'asker'});
      addTearDown(later.release);
      expect(await later.stream.first, {'winner': 60, 'asker': 12});
      expect(calls, 1);
    },
  );

  test('reward primed before acquisition avoids a Firestore load', () async {
    var calls = 0;
    final cache = CommunityUserXpCache(
      loadXp: (_) async {
        calls++;
        return {'winner': 40};
      },
    );

    cache.prime({'winner': 60});
    final lease = cache.acquire({'winner'});
    addTearDown(lease.release);

    expect(await lease.stream.first, {'winner': 60});
    expect(calls, 0);

    await lease.release();
    expect(cache.cachedUserCount, 0);
  });

  test('a later lease replays the cached XP without loading again', () async {
    var calls = 0;
    final cache = CommunityUserXpCache(
      loadXp: (_) async {
        calls++;
        return {'member': 80};
      },
    );
    final first = cache.acquire({'member'});
    addTearDown(first.release);
    await first.stream.firstWhere((value) => value['member'] == 80);

    final second = cache.acquire({'member'});
    addTearDown(second.release);

    expect(await second.stream.first, {'member': 80});
    expect(calls, 1);
  });

  testWidgets(
    'Best Answer reward updates two mounted consumers from the shared cache',
    (tester) async {
      var loads = 0;
      final cache = CommunityUserXpCache(
        loadXp: (_) async {
          loads++;
          return const {'winner': 40, 'asker': 10};
        },
      );
      final service = CommunityAskAnswerService.forTesting(
        currentAccount: () =>
            const CommunityAskAccount(userId: 'asker', isAnonymous: false),
        currentDisplayName: () async => 'Asker',
        createAnswer:
            ({
              required communityId,
              required askId,
              required authorId,
              required askAuthorId,
              required authorDisplayName,
              required answerText,
            }) async => CommunityAnswerCreateResult.created,
        resolveAsk:
            ({
              required communityId,
              required askId,
              required answerId,
              required resolverId,
            }) async => const CommunityAskResolution(
              result: CommunityAskResolveResult.resolved,
              xpByUserId: {'winner': 60, 'asker': 12},
            ),
        primeXp: cache.prime,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              CommunityUserXpScope(
                cache: cache,
                userIds: const {'winner', 'asker'},
                builder: (_, xp) => Text(
                  'chat winner Lv ${CommunityLevel.fromXp(xp['winner'] ?? 0).level}',
                ),
              ),
              CommunityUserXpScope(
                cache: cache,
                userIds: const {'winner', 'asker'},
                builder: (_, xp) => Text(
                  'profile winner Lv ${CommunityLevel.fromXp(xp['winner'] ?? 0).level} '
                  'asker XP ${xp['asker'] ?? 0}',
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('chat winner Lv 2'), findsOneWidget);
      expect(find.text('profile winner Lv 2 asker XP 10'), findsOneWidget);

      await service.selectBestAnswer(
        ask: CommunityAskModel(
          askId: 'ask-1',
          communityId: 'community-1',
          authorId: 'asker',
          authorDisplayName: 'Asker',
          type: CommunityAskType.help,
          text: 'Question',
          createdAt: Timestamp(1, 0),
          status: CommunityAskStatus.active,
        ),
        answer: CommunityAskAnswerModel(
          answerId: 'winner',
          authorId: 'winner',
          authorDisplayName: 'Winner',
          text: 'Answer',
          createdAt: Timestamp(2, 0),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('chat winner Lv 3'), findsOneWidget);
      expect(find.text('profile winner Lv 3 asker XP 12'), findsOneWidget);
      expect(loads, 1);
    },
  );
}

bool valueContainsUser2(Map<String, int> value) => value.containsKey('user-2');
