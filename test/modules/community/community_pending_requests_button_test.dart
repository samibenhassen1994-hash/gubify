import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_model.dart';
import 'package:gubify/modules/community/widgets/community_pending_requests_button.dart';

void main() {
  const openCommunity = CommunityModel(
    communityId: 'open',
    name: 'Open Community',
    ownerId: 'owner',
    memberCount: 1,
    visibility: CommunityModel.publicVisibility,
    createdAt: null,
    type: CommunityModel.defaultType,
    language: CommunityModel.defaultLanguage,
    description: '',
    accessMode: CommunityModel.openAccessMode,
  );
  const approvalCommunity = CommunityModel(
    communityId: 'approval',
    name: 'Approval Community',
    ownerId: 'owner',
    memberCount: 1,
    visibility: CommunityModel.publicVisibility,
    createdAt: null,
    type: CommunityModel.defaultType,
    language: CommunityModel.defaultLanguage,
    description: '',
    accessMode: CommunityModel.approvalAccessMode,
  );

  testWidgets('hides zero, shows updates, caps at 99+, and handles errors', (
    tester,
  ) async {
    final controller = StreamController<int>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityPendingRequestsButton(
            countStream: controller.stream,
            onPressed: () {},
          ),
        ),
      ),
    );

    controller.add(0);
    await tester.pumpAndSettle();
    expect(find.text('0'), findsNothing);

    controller.add(3);
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);

    controller.add(120);
    await tester.pumpAndSettle();
    expect(find.text('99+'), findsOneWidget);

    controller.addError(StateError('denied'));
    await tester.pumpAndSettle();
    expect(find.text('99+'), findsNothing);
  });

  testWidgets('invokes its owner action once', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityPendingRequestsButton(
            countStream: Stream.value(1),
            onPressed: () => taps++,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.how_to_reg_rounded));
    expect(taps, 1);
  });

  testWidgets('renders only for an approval Community owner', (tester) async {
    var subscriptionCount = 0;
    final stream = Stream<int>.multi((_) => subscriptionCount++);

    await tester.pumpWidget(
      MaterialApp(
        home: CommunityPendingRequestsButton(
          isVisible: openCommunity.canManageJoinRequests(isOwner: true),
          countStream: stream,
          onPressed: () {},
        ),
      ),
    );

    expect(find.byIcon(Icons.how_to_reg_rounded), findsNothing);
    expect(subscriptionCount, 0);

    await tester.pumpWidget(
      MaterialApp(
        home: CommunityPendingRequestsButton(
          isVisible: approvalCommunity.canManageJoinRequests(isOwner: false),
          countStream: stream,
          onPressed: () {},
        ),
      ),
    );
    expect(find.byIcon(Icons.how_to_reg_rounded), findsNothing);
    expect(subscriptionCount, 0);

    await tester.pumpWidget(
      MaterialApp(
        home: CommunityPendingRequestsButton(
          isVisible: approvalCommunity.canManageJoinRequests(isOwner: true),
          countStream: stream,
          onPressed: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.how_to_reg_rounded), findsOneWidget);
  });
}
