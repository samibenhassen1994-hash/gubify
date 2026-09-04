import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_ask_model.dart';
import 'package:gubify/modules/community/repositories/community_ask_repository.dart';
import 'package:gubify/modules/community/screens/community_my_asks_screen.dart';
import 'package:gubify/modules/community/services/community_user_xp_cache.dart';

CommunityAskModel _ask(CommunityAskStatus status) => CommunityAskModel(
  askId: status.value,
  communityId: 'community-1',
  authorId: 'me',
  authorDisplayName: 'Me',
  type: CommunityAskType.help,
  text: '${status.value} question',
  createdAt: Timestamp(1, 0),
  status: status,
  resolvedAt: status == CommunityAskStatus.resolved ? Timestamp(2, 0) : null,
);

void main() {
  testWidgets('loads Active automatically and Resolved only when opened', (
    tester,
  ) async {
    final calls = <CommunityAskStatus>[];
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityMyAsksScreen(
          communityId: 'community-1',
          communityName: 'Community',
          userXpCache: CommunityUserXpCache(
            loadXp: (_) async => const {'me': 0},
          ),
          pageLoader: ({required status, after}) async {
            calls.add(status);
            return CommunityUserAsksPage(
              asks: [_ask(status)],
              nextCursor: null,
              hasMore: false,
            );
          },
        ),
      ),
    );
    await tester.pump();

    expect(calls, [CommunityAskStatus.active]);
    expect(find.text('active question'), findsOneWidget);

    await tester.tap(find.text('Resolved Asks'));
    await tester.pump();
    expect(calls, [CommunityAskStatus.active, CommunityAskStatus.resolved]);
  });

  testWidgets('Resolved Asks has no expanded outer divider border', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityMyAsksScreen(
          communityId: 'community-1',
          communityName: 'Community',
          pageLoader: ({required status, after}) async => CommunityUserAsksPage(
            asks: const [],
            nextCursor: null,
            hasMore: false,
          ),
        ),
      ),
    );

    final tile = tester.widget<ExpansionTile>(
      find.byKey(const ValueKey('my-resolved-asks-section')),
    );
    expect(tile.shape, isA<RoundedRectangleBorder>());
    expect((tile.shape! as RoundedRectangleBorder).side, BorderSide.none);
    expect(tile.collapsedShape, isA<RoundedRectangleBorder>());
    expect(
      (tile.collapsedShape! as RoundedRectangleBorder).side,
      BorderSide.none,
    );
  });
}
