import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_access_request_model.dart';
import 'package:gubify/modules/community/models/community_model.dart';
import 'package:gubify/modules/community/screens/community_join_requests_screen.dart';

const _openCommunity = CommunityModel(
  communityId: 'open-community',
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

const _approvalCommunity = CommunityModel(
  communityId: 'approval-community',
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

Widget _screen({
  required CommunityModel community,
  Future<List<CommunityAccessRequestModel>> Function(String communityId)?
  loader,
}) => MaterialApp(
  home: CommunityJoinRequestsScreen(
    community: community,
    pendingRequestsLoader: loader,
  ),
);

void main() {
  test('join request management is available only to approval communities', () {
    expect(_openCommunity.canManageJoinRequests(isOwner: true), isFalse);
    expect(_approvalCommunity.canManageJoinRequests(isOwner: false), isFalse);
    expect(_approvalCommunity.canManageJoinRequests(isOwner: true), isTrue);
  });

  testWidgets('direct access to an open Community is safe and does not load', (
    tester,
  ) async {
    var loadCount = 0;

    await tester.pumpWidget(
      _screen(
        community: _openCommunity,
        loader: (_) async {
          loadCount++;
          return const [];
        },
      ),
    );
    await tester.pump();

    expect(
      find.text('This Community accepts members directly.'),
      findsOneWidget,
    );
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Reject'), findsNothing);
    expect(loadCount, 0);
  });

  testWidgets('approval Community continues to load pending requests', (
    tester,
  ) async {
    var loadCount = 0;

    await tester.pumpWidget(
      _screen(
        community: _approvalCommunity,
        loader: (_) async {
          loadCount++;
          return const [
            CommunityAccessRequestModel(
              userId: 'pending-user',
              displayName: 'Pending user',
              status: CommunityAccessRequestModel.pendingStatus,
              createdAt: null,
            ),
          ];
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(loadCount, 1);
    expect(find.text('Pending user'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
  });
}
