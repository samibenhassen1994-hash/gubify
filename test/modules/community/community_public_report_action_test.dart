import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_access_request_model.dart';
import 'package:gubify/modules/community/models/community_model.dart';
import 'package:gubify/modules/community/restrictions/models/community_restriction_model.dart';
import 'package:gubify/modules/community/screens/community_public_details_screen.dart';

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
    description: 'Description',
    accessMode: 'open',
  );

  testWidgets('Report Community action opens and submits the shared form', (
    tester,
  ) async {
    var submitted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityPublicDetailsScreen(
          communityId: community.communityId,
          stateStream: Stream.value(
            const CommunityPublicAccessState(
              community: community,
              isMember: false,
              isOwner: false,
              request: null,
            ),
          ),
          restrictionStream: Stream.value(CommunityRestriction.unrestricted),
          reportSubmit: (_, _) async => submitted = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

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
    expect(find.text('Report submitted'), findsOneWidget);
  });

  testWidgets('Community owner has no Report Community action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityPublicDetailsScreen(
          communityId: community.communityId,
          stateStream: Stream.value(
            const CommunityPublicAccessState(
              community: community,
              isMember: true,
              isOwner: true,
              request: null,
            ),
          ),
          restrictionStream: Stream.value(CommunityRestriction.unrestricted),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Community actions'), findsNothing);
  });

  testWidgets('joining restriction hides Join for a non-member', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityPublicDetailsScreen(
          communityId: community.communityId,
          stateStream: Stream.value(
            const CommunityPublicAccessState(
              community: community,
              isMember: false,
              isOwner: false,
              request: null,
            ),
          ),
          restrictionStream: Stream.value(
            const CommunityRestriction(
              hiddenFromDiscovery: false,
              joiningRestricted: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('New members are not being accepted right now.'),
      findsOneWidget,
    );
    expect(find.text('Join Community'), findsNothing);
  });

  testWidgets('joining restriction does not block existing members', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityPublicDetailsScreen(
          communityId: community.communityId,
          stateStream: Stream.value(
            const CommunityPublicAccessState(
              community: community,
              isMember: true,
              isOwner: false,
              request: null,
            ),
          ),
          restrictionStream: Stream.value(
            const CommunityRestriction(
              hiddenFromDiscovery: true,
              joiningRestricted: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Open Community'), findsOneWidget);
    expect(
      find.text('New members are not being accepted right now.'),
      findsNothing,
    );
  });
}
