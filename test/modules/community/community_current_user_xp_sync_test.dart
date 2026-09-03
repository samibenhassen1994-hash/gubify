import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/services/community_current_user_xp_sync.dart';
import 'package:gubify/modules/community/services/community_user_xp_cache.dart';
import 'package:gubify/modules/community/widgets/community_user_xp_scope.dart';

void main() {
  test(
    'starts one XP listener when the same anonymous UID becomes linked',
    () async {
      final accounts = StreamController<CommunityCurrentUserAccount?>.broadcast(
        sync: true,
      );
      final progress = _FakeProgressSource();
      final cache = CommunityUserXpCache(loadXp: (_) async => {});
      CommunityCurrentUserAccount? current = const CommunityCurrentUserAccount(
        userId: 'user-a',
        isAnonymous: true,
      );
      final sync = CommunityCurrentUserXpSync(
        currentAccount: () => current,
        accountChanges: () => accounts.stream,
        watchUserXp: progress.watch,
        cache: cache,
      );
      addTearDown(accounts.close);
      addTearDown(sync.dispose);

      await sync.start();
      expect(progress.watchCalls, 0);

      current = const CommunityCurrentUserAccount(
        userId: 'user-a',
        isAnonymous: false,
      );
      accounts.add(current);
      await sync.pendingTransitions;

      expect(progress.watchCalls, 1);
      expect(progress.watchedUserIds, ['user-a']);
    },
  );

  test(
    'shares one current-user listener, updates the cache, and cancels it',
    () async {
      final accounts = StreamController<CommunityCurrentUserAccount?>.broadcast(
        sync: true,
      );
      final progress = _FakeProgressSource();
      final cache = CommunityUserXpCache(loadXp: (_) async => {});
      final current = const CommunityCurrentUserAccount(
        userId: 'user-a',
        isAnonymous: false,
      );
      final sync = CommunityCurrentUserXpSync(
        currentAccount: () => current,
        accountChanges: () => accounts.stream,
        watchUserXp: progress.watch,
        cache: cache,
      );
      final lease = cache.acquire({'user-a'});
      addTearDown(accounts.close);
      addTearDown(lease.release);
      addTearDown(sync.dispose);

      await sync.start();
      await sync.start();
      expect(progress.watchCalls, 1);

      final update = lease.stream.firstWhere((xp) => xp['user-a'] == 60);
      progress.add('user-a', 60);
      expect(await update, {'user-a': 60});

      await sync.dispose();
      expect(progress.cancelledUserIds, ['user-a']);
    },
  );

  test(
    'cancels the old UID and ignores emissions after an account switch',
    () async {
      final accounts = StreamController<CommunityCurrentUserAccount?>.broadcast(
        sync: true,
      );
      final progress = _FakeProgressSource();
      final cache = CommunityUserXpCache(loadXp: (_) async => {});
      CommunityCurrentUserAccount? current = const CommunityCurrentUserAccount(
        userId: 'user-a',
        isAnonymous: false,
      );
      final sync = CommunityCurrentUserXpSync(
        currentAccount: () => current,
        accountChanges: () => accounts.stream,
        watchUserXp: progress.watch,
        cache: cache,
      );
      final lease = cache.acquire({'user-a', 'user-b'});
      addTearDown(accounts.close);
      addTearDown(lease.release);
      addTearDown(sync.dispose);

      await sync.start();
      progress.add('user-a', 40);
      await lease.stream.firstWhere((xp) => xp['user-a'] == 40);

      current = const CommunityCurrentUserAccount(
        userId: 'user-b',
        isAnonymous: false,
      );
      await sync.refresh();
      expect(progress.cancelledUserIds, ['user-a']);
      expect(progress.watchedUserIds, ['user-a', 'user-b']);

      final userBUpdate = lease.stream.firstWhere((xp) => xp['user-b'] == 60);
      progress.add('user-a', 999);
      progress.add('user-b', 60);
      final latest = await userBUpdate;
      expect(latest['user-a'], 40);
      expect(latest['user-b'], 60);
    },
  );

  test(
    'uses zero XP for a missing progress document and stops for logout',
    () async {
      final accounts = StreamController<CommunityCurrentUserAccount?>.broadcast(
        sync: true,
      );
      final progress = _FakeProgressSource();
      final cache = CommunityUserXpCache(loadXp: (_) async => {});
      CommunityCurrentUserAccount? current = const CommunityCurrentUserAccount(
        userId: 'user-a',
        isAnonymous: false,
      );
      final sync = CommunityCurrentUserXpSync(
        currentAccount: () => current,
        accountChanges: () => accounts.stream,
        watchUserXp: progress.watch,
        cache: cache,
      );
      final lease = cache.acquire({'user-a'});
      addTearDown(accounts.close);
      addTearDown(lease.release);
      addTearDown(sync.dispose);

      await sync.start();
      final zero = lease.stream.firstWhere((xp) => xp['user-a'] == 0);
      progress.add('user-a', 0);
      expect(await zero, {'user-a': 0});

      current = null;
      await sync.refresh();
      expect(progress.cancelledUserIds, ['user-a']);
    },
  );

  test(
    'does not regress a local reward while an older listener update arrives',
    () async {
      final accounts = StreamController<CommunityCurrentUserAccount?>.broadcast(
        sync: true,
      );
      final progress = _FakeProgressSource();
      final cache = CommunityUserXpCache(loadXp: (_) async => {});
      final current = const CommunityCurrentUserAccount(
        userId: 'user-a',
        isAnonymous: false,
      );
      final sync = CommunityCurrentUserXpSync(
        currentAccount: () => current,
        accountChanges: () => accounts.stream,
        watchUserXp: progress.watch,
        cache: cache,
      );
      final lease = cache.acquire({'user-a'});
      addTearDown(accounts.close);
      addTearDown(lease.release);
      addTearDown(sync.dispose);

      await sync.start();
      progress.add('user-a', 40);
      await lease.stream.firstWhere((xp) => xp['user-a'] == 40);

      cache.prime({'user-a': 60});
      await lease.stream.firstWhere((xp) => xp['user-a'] == 60);
      final retained = lease.stream.firstWhere((xp) => xp['user-a'] == 60);
      progress.add('user-a', 40);
      await Future<void>.delayed(Duration.zero);
      progress.add('user-a', 60);

      expect(await retained, {'user-a': 60});
    },
  );

  testWidgets('remote XP updates two mounted Community consumers', (
    tester,
  ) async {
    final accounts = StreamController<CommunityCurrentUserAccount?>.broadcast(
      sync: true,
    );
    final progress = _FakeProgressSource();
    final cache = CommunityUserXpCache(loadXp: (_) async => {});
    final sync = CommunityCurrentUserXpSync(
      currentAccount: () => const CommunityCurrentUserAccount(
        userId: 'user-a',
        isAnonymous: false,
      ),
      accountChanges: () => accounts.stream,
      watchUserXp: progress.watch,
      cache: cache,
    );
    addTearDown(accounts.close);
    addTearDown(sync.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            CommunityUserXpScope(
              cache: cache,
              userIds: const {'user-a', 'other-user'},
              builder: (_, xp) => Text('chat ${xp['user-a'] ?? 0}'),
            ),
            CommunityUserXpScope(
              cache: cache,
              userIds: const {'user-a', 'other-user'},
              builder: (_, xp) => Text('asks ${xp['user-a'] ?? 0}'),
            ),
          ],
        ),
      ),
    );
    await sync.start();
    expect(progress.watchCalls, 1);
    expect(progress.watchedUserIds, ['user-a']);

    progress.add('user-a', 40);
    await tester.pump();
    expect(find.text('chat 40'), findsOneWidget);
    expect(find.text('asks 40'), findsOneWidget);

    progress.add('user-a', 60);
    await tester.pumpAndSettle();
    expect(find.text('chat 60'), findsOneWidget);
    expect(find.text('asks 60'), findsOneWidget);
  });
}

class _FakeProgressSource {
  final Map<String, StreamController<int>> _controllers = {};
  final List<String> watchedUserIds = [];
  final List<String> cancelledUserIds = [];

  int get watchCalls => watchedUserIds.length;

  Stream<int> watch(String userId) {
    watchedUserIds.add(userId);
    return (_controllers[userId] ??= StreamController<int>.broadcast(
      sync: true,
      onCancel: () => cancelledUserIds.add(userId),
    )).stream;
  }

  void add(String userId, int xp) => _controllers[userId]!.add(xp);
}
