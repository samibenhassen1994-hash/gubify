import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_ask_model.dart';
import 'package:gubify/modules/community/screens/community_ask_details_screen.dart';
import 'package:gubify/modules/community/screens/community_asks_screen.dart';
import 'package:gubify/modules/community/services/community_user_xp_cache.dart';

final _xpCache = CommunityUserXpCache(loadXp: (_) async => const {});

CommunityAskModel _ask(
  String id,
  CommunityAskType type, {
  CommunityAskStatus status = CommunityAskStatus.active,
}) => CommunityAskModel(
  askId: id,
  communityId: 'community-1',
  authorId: 'author-$id',
  authorDisplayName: 'Author $id',
  type: type,
  sourceMessageId: id,
  text: 'Preview $id',
  createdAt: Timestamp.fromMillisecondsSinceEpoch(type.index + 1),
  status: status,
);

Widget _board(
  List<CommunityAskModel> asks, {
  Widget Function(BuildContext context, CommunityAskModel ask)? detailsBuilder,
  CommunityUserXpCache? membershipXpCache,
}) => MaterialApp(
  home: CommunityAsksScreen(
    communityId: 'community-1',
    communityName: 'Flutter Friends',
    asksStream: Stream.value(asks),
    detailsBuilder: detailsBuilder,
    membershipXpCache: membershipXpCache ?? _xpCache,
  ),
);

void main() {
  testWidgets(
    'active Ask card renders a level from the shared membership map',
    (tester) async {
      final levelCache = CommunityUserXpCache(
        loadXp: (_) async => const {'author-help': 640},
      );
      await tester.pumpWidget(
        _board([
          _ask('help', CommunityAskType.help),
        ], membershipXpCache: levelCache),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lv 8'), findsOneWidget);
    },
  );

  testWidgets('board shows all active asks and filters one shared stream', (
    tester,
  ) async {
    await tester.pumpWidget(
      _board([
        _ask('help', CommunityAskType.help),
        _ask('information', CommunityAskType.information),
        _ask('advice', CommunityAskType.advice),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Preview help'), findsOneWidget);
    expect(find.text('Preview information'), findsOneWidget);
    expect(find.text('Preview advice'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ask-filter-help')));
    await tester.pump();
    expect(find.text('Preview help'), findsOneWidget);
    expect(find.text('Preview information'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('ask-filter-information')));
    await tester.pump();
    expect(find.text('Preview information'), findsOneWidget);
    expect(find.text('Preview help'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('ask-filter-advice')));
    await tester.pump();
    expect(find.text('Preview advice'), findsOneWidget);
    expect(find.text('Preview information'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('ask-filter-all')));
    await tester.pump();
    expect(find.textContaining('Preview '), findsNWidgets(3));
  });

  testWidgets('ask card opens details with the selected data', (tester) async {
    await tester.pumpWidget(
      _board(
        [_ask('help', CommunityAskType.help)],
        detailsBuilder: (context, ask) => CommunityAskDetailsScreen(
          ask: ask,
          communityName: 'Flutter Friends',
          askStream: Stream.value(ask),
          answersStream: Stream.value(const []),
          currentUserId: 'viewer',
          membershipXpCache: _xpCache,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ask-card-help')));
    await tester.pumpAndSettle();

    expect(find.byType(CommunityAskDetailsScreen), findsOneWidget);
    expect(find.text('Ask'), findsOneWidget);
    expect(find.text('Author help'), findsOneWidget);
    expect(find.text('Preview help'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('board has distinct all and filtered empty states', (
    tester,
  ) async {
    await tester.pumpWidget(_board(const []));
    await tester.pumpAndSettle();

    expect(find.text('No active asks'), findsOneWidget);
    expect(
      find.text('Asks created by community members will appear here.'),
      findsOneWidget,
    );

    await tester.pumpWidget(_board([_ask('help', CommunityAskType.help)]));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ask-filter-advice')));
    await tester.pump();
    expect(find.text('No Advice asks'), findsOneWidget);
  });

  testWidgets('board excludes resolved asks from the active list', (
    tester,
  ) async {
    await tester.pumpWidget(
      _board([
        _ask('active', CommunityAskType.help),
        _ask(
          'resolved',
          CommunityAskType.advice,
          status: CommunityAskStatus.resolved,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Preview active'), findsOneWidget);
    expect(find.text('Preview resolved'), findsNothing);
  });

  testWidgets('board fits a phone viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_board([_ask('help', CommunityAskType.help)]));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
