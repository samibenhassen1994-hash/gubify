import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_model.dart';
import 'package:gubify/modules/community/repositories/community_repository.dart';
import 'package:gubify/modules/community/screens/community_explorer_screen.dart';

const _visible = CommunityModel(
  communityId: 'visible',
  name: 'Visible Community',
  ownerId: 'owner',
  memberCount: 1,
  visibility: CommunityModel.publicVisibility,
  createdAt: null,
  type: CommunityModel.defaultType,
  language: CommunityModel.defaultLanguage,
  description: '',
  accessMode: CommunityModel.openAccessMode,
);

const _hidden = CommunityModel(
  communityId: 'hidden',
  name: 'Hidden Community',
  ownerId: 'owner',
  memberCount: 1,
  visibility: CommunityModel.publicVisibility,
  createdAt: null,
  type: CommunityModel.defaultType,
  language: CommunityModel.defaultLanguage,
  description: '',
  accessMode: CommunityModel.openAccessMode,
);

void main() {
  testWidgets('Explorer gives Owner precedence when the joined user owns the Community', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityExplorerScreen(
          pageLoader: (_) async => const CommunityExplorerPage(
            communities: [_visible],
            nextCursor: null,
            hasMore: false,
          ),
          discoveryFilter: (communities) async => communities,
          joinedCommunityIdsStream: Stream.value({_visible.communityId}),
          isOwner: (community) => community.ownerId == 'owner',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('Member'), findsNothing);
  });

  testWidgets('Explorer filters hidden Communities before presentation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityExplorerScreen(
          pageLoader: (_) async => const CommunityExplorerPage(
            communities: [_visible, _hidden],
            nextCursor: null,
            hasMore: false,
          ),
          discoveryFilter: (communities) async => communities
              .where(
                (community) => community.communityId != _hidden.communityId,
              )
              .toList(growable: false),
          joinedCommunityIdsStream: Stream.value(const <String>{}),
          isOwner: (_) => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(_visible.name), findsOneWidget);
    expect(find.text(_hidden.name), findsNothing);
  });
}
