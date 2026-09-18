import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_model.dart';
import 'package:gubify/modules/community/repositories/community_repository.dart';
import 'package:gubify/modules/community/screens/community_explorer_screen.dart';
import 'package:gubify/widgets/gubify_swipe_back.dart';

void main() {
  Widget explorer({
    required bool showBackButton,
    double additionalBottomScrollPadding = 0,
    List<CommunityModel> communities = const [],
  }) => MaterialApp(
    home: CommunityExplorerScreen(
      showBackButton: showBackButton,
      additionalBottomScrollPadding: additionalBottomScrollPadding,
      pageLoader: (_) async => CommunityExplorerPage(
        communities: communities,
        nextCursor: null,
        hasMore: false,
      ),
      discoveryFilter: (communities) async => communities,
      joinedCommunityIdsStream: Stream.value(const <String>{}),
      isAnonymous: () => false,
      isOwner: (_) => false,
    ),
  );

  testWidgets('root mode hides Back', (tester) async {
    await tester.pumpWidget(explorer(showBackButton: false));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Back'), findsNothing);
    expect(find.byType(GubifySwipeBack), findsNothing);
    expect(find.text('Explore communities'), findsOneWidget);
  });

  testWidgets('standalone mode keeps Back', (tester) async {
    await tester.pumpWidget(explorer(showBackButton: true));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.byType(GubifySwipeBack), findsOneWidget);
  });

  testWidgets('root mode keeps navbar clearance inside the scroll content', (
    tester,
  ) async {
    await tester.pumpWidget(
      explorer(
        showBackButton: false,
        additionalBottomScrollPadding: 88,
        communities: [
          CommunityModel(
            communityId: 'community-1',
            name: 'Community',
            ownerId: 'owner',
            memberCount: 1,
            visibility: CommunityModel.publicVisibility,
            createdAt: null,
            type: CommunityModel.defaultType,
            language: CommunityModel.defaultLanguage,
            description: '',
            accessMode: CommunityModel.openAccessMode,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final list = tester.widget<ListView>(find.byType(ListView));
    expect((list.padding! as EdgeInsets).bottom, 116);
  });
}
