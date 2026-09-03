import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_model.dart';
import 'package:gubify/modules/community/widgets/community_create_ask_card.dart';
import 'package:gubify/modules/community/widgets/community_home_content.dart';

const community = CommunityModel(
  communityId: 'community-1',
  name: 'Flutter Friends',
  ownerId: 'owner',
  memberCount: 4,
  visibility: CommunityModel.publicVisibility,
  createdAt: null,
  type: CommunityModel.defaultType,
  language: CommunityModel.defaultLanguage,
  description: '',
  accessMode: CommunityModel.openAccessMode,
);

Widget _home({
  VoidCallback? onOpenAsks,
  VoidCallback? onOpenResolvedAsks,
  VoidCallback? onOpenMyAsks,
  CommunityDirectAskSubmit? onCreateDirectAsk,
}) => MaterialApp(
  home: Scaffold(
    body: CommunityHomeContent(
      community: community,
      isKeyboardOpen: false,
      isOwner: false,
      onOpenAsks: onOpenAsks,
      onOpenResolvedAsks: onOpenResolvedAsks,
      onOpenMyAsks: onOpenMyAsks,
      onCreateDirectAsk: onCreateDirectAsk,
      chatView: const ColoredBox(color: Colors.white),
    ),
  ),
);

void main() {
  testWidgets('compact Community and Asks circles toggle exclusive panels', (
    tester,
  ) async {
    await tester.pumpWidget(_home());

    expect(
      find.byKey(const ValueKey('community-header-action')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('asks-header-action')), findsOneWidget);
    expect(find.byKey(const ValueKey('my-asks-header-action')), findsOneWidget);
    expect(find.text('4 members'), findsNothing);
    expect(find.text('Tap to view'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('community-header-action')));
    await tester.pump();
    expect(find.text('4 members'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('community-header-action')));
    await tester.pump();
    expect(find.text('4 members'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('asks-header-action')));
    await tester.pump();
    expect(find.text('Active Asks'), findsOneWidget);
    expect(find.text('Resolved Asks'), findsOneWidget);
    expect(find.text('Tap to view'), findsNWidgets(2));
    expect(find.text('4 members'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('community-header-action')));
    await tester.pump();
    expect(find.text('4 members'), findsOneWidget);
    expect(find.text('Active Asks'), findsNothing);
    expect(find.text('Resolved Asks'), findsNothing);
  });

  testWidgets('My Asks action opens the current-user bounded history', (
    tester,
  ) async {
    var opens = 0;
    await tester.pumpWidget(_home(onOpenMyAsks: () => opens++));

    await tester.tap(find.byKey(const ValueKey('my-asks-header-action')));
    await tester.pump();

    expect(opens, 1);
  });

  testWidgets('Asks circle toggles summary and only the card opens the board', (
    tester,
  ) async {
    var opens = 0;
    await tester.pumpWidget(_home(onOpenAsks: () => opens++));

    await tester.tap(find.byKey(const ValueKey('asks-header-action')));
    await tester.pump();
    expect(opens, 0);
    expect(find.text('Active Asks'), findsOneWidget);
    expect(find.text('Resolved Asks'), findsOneWidget);
    expect(find.text('Tap to view'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('asks-header-action')));
    await tester.pump();
    expect(find.text('Active Asks'), findsNothing);
    expect(find.text('Resolved Asks'), findsNothing);
    expect(opens, 0);

    await tester.tap(find.byKey(const ValueKey('asks-header-action')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('active-asks-summary-card')));
    await tester.pump();
    expect(opens, 1);
  });

  testWidgets('both static Ask cards open their corresponding flows', (
    tester,
  ) async {
    var activeOpens = 0;
    var resolvedOpens = 0;
    await tester.pumpWidget(
      _home(
        onOpenAsks: () => activeOpens++,
        onOpenResolvedAsks: () => resolvedOpens++,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('asks-header-action')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('active-asks-summary-card')));
    await tester.tap(find.byKey(const ValueKey('resolved-asks-summary-card')));

    expect(activeOpens, 1);
    expect(resolvedOpens, 1);
  });

  testWidgets(
    'compact header fits a phone viewport without layout exceptions',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_home());
      await tester.tap(find.byKey(const ValueKey('asks-header-action')));
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Asks summary has no active-count status', (tester) async {
    await tester.pumpWidget(_home());
    await tester.tap(find.byKey(const ValueKey('asks-header-action')));
    await tester.pump();

    expect(find.text('Active Asks'), findsOneWidget);
    expect(find.text('Resolved Asks'), findsOneWidget);
    expect(find.text('Tap to view'), findsNWidgets(2));
    expect(find.textContaining('ask active'), findsNothing);
    expect(find.text('Loading active asks…'), findsNothing);
  });

  testWidgets('Create circle toggles its card and excludes other panels', (
    tester,
  ) async {
    await tester.pumpWidget(
      _home(onCreateDirectAsk: ({required text, required type}) async {}),
    );

    expect(
      find.byKey(const ValueKey('create-ask-header-action')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('community-header-action')));
    await tester.pump();
    expect(find.text('4 members'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('create-ask-header-action')));
    await tester.pump();
    expect(find.byType(CommunityCreateAskCard), findsOneWidget);
    expect(find.text('4 members'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('asks-header-action')));
    await tester.pump();
    expect(find.byType(CommunityCreateAskCard), findsNothing);
    expect(find.text('Active Asks'), findsOneWidget);
    expect(find.text('Resolved Asks'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('create-ask-header-action')));
    await tester.pump();
    expect(find.byType(CommunityCreateAskCard), findsOneWidget);
    expect(find.text('Active Asks'), findsNothing);
    expect(find.text('Resolved Asks'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('create-ask-header-action')));
    await tester.pump();
    expect(find.byType(CommunityCreateAskCard), findsNothing);
  });

  testWidgets('successful Direct Ask closes card and shows feedback', (
    tester,
  ) async {
    await tester.pumpWidget(
      _home(onCreateDirectAsk: ({required text, required type}) async {}),
    );
    await tester.tap(find.byKey(const ValueKey('create-ask-header-action')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('create-ask-text')),
      'A useful question',
    );
    await tester.tap(find.byKey(const ValueKey('create-ask-type-help')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('create-ask-submit')));
    await tester.pumpAndSettle();

    expect(find.byType(CommunityCreateAskCard), findsNothing);
    expect(find.text('Ask created.'), findsOneWidget);
  });
}
