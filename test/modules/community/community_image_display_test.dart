import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/images/community_image_view.dart';
import 'package:gubify/modules/community/models/community_model.dart';
import 'package:gubify/modules/community/widgets/community_explorer_card.dart';

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
  });
}
