import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_leaderboard_model.dart';
import 'package:gubify/modules/community/screens/community_leaderboard_screen.dart';
import 'package:gubify/modules/community/services/community_user_xp_cache.dart';

const _members = <CommunityLeaderboardMember>[
  CommunityLeaderboardMember(
    userId: 'u1',
    displayName: 'Gold',
    xp: 640,
    bestAnswerCount: 7,
  ),
  CommunityLeaderboardMember(
    userId: 'u2',
    displayName: 'Silver',
    xp: 300,
    bestAnswerCount: 4,
  ),
  CommunityLeaderboardMember(
    userId: 'u3',
    displayName: 'Bronze',
    xp: 100,
    bestAnswerCount: 2,
  ),
  CommunityLeaderboardMember(
    userId: 'u4',
    displayName: 'Fourth',
    xp: 20,
    bestAnswerCount: 1,
  ),
  CommunityLeaderboardMember(
    userId: 'u5',
    displayName: 'Fifth',
    xp: 0,
    bestAnswerCount: 1,
  ),
];

void main() {
  testWidgets('shows exactly Top Level and Top Answers with podium trophies', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityLeaderboardScreen(
          communityId: 'c1',
          communityName: 'Community',
          userXpCache: CommunityUserXpCache(loadXp: (_) async => const {}),
          loadTopLevel: ({after, required limit}) async =>
              CommunityLeaderboardPage(
                members: _members,
                nextCursor: 'level-page-1',
                hasMore: true,
              ),
          loadTopAnswers: ({after, required limit}) async =>
              const CommunityLeaderboardPage(members: []),
          profileBuilder: (_, member) => Text('Profile ${member.userId}'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Top Level'), findsOneWidget);
    expect(find.text('Top Answers'), findsOneWidget);
    expect(find.byType(Tab), findsNWidgets(2));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/backgrounds/background_leaderboard.png',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('leaderboard-trophy-gold')), findsOneWidget);
    expect(find.byKey(const ValueKey('leaderboard-trophy-silver')), findsOneWidget);
    expect(find.byKey(const ValueKey('leaderboard-trophy-bronze')), findsOneWidget);
    expect(find.text('Lv 8'), findsWidgets);
  });

  testWidgets('loads five more once and caps the leaderboard at ten', (
    tester,
  ) async {
    final calls = <Object?>[];
    final secondPage = List.generate(
      5,
      (index) => CommunityLeaderboardMember(
        userId: 'next-$index',
        displayName: 'Next $index',
        xp: 10 - index,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityLeaderboardScreen(
          communityId: 'c1',
          communityName: 'Community',
          userXpCache: CommunityUserXpCache(loadXp: (_) async => const {}),
          loadTopLevel: ({after, required limit}) async {
            calls.add(after);
            return after == null
                ? const CommunityLeaderboardPage(
                    members: _members,
                    nextCursor: 'page-1',
                    hasMore: true,
                  )
                : CommunityLeaderboardPage(
                    members: secondPage,
                    nextCursor: 'page-2',
                    hasMore: true,
                  );
          },
          loadTopAnswers: ({after, required limit}) async =>
              const CommunityLeaderboardPage(members: []),
          profileBuilder: (_, member) => Text('Profile ${member.userId}'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final loadMore = find.text('Load 5 more');
    await tester.ensureVisible(loadMore);
    await tester.tap(loadMore);
    await tester.pumpAndSettle();

    expect(calls, <Object?>[null, 'page-1']);
    expect(find.text('Load 5 more'), findsNothing);
  });

  testWidgets('Top Answers uses Best Answer grammar and opens existing profile', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityLeaderboardScreen(
          communityId: 'c1',
          communityName: 'Community',
          userXpCache: CommunityUserXpCache(loadXp: (_) async => const {}),
          loadTopLevel: ({after, required limit}) async =>
              const CommunityLeaderboardPage(members: []),
          loadTopAnswers: ({after, required limit}) async =>
              const CommunityLeaderboardPage(
                members: [
                  CommunityLeaderboardMember(
                    userId: 'u1',
                    displayName: 'One',
                    xp: 40,
                    bestAnswerCount: 1,
                  ),
                ],
              ),
          profileBuilder: (_, member) => Text('Profile ${member.userId}'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Top Answers'));
    await tester.pumpAndSettle();
    expect(find.text('1 Best Answer'), findsOneWidget);
    await tester.tap(find.text('One'));
    await tester.pumpAndSettle();
    expect(find.text('Profile u1'), findsOneWidget);
  });

  testWidgets('current user live XP cache update is reflected without a listener', (
    tester,
  ) async {
    final cache = CommunityUserXpCache(loadXp: (_) async => const {});
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityLeaderboardScreen(
          communityId: 'c1',
          communityName: 'Community',
          userXpCache: cache,
          loadTopLevel: ({after, required limit}) async =>
              const CommunityLeaderboardPage(
                members: [
                  CommunityLeaderboardMember(
                    userId: 'u1',
                    displayName: 'Live',
                    xp: 40,
                  ),
                ],
              ),
          loadTopAnswers: ({after, required limit}) async =>
              const CommunityLeaderboardPage(members: []),
          profileBuilder: (_, member) => Text('Profile ${member.userId}'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lv 2 · 40 XP'), findsOneWidget);

    cache.applyCurrentUserXp('u1', 60);
    await tester.pumpAndSettle();
    expect(find.text('Lv 3 · 60 XP'), findsOneWidget);
  });
}
