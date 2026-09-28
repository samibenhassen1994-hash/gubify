import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_model.dart';
import 'package:gubify/modules/community/repositories/community_repository.dart';
import 'package:gubify/modules/community/screens/community_explorer_screen.dart';
import 'package:gubify/modules/community/widgets/community_explorer_card.dart';

CommunityModel community(String id, {String? name, String? accessMode}) =>
    CommunityModel(
      communityId: id,
      name: name ?? 'Community $id',
      ownerId: 'owner',
      memberCount: 1,
      visibility: CommunityModel.publicVisibility,
      createdAt: null,
      type: CommunityModel.defaultType,
      language: CommunityModel.defaultLanguage,
      description: '',
      accessMode: accessMode ?? CommunityModel.openAccessMode,
    );

Widget explorer(CommunityExplorerPageLoader loader) => MaterialApp(
  home: CommunityExplorerScreen(
    pageLoader: loader,
    discoveryFilter: (communities) async => communities,
    joinedCommunityIdsStream: Stream.value(const <String>{}),
    isAnonymous: () => false,
    isOwner: (_) => false,
  ),
);

Widget searchableExplorer(
  CommunityExplorerSearchPageLoader loader, {
  CommunityDiscoveryFilter? discoveryFilter,
}) => MaterialApp(
  home: CommunityExplorerScreen(
    searchPageLoader: loader,
    discoveryFilter: discoveryFilter ?? (communities) async => communities,
    joinedCommunityIdsStream: Stream.value(const <String>{}),
    isAnonymous: () => false,
    isOwner: (_) => false,
  ),
);

