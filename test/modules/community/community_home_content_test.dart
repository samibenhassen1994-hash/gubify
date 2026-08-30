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

void main() {
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
