import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_leaderboard_model.dart';
import 'package:gubify/modules/community/screens/global_best_answer_ranking_screen.dart';

CommunityLeaderboardMember member(int index) => CommunityLeaderboardMember(
  userId: 'u$index',
  displayName: 'User $index',
  xp: 0,
  bestAnswerCount: 100 - index,
);

void main() {
  testWidgets('loads ten at a time only on request and uses the cursor', (
    tester,
  ) async {
    final cursors = <Object?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: GlobalBestAnswerRankingScreen(
          loadPage: ({after, required limit}) async {
            expect(limit, 10);
            cursors.add(after);
            final start = cursors.length == 1 ? 1 : 11;
            return CommunityLeaderboardPage(
              members: List.generate(10, (i) => member(start + i)),
              nextCursor: 'page-${cursors.length}',
              hasMore: true,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(cursors, [null]);
    expect(find.text('Answers'), findsOneWidget);
    expect(find.byIcon(Icons.workspace_premium), findsNWidgets(3));
    expect(find.text('#4'), findsOneWidget);

    final name = tester.widget<Text>(find.text('User 1'));
    final count = tester.widget<Text>(find.text('99 Best Answers'));
    expect(name.style!.fontSize, 18);
    expect(name.style!.fontSize, greaterThan(count.style!.fontSize!));
    expect(name.style!.fontWeight, FontWeight.w700);
    await tester.scrollUntilVisible(
      find.text('Load 10 more'),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('Load 10 more'));
    await tester.pumpAndSettle();

    expect(cursors, [null, 'page-1']);
    await tester.scrollUntilVisible(
      find.text('#20'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('#20'), findsOneWidget);
  });

  testWidgets('a short page ends pagination without another fetch', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GlobalBestAnswerRankingScreen(
          loadPage: ({after, required limit}) async {
            calls += 1;
            return CommunityLeaderboardPage(
              members: List.generate(4, (index) => member(index + 1)),
              nextCursor: 'unused',
              hasMore: true,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('Load 10 more'), findsNothing);
  });

  testWidgets('never renders more than the top one hundred', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GlobalBestAnswerRankingScreen(
          loadPage: ({after, required limit}) async => CommunityLeaderboardPage(
            members: List.generate(105, (index) => member(index + 1)),
            nextCursor: 'unused',
            hasMore: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('#101'), findsNothing);
    expect(find.text('Load 10 more'), findsNothing);
  });

  testWidgets('each new screen instance performs a fresh initial fetch', (
    tester,
  ) async {
    var calls = 0;
    Future<CommunityLeaderboardPage> load({
      Object? after,
      required int limit,
    }) async {
      calls += 1;
      return const CommunityLeaderboardPage(members: []);
    }

    await tester.pumpWidget(
      MaterialApp(home: GlobalBestAnswerRankingScreen(loadPage: load)),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(home: GlobalBestAnswerRankingScreen(loadPage: load)),
    );
    await tester.pumpAndSettle();

    expect(calls, 2);
  });

  testWidgets('shows retry after an initial error', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GlobalBestAnswerRankingScreen(
          loadPage: ({after, required limit}) async {
            if (calls++ == 0) throw Exception('failed');
            return const CommunityLeaderboardPage(members: []);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No rankings yet.'), findsOneWidget);
  });
}