void main() {
  testWidgets('loads the first page once when Explore opens', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      explorer((_) async {
        calls++;
        return const CommunityExplorerPage(
          communities: [],
          nextCursor: null,
          hasMore: false,
        );
      }),
    );
    await tester.pumpAndSettle();

    expect(calls, 1);
  });

  testWidgets('pull-to-refresh reloads the first page with new Communities', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      explorer((_) async {
        calls++;
        return CommunityExplorerPage(
          communities: calls == 1
              ? [community('old', name: 'Old Community')]
              : [
                  community(
                    'approval',
                    name: 'Approval Required Community',
                    accessMode: CommunityModel.approvalAccessMode,
                  ),
                ],
          nextCursor: null,
          hasMore: false,
        );
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('Old Community'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 350));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Approval Required Community'), findsOneWidget);
    expect(find.text('Old Community'), findsNothing);
  });

  testWidgets(
    'limits a page to ten cards and keeps Open and Approval visible',
    (tester) async {
      final communities = [
        community('open', name: 'Open Community'),
        community(
          'approval',
          name: 'Approval Required Community',
          accessMode: CommunityModel.approvalAccessMode,
        ),
        for (var index = 2; index < 12; index++) community('$index'),
      ];
      await tester.pumpWidget(
        explorer(
          (_) async => CommunityExplorerPage(
            communities: communities,
            nextCursor: null,
            hasMore: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Open Community'), findsOneWidget);
      expect(find.text('Approval Required Community'), findsOneWidget);
      final list = tester.widget<ListView>(find.byType(ListView));
      final cards = (list.childrenDelegate as SliverChildListDelegate).children
          .whereType<CommunityExplorerCard>();
      expect(cards, hasLength(10));
    },
  );

  testWidgets('Next and Previous replace the page without duplicates', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      explorer((after) async {
        calls++;
        if (calls == 1 || calls == 3) {
          return CommunityExplorerPage(
            communities: [community('one', name: 'First page')],
            nextCursor: const CommunityExplorerCursor.forTesting(),
            hasMore: true,
          );
        }
        return CommunityExplorerPage(
          communities: [community('two', name: 'Second page')],
          nextCursor: null,
          hasMore: false,
        );
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('Page 1'), findsOneWidget);
    expect(find.text('First page'), findsOneWidget);
    await tester.tap(find.byKey(const Key('community-explorer-next-page')));
    await tester.pumpAndSettle();

    expect(find.text('Page 2'), findsOneWidget);
    expect(find.text('Second page'), findsOneWidget);
    expect(find.text('First page'), findsNothing);
    await tester.tap(find.byKey(const Key('community-explorer-previous-page')));
    await tester.pumpAndSettle();

    expect(find.text('Page 1'), findsOneWidget);
    expect(find.text('First page'), findsOneWidget);
    expect(find.text('Second page'), findsNothing);
    expect(calls, 3);
  });

  testWidgets('typing search text does not invoke another page load', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      explorer((_) async {
        calls++;
        return CommunityExplorerPage(
          communities: [community('open', name: 'Open Community')],
          nextCursor: null,
          hasMore: false,
        );
      }),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(SearchBar), 'Open');
    await tester.pump();

    expect(calls, 1);
    expect(find.text('Open Community'), findsOneWidget);
  });

  testWidgets('global search finds a Community outside the browse page', (
    tester,
  ) async {
    final requestedSearchKeys = <String>[];
    await tester.pumpWidget(
      searchableExplorer((after, searchKey) async {
        requestedSearchKeys.add(searchKey);
        if (searchKey.isEmpty) {
          return CommunityExplorerPage(
            communities: [community('browse', name: 'Browse Community')],
            nextCursor: null,
            hasMore: false,
          );
        }
        return CommunityExplorerPage(
          communities: [
            community('remote-open', name: 'Remote Open Community'),
            community(
              'remote-approval',
              name: 'Remote Approval Community',
              accessMode: CommunityModel.approvalAccessMode,
            ),
          ],
          nextCursor: null,
          hasMore: false,
        );
      }),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(SearchBar), 'Remote');
    await tester.pump(const Duration(milliseconds: 499));
    expect(requestedSearchKeys, ['']);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    expect(requestedSearchKeys, ['', 'remote']);
    expect(find.text('Remote Approval Community'), findsOneWidget);
    expect(find.text('Remote Open Community'), findsOneWidget);
    expect(find.text('Browse Community'), findsNothing);
  });

  testWidgets('global search keeps restricted Communities out of results', (
    tester,
  ) async {
    await tester.pumpWidget(
      searchableExplorer(
        (_, searchKey) async => CommunityExplorerPage(
          communities: [
            community('visible', name: 'Visible Search Community'),
            community('hidden', name: 'Restricted Search Community'),
          ],
          nextCursor: null,
          hasMore: false,
        ),
        discoveryFilter: (communities) async => communities
            .where((community) => community.communityId != 'hidden')
            .toList(growable: false),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(SearchBar), 'Search');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Visible Search Community'), findsOneWidget);
    expect(find.text('Restricted Search Community'), findsNothing);
  });

  testWidgets('search pagination returns to the prior search page', (
    tester,
  ) async {
    const searchCursor = CommunityExplorerCursor.forTesting();
    var searchCalls = 0;
    await tester.pumpWidget(
      searchableExplorer((after, searchKey) async {
        if (searchKey.isEmpty) {
          return const CommunityExplorerPage(
            communities: [],
            nextCursor: null,
            hasMore: false,
          );
        }
        searchCalls++;
        return switch (searchCalls) {
          1 || 3 => CommunityExplorerPage(
            communities: [community('first', name: 'Search page one')],
            nextCursor: searchCursor,
            hasMore: true,
          ),
          _ => CommunityExplorerPage(
            communities: [community('second', name: 'Search page two')],
            nextCursor: null,
            hasMore: false,
          ),
        };
      }),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(SearchBar), 'Search');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('community-explorer-next-page')));
    await tester.pumpAndSettle();

    expect(find.text('Search page two'), findsOneWidget);
    await tester.tap(find.byKey(const Key('community-explorer-previous-page')));
    await tester.pumpAndSettle();
    expect(find.text('Search page one'), findsOneWidget);
  });

  testWidgets(
    'same normalized query is not requested twice and clearing resets browse',
    (tester) async {
      final requestedSearchKeys = <String>[];
      await tester.pumpWidget(
        searchableExplorer((_, searchKey) async {
          requestedSearchKeys.add(searchKey);
          return CommunityExplorerPage(
            communities: [community(searchKey.isEmpty ? 'browse' : 'query')],
            nextCursor: null,
            hasMore: false,
          );
        }),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(SearchBar), 'Test');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.enterText(find.byType(SearchBar), 'Test ');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(requestedSearchKeys, ['', 'test']);

      await tester.enterText(find.byType(SearchBar), '');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(requestedSearchKeys, ['', 'test', '']);
      expect(find.text('Page 1'), findsOneWidget);
    },
  );
}
