import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_model.dart';
import 'package:gubify/modules/community/widgets/community_home_content.dart';
import 'package:gubify/widgets/gub_content_card.dart';

const _community = CommunityModel(
  communityId: 'community-1',
  name: 'Cafe Test',
  ownerId: 'owner',
  memberCount: 2,
  visibility: CommunityModel.publicVisibility,
  createdAt: null,
  type: CommunityModel.defaultType,
  language: CommunityModel.defaultLanguage,
  description: '',
  accessMode: CommunityModel.openAccessMode,
);

const _communityWithSlug = CommunityModel(
  communityId: 'community-1',
  name: 'Cafe Test',
  ownerId: 'owner',
  memberCount: 2,
  visibility: CommunityModel.publicVisibility,
  createdAt: null,
  type: CommunityModel.defaultType,
  language: CommunityModel.defaultLanguage,
  description: '',
  accessMode: CommunityModel.openAccessMode,
  slug: 'cafe-test',
);

void main() {
  testWidgets('Community Home shows Web for a Community with a valid slug', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CommunityHomeContent(
            community: _communityWithSlug,
            isKeyboardOpen: false,
            isOwner: false,
            chatView: SizedBox(),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('web-header-action')), findsOneWidget);
    expect(find.text('Web'), findsOneWidget);
    expect(find.byIcon(Icons.language_rounded), findsOneWidget);
  });

  testWidgets('Web opens the canonical public Community URL externally', (
    tester,
  ) async {
    Uri? launchedUri;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityHomeContent(
            community: _communityWithSlug,
            isKeyboardOpen: false,
            isOwner: false,
            launchExternalUrl: (uri) async {
              launchedUri = uri;
              return true;
            },
            chatView: const SizedBox(),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('web-header-action')));
    await tester.pump();

    expect(launchedUri, Uri.parse('https://gubify.com/community/cafe-test'));
  });

  testWidgets('Web is absent for a Community without a valid slug', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CommunityHomeContent(
            community: CommunityModel(
              communityId: 'legacy-community',
              name: 'Legacy Community',
              ownerId: 'owner',
              memberCount: 2,
              visibility: CommunityModel.publicVisibility,
              createdAt: null,
              type: CommunityModel.defaultType,
              language: CommunityModel.defaultLanguage,
              description: '',
              accessMode: CommunityModel.openAccessMode,
              slug: 'not a valid slug',
            ),
            isKeyboardOpen: false,
            isOwner: false,
            chatView: SizedBox(),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('web-header-action')), findsNothing);
  });

  testWidgets('Web failure shows feedback without crashing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityHomeContent(
            community: _communityWithSlug,
            isKeyboardOpen: false,
            isOwner: false,
            launchExternalUrl: (_) async => false,
            chatView: const SizedBox(),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('web-header-action')));
    await tester.pump();

    expect(find.text('Unable to open Community page.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('six Home actions fit a narrow phone viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CommunityHomeContent(
            community: _communityWithSlug,
            isKeyboardOpen: false,
            isOwner: false,
            chatView: SizedBox(),
          ),
        ),
      ),
    );

    for (final key in const [
      'community-header-action',
      'asks-header-action',
      'my-asks-header-action',
      'create-ask-header-action',
      'leaderboard-header-action',
      'web-header-action',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Community Home opens Leaderboard from its circular action', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityHomeContent(
            community: _community,
            isKeyboardOpen: false,
            isOwner: false,
            chatView: const SizedBox(),
            onOpenLeaderboard: () => opened = true,
          ),
        ),
      ),
    );

    expect(find.text('Leaderboard'), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('leaderboard-header-action')));
    expect(opened, isTrue);
  });

  testWidgets('compact Home header has avatar, member count and role only', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CommunityHomeContent(
            community: _community,
            isKeyboardOpen: false,
            isOwner: false,
            chatView: SizedBox(),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('community-header-action')));
    await tester.pump();

    expect(find.byType(ClipOval), findsNWidgets(2));
    expect(find.byIcon(Icons.public_rounded), findsNWidgets(2));
    expect(find.text('2 members'), findsOneWidget);
    expect(find.text('Member'), findsOneWidget);
    expect(find.text('Public community'), findsNothing);
    expect(find.byType(Wrap), findsNothing);
  });

  testWidgets('Home card keeps its compact fixed height for long names', (
    tester,
  ) async {
    const longName =
        'A Community name intentionally long enough to require scaling';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: CommunityHomeContent(
              community: CommunityModel(
                communityId: 'community-1',
                name: longName,
                ownerId: 'owner',
                memberCount: 1200,
                visibility: CommunityModel.publicVisibility,
                createdAt: null,
                type: CommunityModel.defaultType,
                language: CommunityModel.defaultLanguage,
                description: '',
                accessMode: CommunityModel.openAccessMode,
              ),
              isKeyboardOpen: false,
              isOwner: true,
              chatView: SizedBox(),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('community-header-action')));
    await tester.pump();

    expect(tester.getSize(find.byType(GubContentCard)).height, 84);
    expect(find.byType(Wrap), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long Community name stays on one scale-down line', (
    tester,
  ) async {
    const longName =
        'A Community name intentionally long enough to require scaling';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: CommunityHomeContent(
              community: CommunityModel(
                communityId: 'community-1',
                name: longName,
                ownerId: 'owner',
                memberCount: 1,
                visibility: CommunityModel.publicVisibility,
                createdAt: null,
                type: CommunityModel.defaultType,
                language: CommunityModel.defaultLanguage,
                description: '',
                accessMode: CommunityModel.openAccessMode,
              ),
              isKeyboardOpen: false,
              isOwner: true,
              chatView: SizedBox(),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('community-header-action')));
    await tester.pump();

    final name = tester.widget<Text>(find.text(longName));
    expect(name.maxLines, 1);
    expect(
      find.ancestor(of: find.text(longName), matching: find.byType(FittedBox)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home header renders the current Community image', (
    tester,
  ) async {
    const imageUrl =
        'https://res.cloudinary.com/s3yauoza/image/upload/v8/community_community-1.jpg';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityHomeContent(
            community: _community.copyWith(
              imageUrl: imageUrl,
              imagePublicId: 'community_community-1',
              imageVersion: 8,
            ),
            isKeyboardOpen: false,
            isOwner: false,
            chatView: const SizedBox(),
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is NetworkImage &&
            (widget.image as NetworkImage).url == imageUrl,
      ),
    );
    expect((image.image as NetworkImage).url, imageUrl);
    expect(find.byType(ClipOval), findsOneWidget);
  });
}
