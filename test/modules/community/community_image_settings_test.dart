import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/images/community_image_settings_card.dart';
import 'package:gubify/modules/community/models/community_model.dart';

const _community = CommunityModel(
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

void main() {
  testWidgets('owner image card shows Add image without metadata', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityImageSettingsCard(
            community: _community,
            onUpload: (_) async => null,
          ),
        ),
      ),
    );

    expect(find.text('Community image'), findsOneWidget);
    expect(find.text('Add image'), findsOneWidget);
    expect(find.text('Remove image'), findsNothing);
    expect(find.byIcon(Icons.public_rounded), findsOneWidget);
    expect(find.byType(ClipOval), findsOneWidget);
  });

  testWidgets('non-owner image management renders no controls', (tester) async {
    final withImage = _community.copyWith(
      imageUrl:
          'https://res.cloudinary.com/s3yauoza/image/upload/v2/community_abc123.jpg',
      imagePublicId: 'community_abc123',
      imageVersion: 2,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityImageManagementSection(
            isOwner: false,
            community: withImage,
          ),
        ),
      ),
    );

    expect(find.text('Community image'), findsNothing);
    expect(find.text('Add image'), findsNothing);
    expect(find.text('Remove image'), findsNothing);
  });

  testWidgets('owner image card shows Change image for existing metadata', (
    tester,
  ) async {
    final withImage = _community.copyWith(
      imageUrl:
          'https://res.cloudinary.com/s3yauoza/image/upload/v2/community_abc123.jpg',
      imagePublicId: 'community_abc123',
      imageVersion: 2,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityImageSettingsCard(
            community: withImage,
            onUpload: (_) async => null,
          ),
        ),
      ),
    );

    expect(find.text('Change image'), findsOneWidget);
    expect(find.text('Remove image'), findsOneWidget);
    expect(find.text('Add image'), findsNothing);
    expect(find.byType(ClipOval), findsOneWidget);
  });

  testWidgets('Remove image asks for confirmation and publishes cleared state', (
    tester,
  ) async {
    final withImage = _community.copyWith(
      imageUrl:
          'https://res.cloudinary.com/s3yauoza/image/upload/v2/community_abc123.jpg',
      imagePublicId: 'community_abc123',
      imageVersion: 2,
    );
    CommunityModel? published;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityImageSettingsCard(
            community: withImage,
            onUpload: (_) async => null,
            onRemove: (_) async => withImage.withoutImage(),
            onUpdated: (value) => published = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Remove image'));
    await tester.pump();
    expect(find.text('Remove Community image?'), findsOneWidget);
    expect(
      find.text('The current Community image will be removed.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(published?.imageUrl, isNull);
    expect(find.text('Community image removed.'), findsOneWidget);
  });

  testWidgets('one pending image operation disables Change and Remove', (
    tester,
  ) async {
    final completer = Completer<CommunityModel>();
    var removeCalls = 0;
    final withImage = _community.copyWith(
      imageUrl:
          'https://res.cloudinary.com/s3yauoza/image/upload/v2/community_abc123.jpg',
      imagePublicId: 'community_abc123',
      imageVersion: 2,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityImageSettingsCard(
            community: withImage,
            onUpload: (_) async => null,
            onRemove: (_) {
              removeCalls++;
              return completer.future;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Remove image'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
    await tester.pump();

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Remove image'));
    await tester.pump();
    expect(removeCalls, 1);
    completer.complete(withImage.withoutImage());
    await tester.pump();
  });

  testWidgets('upload action is disabled while an upload is pending', (
    tester,
  ) async {
    final completer = Completer<CommunityModel?>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityImageSettingsCard(
            community: _community,
            onUpload: (_) => completer.future,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add image'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    completer.complete(null);
    await tester.pump();
  });
}
