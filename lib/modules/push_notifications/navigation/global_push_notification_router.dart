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
  GlobalPushNotificationRouter({
    Future<void> Function(BuildContext, String, Map<String, String>)? openPrivate,
    Future<dynamic> Function(String)? loadCommunity,
    Future<dynamic> Function(String, String)? loadMember,
    Future<CommunityAskModel?> Function(String, String)? loadAsk,
    bool Function()? canManageRequests,
    String? Function()? currentUserId,
    void Function(BuildContext, Widget)? push,
  })  : _openPrivate = openPrivate ?? ((context, gubId, data) => NotificationRouter.navigate(context: context, gubId: gubId, data: data)),
        _loadCommunity = loadCommunity ?? CommunityRepository.instance.getCommunity,
        _loadMember = loadMember ?? ((communityId, uid) => CommunityRepository.instance.getCommunityMember(communityId: communityId, userId: uid)),
        _loadAsk = loadAsk ?? _defaultLoadAsk,
        _canManageRequests = canManageRequests ?? (() => PlatformAdminService.instance.isAdmin),
        _currentUserId = currentUserId ?? (() => FirebaseAuth.instance.currentUser?.uid),
        _push = push ?? ((context, child) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => child)));

  final Future<void> Function(BuildContext, String, Map<String, String>) _openPrivate;
  final Future<dynamic> Function(String) _loadCommunity;
  final Future<dynamic> Function(String, String) _loadMember;
  final Future<CommunityAskModel?> Function(String, String) _loadAsk;
  final bool Function() _canManageRequests;
  final String? Function() _currentUserId;
  final void Function(BuildContext, Widget) _push;
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
      if (gubId != null) await _openPrivate(context, gubId, data);
      return;
    }
    final communityId = data['communityId'];
    if (communityId == null) return;
    final uid = _currentUserId();
    final community = await _loadCommunity(communityId);
    if (!context.mounted || community == null) return;
    if (type == 'community_join_request_created') {
      if (uid == null ||
          (community.ownerId != uid && !_canManageRequests())) {
        return;
      }
      _push(context, CommunityJoinRequestsScreen(community: community));
      return;
    }
    if (type == 'community_join_request_resolved') {
      final member = uid == null ? null : await _loadMember(communityId, uid);
      if (!context.mounted) return;
      _push(context, member == null ? CommunityPublicDetailsScreen(communityId: communityId) : GubCommunityHomeScreen(communityId: communityId, initialCommunity: community));
      return;
    }
    final askId = data['askId'];
    if (askId == null) return;
    final model = await _loadAsk(communityId, askId);
    if (!context.mounted || model == null) return;
    _push(context, CommunityAskDetailsScreen(ask: model, communityName: community.name));
  }

  static Future<CommunityAskModel?> _defaultLoadAsk(String communityId, String askId) async {
    final ask = await FirebaseFirestore.instance.collection('communities').doc(communityId).collection('asks').doc(askId).get();
    return ask.exists ? CommunityAskModel.fromFirestore(ask.data()!, askId: ask.id) : null;
  }
}
