import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_leaderboard_model.dart';
import 'package:gubify/modules/community/screens/global_best_answer_ranking_screen.dart';
import 'package:gubify/screens/welcome_screen.dart';

Future<CommunityLeaderboardPage> _emptyRanking({
  Object? after,
  required int limit,
}) async => const CommunityLeaderboardPage(members: []);

Future<CommunityLeaderboardPage> _fiveRankedUsers({
  Object? after,
  required int limit,
}) async => CommunityLeaderboardPage(
  members: List.generate(
    5,
    (index) => CommunityLeaderboardMember(
      userId: 'user-$index',
      displayName: 'Ranked ${index + 1}',
      xp: 0,
      bestAnswerCount: 5 - index,
    ),
  ),
);

void main() {
  testWidgets('fits a short screen without scrolling or overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 426));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: WelcomeScreen(
          headerOverride: const SizedBox(height: 52),
          greetingOverride: const SizedBox(
            height: 31,
            child: Center(child: Text('Hi, Test')),
          ),
          globalRankingLoader: _fiveRankedUsers,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.byType(ListView), findsNothing);
    expect(find.byType(Scrollable), findsNothing);
    expect(find.text('Explore Communities'), findsNothing);
    expect(
      find.textContaining('Create your Gub or join an existing one'),
      findsNothing,
    );
    expect(find.text('Create Gub'), findsNothing);
    expect(find.byTooltip('Create Gub'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(find.text('My Gubs'), findsOneWidget);
    expect(find.text('Join a Gub'), findsOneWidget);
    expect(find.text('Learn More'), findsNothing);
    expect(find.text('Support Us'), findsNothing);
    expect(tester.takeException(), isNull);

    for (final action in [
      find.byTooltip('Create Gub'),
      find.text('My Gubs'),
      find.text('Join a Gub'),
    ]) {
      expect(tester.getBottomRight(action).dy, lessThanOrEqualTo(426));
    }
  });

  testWidgets('keeps the normal layout non-scrollable', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: WelcomeScreen(
          headerOverride: SizedBox(height: 96),
          greetingOverride: Text(
            'Hi, Test',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          globalRankingLoader: _emptyRanking,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.byType(ListView), findsNothing);
    expect(find.byType(Scrollable), findsNothing);
    expect(find.byTooltip('Create Gub'), findsOneWidget);
    expect(find.text('Create Gub'), findsNothing);

    final greetingTop = tester.getTopLeft(find.text('Hi, Test')).dy;
    final greetingBottom = tester.getBottomLeft(find.text('Hi, Test')).dy;
    final createTop = tester.getTopLeft(find.byTooltip('Create Gub')).dy;
    final createBottom = tester.getBottomLeft(find.byTooltip('Create Gub')).dy;
    final myGubsButton = find.ancestor(
      of: find.text('My Gubs'),
      matching: find.byType(OutlinedButton),
    );
    final joinButton = find.ancestor(
      of: find.text('Join a Gub'),
      matching: find.byType(OutlinedButton),
    );
    final myGubsTop = tester.getTopLeft(myGubsButton).dy;
    final myGubsBottom = tester.getBottomLeft(myGubsButton).dy;
    final joinTop = tester.getTopLeft(joinButton).dy;

    expect(greetingTop, lessThan(380));
    expect(createTop - greetingBottom, inInclusiveRange(12, 20));
    expect(myGubsTop - createBottom, inInclusiveRange(12, 18));
    expect(joinTop - myGubsBottom, inInclusiveRange(10, 14));
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact glass Create Gub action keeps the existing behavior', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var createCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: WelcomeScreen(
          headerOverride: const SizedBox(height: 52),
          greetingOverride: const SizedBox(height: 31),
          onCreateGub: () => createCalls += 1,
          globalRankingLoader: _emptyRanking,
        ),
      ),
    );

    final action = find.byKey(const Key('welcome-create-gub-glass-action'));
    expect(action, findsOneWidget);
    expect(
      find.ancestor(of: action, matching: find.byType(ClipOval)),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: action, matching: find.byType(BackdropFilter)),
      findsOneWidget,
    );
    expect(tester.getSize(action).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(action).height, greaterThanOrEqualTo(48));

    await tester.tap(find.byTooltip('Create Gub'));
    await tester.pump();

    expect(createCalls, 1);
  });

  testWidgets('shows five rankings below Join and opens the ranking page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: WelcomeScreen(
          headerOverride: const SizedBox(height: 96),
          greetingOverride: const Text('Hi, Test'),
          globalRankingLoader: _fiveRankedUsers,
          globalRankingScreenBuilder: (_) =>
              const Scaffold(body: Text('Global ranking destination')),
        ),
      ),
    );
    await tester.pump();

    final preview = find.byKey(const Key('global-best-answer-ranking-preview'));
    expect(preview, findsOneWidget);
    expect(find.text('Ranked 1'), findsOneWidget);
    expect(find.text('Ranked 5'), findsOneWidget);
    expect(
      tester.getTopLeft(preview).dy,
      greaterThan(tester.getBottomLeft(find.text('Join a Gub')).dy),
    );

    await tester.tap(preview);
    await tester.pumpAndSettle();
    expect(find.text('Global ranking destination'), findsOneWidget);
    expect(find.byType(GlobalBestAnswerRankingScreen), findsNothing);
  });
}
