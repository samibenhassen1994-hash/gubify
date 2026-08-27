import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/images/community_image_view.dart';
import 'package:gubify/modules/community/models/community_model.dart';
import 'package:gubify/modules/community/widgets/community_explorer_card.dart';
import 'package:gubify/widgets/gub_content_card.dart';

const _imageUrl =
    'https://res.cloudinary.com/s3yauoza/image/upload/v8/community_abc123.jpg';

void main() {
  testWidgets('missing Community image uses the public icon fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: CommunityImageView(imageUrl: null, size: 80)),
    );

    expect(find.byIcon(Icons.public_rounded), findsOneWidget);
  });

  testWidgets('Explorer card renders the current Community image URL', (
    tester,
  ) async {
    const community = CommunityModel(
      communityId: 'abc123',
      name: 'Photos',
      ownerId: 'owner',
      memberCount: 1,
      visibility: CommunityModel.publicVisibility,
      createdAt: null,
      type: 'Art & Creativity',
      language: 'English',
      description: '',
      accessMode: CommunityModel.openAccessMode,
      imageUrl: _imageUrl,
      imagePublicId: 'community_abc123',
      imageVersion: 8,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityExplorerCard(
            community: community,
            isJoined: false,
            onOpen: () {},
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).url, _imageUrl);
    expect(find.byType(ClipOval), findsOneWidget);
  });

  testWidgets('Explorer card preserves the Community fallback', (tester) async {
    const community = CommunityModel(
      communityId: 'abc123',
      name: 'Photos',
      ownerId: 'owner',
      memberCount: 1,
      visibility: CommunityModel.publicVisibility,
      createdAt: null,
      type: 'Art & Creativity',
      language: 'English',
      description: '',
      accessMode: CommunityModel.openAccessMode,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityExplorerCard(
            community: community,
            isJoined: false,
            onOpen: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.public_rounded), findsOneWidget);
    expect(find.byType(ClipOval), findsOneWidget);
  });

  testWidgets('Explorer keeps a long Community name readable on up to two lines', (
    tester,
  ) async {
    const longName =
        'A Community name intentionally long enough to require scaling';
    const community = CommunityModel(
      communityId: 'abc123',
      name: longName,
      ownerId: 'owner',
      memberCount: 1,
      visibility: CommunityModel.publicVisibility,
      createdAt: null,
      type: 'Art & Creativity',
      language: 'English',
      description: '',
      accessMode: CommunityModel.openAccessMode,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: CommunityExplorerCard(
              community: community,
              isJoined: false,
              onOpen: () {},
            ),
          ),
        ),
      ),
    );

    final name = tester.widget<Text>(find.text(longName));
    expect(name.maxLines, 2);
    expect(name.overflow, TextOverflow.ellipsis);
    expect(name.style?.fontSize, 19);
    expect(find.byType(FittedBox), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Explorer long name does not increase card height', (
    tester,
  ) async {
    const shortCommunity = CommunityModel(
      communityId: 'short',
      name: 'Cafe Test',
      ownerId: 'owner',
      memberCount: 1,
      visibility: CommunityModel.publicVisibility,
      createdAt: null,
      type: 'Art & Creativity',
      language: 'English',
      description: '',
      accessMode: CommunityModel.openAccessMode,
    );
    const longCommunity = CommunityModel(
      communityId: 'long',
      name: 'A Community name intentionally long enough to require scaling',
      ownerId: 'owner',
      memberCount: 1,
      visibility: CommunityModel.publicVisibility,
      createdAt: null,
      type: 'Art & Creativity',
      language: 'English',
      description: '',
      accessMode: CommunityModel.openAccessMode,
    );

    Future<void> pumpCard(CommunityModel community) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: CommunityExplorerCard(
              community: community,
              isJoined: false,
              onOpen: () {},
            ),
          ),
        ),
      ),
    );

    await pumpCard(shortCommunity);
    final shortHeight = tester.getSize(find.byType(GubContentCard)).height;

    await pumpCard(longCommunity);
    final longHeight = tester.getSize(find.byType(GubContentCard)).height;

    expect(longHeight, shortHeight);
  });
}
