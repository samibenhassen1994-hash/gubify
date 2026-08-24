import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_model.dart';
import 'package:gubify/modules/community/moderation/widgets/community_report_menu.dart';

void main() {
  const community = CommunityModel(
    communityId: 'community',
    name: 'Public Community',
    ownerId: 'owner',
    memberCount: 2,
    visibility: 'public',
    createdAt: null,
    type: 'General',
    language: 'English',
    description: '',
    accessMode: 'open',
  );

  testWidgets('a Community member can open Report Community from the menu', (
    tester,
  ) async {
    var submitted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityReportMenu(
            community: community,
            isOwner: false,
            reportSubmit: (_, _) async => submitted = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Community actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report Community'));
    await tester.pumpAndSettle();
    expect(find.text('Report Community'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spam').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();
    expect(submitted, isTrue);
  });

  testWidgets('Community owner cannot see the report menu', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CommunityReportMenu(community: community, isOwner: true),
        ),
      ),
    );

    expect(find.byTooltip('Community actions'), findsNothing);
  });
}
