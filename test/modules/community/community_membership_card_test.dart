import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_model.dart';
import 'package:gubify/modules/community/widgets/community_membership_card.dart';
import 'package:gubify/widgets/membership_details.dart';

void main() {
  const imageUrl =
      'https://res.cloudinary.com/s3yauoza/image/upload/v8/community_abc123.jpg';
  final community = CommunityModel.fromData(
    documentId: 'abc123',
    data: {
      'communityId': 'abc123',
      'name': 'Photos',
      'ownerId': 'owner',
      'memberCount': 2,
      'imageUrl': imageUrl,
    },
  );

  testWidgets('My Communities row uses the Community image when available', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityMembershipCard(
            membership: CommunityMembershipModel(
              community: community,
              role: 'member',
              joinedAt: null,
            ),
            onTap: () {},
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).url, imageUrl);
    expect(find.byType(ClipOval), findsOneWidget);
  });

  testWidgets('My Communities row preserves the Community fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityMembershipCard(
            membership: CommunityMembershipModel(
              community: community.withoutImage(),
              role: 'owner',
              joinedAt: null,
            ),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.public_rounded), findsOneWidget);
  });

  testWidgets('Community membership card keeps readable ListTile spacing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityMembershipCard(
            membership: CommunityMembershipModel(
              community: community,
              role: 'member',
              joinedAt: null,
            ),
            onTap: () {},
          ),
        ),
      ),
    );

    final tile = tester.widget<ListTile>(find.byType(ListTile));
    expect(tile.dense, isNull);
    expect(tile.minVerticalPadding, isNull);
    expect(tile.visualDensity, isNull);
    expect(
      tile.contentPadding,
      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    );
    final subtitle = tester.widget<Padding>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Padding &&
            widget.padding == const EdgeInsets.only(top: 6) &&
            widget.child is MembershipDetails,
      ),
    );
    expect(subtitle.padding, const EdgeInsets.only(top: 6));
  });
}
