import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_ask_model.dart';
import 'package:gubify/modules/community/repositories/community_profile_ask_history_repository.dart';
import 'package:gubify/modules/community/services/community_user_xp_cache.dart';
import 'package:gubify/modules/community/widgets/community_profile_asks_section.dart';

CommunityAskModel ask(String id, CommunityAskStatus status) =>
    CommunityAskModel(
      askId: id,
      communityId: 'known-community',
      authorId: 'target',
      authorDisplayName: 'Target',
      type: CommunityAskType.help,
      text: 'Ask $id',
      createdAt: Timestamp(1, 0),
      status: status,
      resolvedAt: status == CommunityAskStatus.resolved
          ? Timestamp(2, 0)
          : null,
    );

void main() {
  testWidgets('loads Active once and keeps Resolved lazy with bounded pages', (
    tester,
  ) async {
    final calls = <CommunityAskStatus>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CommunityProfileAsksSection(
              targetUserId: 'target',
              knownCommunities: const {'known-community': 'Known'},
              userXpCache: CommunityUserXpCache(
                loadXp: (_) async => const {'target': 80},
              ),
              pageLoader: ({required status, after}) async {
                calls.add(status);
                return CommunityProfileAsksPage(
                  asks: List.generate(
                    5,
                    (index) => ask('$status-$index', status),
                  ),
                  communityNames: const {'known-community': 'Known'},
                  nextCursor: const CommunityProfileAsksCursor.forTesting(
                    'next',
                  ),
                  hasMore: true,
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(calls, [CommunityAskStatus.active]);
    expect(find.text('Resolved Asks'), findsOneWidget);

    await tester.ensureVisible(find.text('Resolved Asks'));
    await tester.tap(find.text('Resolved Asks'));
    await tester.pump();
    expect(calls, [CommunityAskStatus.active, CommunityAskStatus.resolved]);
  });

  testWidgets('profile Resolved Asks has no expanded outer divider border', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityProfileAsksSection(
            targetUserId: 'target',
            knownCommunities: const {'known-community': 'Known'},
            pageLoader: ({required status, after}) async =>
                CommunityProfileAsksPage(
                  asks: const [],
                  communityNames: const {},
                  nextCursor: null,
                  hasMore: false,
                ),
          ),
        ),
      ),
    );

    final tile = tester.widget<ExpansionTile>(find.byType(ExpansionTile));
    expect(tile.shape, isA<RoundedRectangleBorder>());
    expect((tile.shape! as RoundedRectangleBorder).side, BorderSide.none);
    expect(tile.collapsedShape, isA<RoundedRectangleBorder>());
    expect(
      (tile.collapsedShape! as RoundedRectangleBorder).side,
      BorderSide.none,
    );
    expect(tile.minTileHeight, 48);
  });

  testWidgets(
    'Profile Resolved Asks keeps successful cards aligned with Active Asks',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CommunityProfileAsksSection(
                targetUserId: 'target',
                knownCommunities: const {'known-community': 'Known'},
                userXpCache: CommunityUserXpCache(
                  loadXp: (_) async => const {'target': 80},
                ),
                pageLoader: ({required status, after}) async =>
                    CommunityProfileAsksPage(
                      asks: [ask(status.name, status)],
                      communityNames: const {'known-community': 'Known'},
                      nextCursor: null,
                      hasMore: false,
                    ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Resolved Asks'));
      await tester.tap(find.text('Resolved Asks'));
      await tester.pumpAndSettle();

      expect(find.text('Try again'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Ask active')).dx,
        tester.getTopLeft(find.text('Ask resolved')).dx,
      );
    },
  );

  testWidgets(
    'Profile Resolved Asks constrains one Community context label inside its shell',
    (tester) async {
      String? openedAskId;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CommunityProfileAsksSection(
                targetUserId: 'target',
                knownCommunities: const {'known-community': 'Testcommunity'},
                userXpCache: CommunityUserXpCache(
                  loadXp: (_) async => const {'target': 80},
                ),
                detailsBuilder: (_, ask, communityName) {
                  openedAskId = ask.askId;
                  return Scaffold(body: Text('Opened ${ask.askId}'));
                },
                pageLoader: ({required status, after}) async =>
                    CommunityProfileAsksPage(
                      asks: [ask(status.name, status)],
                      communityNames: const {
                        'known-community': 'Testcommunity',
                      },
                      nextCursor: null,
                      hasMore: false,
                    ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Resolved Asks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resolved Asks'));
      await tester.pumpAndSettle();

      final contextName = find.byKey(
        const ValueKey('community-context-resolved'),
      );
      final resolvedShell = find.ancestor(
        of: find.text('Resolved Asks'),
        matching: find.byType(Card),
      );
      final activeShell = find.ancestor(
        of: find.text('Active Asks'),
        matching: find.byType(Card),
      );
      expect(contextName, findsOneWidget);
      expect(
        find.descendant(of: contextName, matching: find.text('Testcommunity')),
        findsOneWidget,
      );
      expect(
        tester.getRect(contextName).left,
        greaterThanOrEqualTo(tester.getRect(resolvedShell).left),
      );
      expect(
        tester.getRect(contextName).right,
        lessThanOrEqualTo(tester.getRect(resolvedShell).right),
      );
      expect(
        tester.getRect(resolvedShell).width,
        tester.getRect(activeShell).width,
      );
      final nameText = tester.widget<Text>(
        find.descendant(of: contextName, matching: find.byType(Text)),
      );
      expect(nameText.maxLines, 1);
      expect(nameText.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Ask resolved'));
      await tester.tap(find.text('Ask resolved'));
      await tester.pumpAndSettle();
      expect(openedAskId, 'resolved');
      expect(find.text('Opened resolved'), findsOneWidget);
    },
  );

  testWidgets('Profile Resolved Asks keeps retry action inside its card', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityProfileAsksSection(
            targetUserId: 'target',
            knownCommunities: const {'known-community': 'Known'},
            userXpCache: CommunityUserXpCache(
              loadXp: (_) async => const {'target': 80},
            ),
            pageLoader: ({required status, after}) async {
              if (status == CommunityAskStatus.resolved) {
                throw StateError('resolved failed');
              }
              return const CommunityProfileAsksPage(
                asks: [],
                communityNames: {},
                nextCursor: null,
                hasMore: false,
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Resolved Asks'));
    await tester.pumpAndSettle();

    final retry = find.text('Try again');
    final outerCard = find.ancestor(
      of: find.text('Resolved Asks'),
      matching: find.byType(Card),
    );
    expect(retry, findsOneWidget);
    expect(
      tester.getTopLeft(retry).dx,
      greaterThan(tester.getTopLeft(outerCard).dx + 12),
    );
  });
}
