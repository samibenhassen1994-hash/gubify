import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_ask_model.dart';
import 'package:gubify/modules/community/models/community_model.dart';
import 'package:gubify/modules/community/screens/community_ask_details_screen.dart';
import 'package:gubify/modules/community/screens/community_join_requests_screen.dart';
import 'package:gubify/modules/community/screens/community_public_details_screen.dart';
import 'package:gubify/modules/community/screens/gub_community_home_screen.dart';
import 'package:gubify/modules/push_notifications/navigation/global_push_notification_router.dart';

void main() {
  final community = CommunityModel(communityId: 'c', name: 'Community', ownerId: 'owner', memberCount: 2, visibility: 'public', createdAt: null, type: 'General', language: 'English', description: '', accessMode: 'approval');
  final ask = CommunityAskModel(askId: 'a', communityId: 'c', authorId: 'asker', authorDisplayName: 'Asker', type: CommunityAskType.help, text: 'Q', createdAt: Timestamp(1, 0), status: CommunityAskStatus.active);

  testWidgets('routes all six approved event types to existing destinations', (tester) async {
    final pushed = <Widget>[];
    final private = <Map<String, String>>[];
    final router = GlobalPushNotificationRouter(currentUserId: () => 'owner', loadCommunity: (_) async => community, loadMember: (_, __) async => Object(), loadAsk: (_, __) async => ask, push: (_, child) => pushed.add(child), openPrivate: (_, __, data) async => private.add(data));
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final context = tester.element(find.byType(Scaffold));
    for (final data in [
      {'type': 'task_assigned', 'gubId': 'g', 'taskId': 't'},
      {'type': 'proposal_created', 'gubId': 'g', 'proposalId': 'p'},
      {'type': 'community_answer_created', 'communityId': 'c', 'askId': 'a'},
      {'type': 'community_best_answer_selected', 'communityId': 'c', 'askId': 'a'},
      {'type': 'community_join_request_created', 'communityId': 'c'},
      {'type': 'community_join_request_resolved', 'communityId': 'c'},
    ]) { await router.open(context, data); }
    expect(private, hasLength(2));
    expect(pushed.whereType<CommunityAskDetailsScreen>(), hasLength(2));
    expect(pushed.whereType<CommunityJoinRequestsScreen>(), hasLength(1));
    expect(pushed.whereType<GubCommunityHomeScreen>(), hasLength(1));
  });

  testWidgets('resolved request opens public details without membership', (tester) async {
    Widget? pushed;
    final router = GlobalPushNotificationRouter(currentUserId: () => 'member', loadCommunity: (_) async => community, loadMember: (_, __) async => null, push: (_, child) => pushed = child);
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await router.open(tester.element(find.byType(Scaffold)), {'type': 'community_join_request_resolved', 'communityId': 'c'});
    expect(pushed, isA<CommunityPublicDetailsScreen>());
  });
}
