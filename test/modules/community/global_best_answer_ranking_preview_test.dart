import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_leaderboard_model.dart';
import 'package:gubify/modules/community/widgets/global_best_answer_ranking_preview.dart';

void main() {
  testWidgets('loads only the global top five once and is fully tappable', (
    tester,
  ) async {
    var calls = 0;
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GlobalBestAnswerRankingPreview(
            loadPage: ({after, required limit}) async {
              calls += 1;
              expect(after, isNull);
              expect(limit, 5);
              return CommunityLeaderboardPage(
                members: List.generate(
                  5,
                  (index) => CommunityLeaderboardMember(
                    userId: 'u$index',
                    displayName: 'User ${index + 1}',
                    xp: 0,
                    bestAnswerCount: 5 - index,
                  ),
                ),
              );
            },
            onTap: () => tapped += 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('User 1'), findsOneWidget);
    expect(find.text('User 5'), findsOneWidget);
    expect(find.byIcon(Icons.workspace_premium), findsNWidgets(3));
    expect(find.text('#4'), findsOneWidget);
    expect(find.text('#5'), findsOneWidget);
    expect(find.text('View Top 100'), findsOneWidget);

    final title = tester.widget<Text>(find.text('Best Answer Ranking'));
    expect(title.textAlign, TextAlign.center);
    final subtitle = tester.widget<Text>(
      find.text('Top 5 across all communities'),
    );
    expect(subtitle.textAlign, TextAlign.center);

    final name = tester.widget<Text>(find.text('User 1'));
    final count = tester.widget<Text>(find.text('5'));
    expect(name.maxLines, 1);
    expect(name.style!.fontSize, 16);
    expect(name.style!.fontWeight, FontWeight.w700);
    expect(name.textAlign, TextAlign.center);
    expect(count.style!.fontSize, 10);
    expect(name.style!.fontSize, greaterThan(count.style!.fontSize!));
    final firstGroup = find.byKey(const Key('global-ranking-main-group-0'));
    final firstRow = find.byKey(const Key('global-ranking-row-0'));
    expect(firstGroup, findsOneWidget);
    expect(
      (tester.getCenter(firstGroup).dx - tester.getCenter(firstRow).dx).abs(),
      lessThanOrEqualTo(1),
    );
    expect(
      find.descendant(
        of: firstGroup,
        matching: find.byIcon(Icons.workspace_premium),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: firstGroup, matching: find.byType(CircleAvatar)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: firstGroup, matching: find.text('User 1')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('global-best-answer-ranking-preview')),
    );
    expect(tapped, 1);
  });

  testWidgets('places a single ranked user immediately below the subtitle', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GlobalBestAnswerRankingPreview(
            loadPage: ({after, required limit}) async =>
                const CommunityLeaderboardPage(
                  members: [
                    CommunityLeaderboardMember(
                      userId: 'user-1',
                      displayName: 'Only User',
                      xp: 0,
                      bestAnswerCount: 1,
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final subtitle = find.text('Top 5 across all communities');
    final user = find.text('Only User');
    expect(
      tester.getTopLeft(user).dy - tester.getBottomLeft(subtitle).dy,
      lessThanOrEqualTo(16),
    );
    expect(find.text('View Top 100'), findsOneWidget);

    final group = find.byKey(const Key('global-ranking-main-group-0'));
    final row = find.byKey(const Key('global-ranking-row-0'));
    expect(
      (tester.getCenter(group).dx - tester.getCenter(row).dx).abs(),
      lessThanOrEqualTo(1),
    );
  });

  testWidgets('fits the centered ranking groups in a 320px viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 426));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GlobalBestAnswerRankingPreview(
            compact: true,
            loadPage: ({after, required limit}) async =>
                CommunityLeaderboardPage(
                  members: List.generate(
                    5,
                    (index) => CommunityLeaderboardMember(
                      userId: 'user-$index',
                      displayName:
                          'A deliberately long display name ${index + 1}',
                      xp: 0,
                      bestAnswerCount: 5 - index,
                    ),
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('View Top 100'), findsOneWidget);
    for (var index = 0; index < 5; index++) {
      final group = find.byKey(Key('global-ranking-main-group-$index'));
      final row = find.byKey(Key('global-ranking-row-$index'));
      expect(
        (tester.getCenter(group).dx - tester.getCenter(row).dx).abs(),
        lessThanOrEqualTo(1),
      );
    }
  });
}
