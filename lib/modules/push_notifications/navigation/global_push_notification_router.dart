import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/navigation/notification_router.dart';
import '../../community/models/community_ask_model.dart';
import '../../community/admin/platform_admin_service.dart';
import '../../community/repositories/community_repository.dart';
import '../../community/screens/community_ask_details_screen.dart';
import '../../community/screens/community_join_requests_screen.dart';
import '../../community/screens/community_public_details_screen.dart';
import '../../community/screens/gub_community_home_screen.dart';

/// Validates the six Worker-issued notification kinds before navigation.
class GlobalPushNotificationRouter {
  static const supportedTypes = {
    'task_assigned', 'proposal_created', 'community_answer_created',
    'community_best_answer_selected', 'community_join_request_created',
    'community_join_request_resolved',
  };

  Future<void> open(BuildContext context, Map<String, String> data) async {
    if (!supportedTypes.contains(data['type'])) return;
    final type = data['type']!;
    if (type == 'task_assigned' || type == 'proposal_created') {
      final gubId = data['gubId'];
      if (gubId != null) await NotificationRouter.navigate(context: context, gubId: gubId, data: data);
      return;
    }
    final communityId = data['communityId'];
    if (communityId == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final community = await CommunityRepository.instance.getCommunity(communityId);
    if (!context.mounted || community == null) return;
    if (type == 'community_join_request_created') {
      if (uid == null ||
          (community.ownerId != uid && !PlatformAdminService.instance.isAdmin)) {
        return;
      }
      _push(context, CommunityJoinRequestsScreen(community: community));
      return;
    }
    if (type == 'community_join_request_resolved') {
      final member = uid == null ? null : await CommunityRepository.instance.getCommunityMember(communityId: communityId, userId: uid);
      if (!context.mounted) return;
      _push(context, member == null ? CommunityPublicDetailsScreen(communityId: communityId) : GubCommunityHomeScreen(communityId: communityId, initialCommunity: community));
      return;
    }
    final askId = data['askId'];
    if (askId == null) return;
    final ask = await FirebaseFirestore.instance.collection('communities').doc(communityId).collection('asks').doc(askId).get();
    if (!context.mounted || !ask.exists) return;
    final model = CommunityAskModel.fromFirestore(
      ask.data()!,
      askId: ask.id,
    );
    _push(context, CommunityAskDetailsScreen(ask: model, communityName: community.name));
  }

  void _push(BuildContext context, Widget child) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => child));
}
