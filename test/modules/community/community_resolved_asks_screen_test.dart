import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:gubify/modules/community/models/community_ask_model.dart';
import 'package:gubify/modules/community/repositories/community_ask_repository.dart';
import 'package:gubify/modules/community/screens/community_resolved_asks_screen.dart';
import 'package:gubify/modules/community/services/community_user_xp_cache.dart';

final _xpCache = CommunityUserXpCache(loadXp: (_) async => const {});

CommunityAskModel _resolvedAsk(String id, int seconds) => CommunityAskModel(
  askId: id,
  communityId: 'community-1',
  authorId: 'author-$id',
  authorDisplayName: 'Author $id',
  type: CommunityAskType.help,
  text: 'Resolved ask $id',
  createdAt: Timestamp(seconds - 1, 0),
  status: CommunityAskStatus.resolved,
  resolvedAt: Timestamp(seconds, 0),
  bestAnswerId: 'answer-$id',
  bestAnswerAuthorId: 'answerer-$id',
  xpAwarded: true,
);

Widget _screen({
  required Future<CommunityResolvedAsksPage> Function(
    CommunityResolvedAsksCursor? after,
  )
  pageLoader,
  CommunityUserXpCache? membershipXpCache,
}) => MaterialApp(
  home: CommunityResolvedAsksScreen(
    communityId: 'community-1',
    communityName: 'Community',
    pageLoader: pageLoader,
    membershipXpCache: membershipXpCache ?? _xpCache,
  ),
);

void main() {
  testWidgets('resolved Ask card renders the shared author level', (
    tester,
  ) async {
    final levelCache = CommunityUserXpCache(
      loadXp: (_) async => const {'author-0': 640},
    );
    await tester.pumpWidget(
      _screen(
        membershipXpCache: levelCache,
        pageLoader: (_) async => CommunityResolvedAsksPage(
          asks: [_resolvedAsk('0', 50)],
          nextCursor: null,
          hasMore: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lv 8'), findsOneWidget);
  });

  testWidgets('loads only the first five resolved Asks initially', (
    tester,
  ) async {
    final firstPage = List.generate(
      5,
      (index) => _resolvedAsk('$index', 50 - index),
    );
    var loads = 0;
    await tester.pumpWidget(
      _screen(
        pageLoader: (after) async {
          loads++;
          expect(after, isNull);
          return CommunityResolvedAsksPage(
            asks: firstPage,
            nextCursor: const CommunityResolvedAsksCursor.forTesting('first'),
            hasMore: true,
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(loads, 1);
    expect(find.text('Try again'), findsNothing);
    expect(find.text('Resolved ask 0'), findsOneWidget);
    expect(find.text('Resolved ask 4'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Load 5 more'), 200);
    expect(find.text('Load 5 more'), findsOneWidget);
  });

  testWidgets(
    'Load 5 more appends one cursor page without reloading prior Asks',
    (tester) async {
      final firstPage = List.generate(
        5,
        (index) => _resolvedAsk('$index', 50 - index),
      );
      final secondPage = [_resolvedAsk('5', 45), _resolvedAsk('6', 44)];
      const firstPageCursor = CommunityResolvedAsksCursor.forTesting('first');
      final cursors = <CommunityResolvedAsksCursor?>[];
      await tester.pumpWidget(
        _screen(
          pageLoader: (after) async {
            cursors.add(after);
            return cursors.length == 1
                ? CommunityResolvedAsksPage(
                    asks: firstPage,
                    nextCursor: firstPageCursor,
                    hasMore: true,
                  )
                : CommunityResolvedAsksPage(
                    asks: secondPage,
                    nextCursor: const CommunityResolvedAsksCursor.forTesting(
                      'second',
                    ),
                    hasMore: false,
                  );
          },
        ),
      );
      await tester.pumpAndSettle();
      final loadMore = find.text('Load 5 more');
      await tester.scrollUntilVisible(loadMore, 200);
      await tester.tap(loadMore);
      await tester.pumpAndSettle();

      expect(cursors, hasLength(2));
      expect(cursors.first, isNull);
      expect(identical(cursors.last, firstPageCursor), isTrue);
      await tester.scrollUntilVisible(find.text('Resolved ask 6'), 200);
      expect(find.text('Resolved ask 6'), findsOneWidget);
      expect(find.text('Load 5 more'), findsNothing);
    },
  );

  testWidgets('empty first page shows the resolved Ask empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _screen(
        pageLoader: (after) async => const CommunityResolvedAsksPage(
          asks: [],
          nextCursor: null,
          hasMore: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No resolved Asks yet'), findsOneWidget);
    expect(find.text('Load 5 more'), findsNothing);
  });
}
