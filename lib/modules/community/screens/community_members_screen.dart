import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../widgets/gub_content_card.dart';
import '../../../widgets/gub_screen_background.dart';
import '../../chat/widgets/chat_user_avatar.dart';
import '../../profile/screens/user_profile_screen.dart';
import '../../profile/models/user_profile_model.dart';
import '../models/community_model.dart';
import '../services/community_service.dart';

class CommunityMembersScreen extends StatelessWidget {
  final CommunityModel community;
  final Stream<List<CommunityMemberModel>>? memberStream;
  final String? currentUserId;
  final bool? isOwner;
  final Future<void> Function(String userId)? onRemove;
  final Future<void> Function(String userId)? onBan;
  final Future<UserProfileModel?> Function(String userId)? profileLoader;

  const CommunityMembersScreen({
    super.key,
    required this.community,
    this.memberStream,
    this.currentUserId,
    this.isOwner,
    this.onRemove,
    this.onBan,
    this.profileLoader,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        this.currentUserId ?? FirebaseAuth.instance.currentUser?.uid;
    final isOwner =
        this.isOwner ?? CommunityService.instance.isCurrentUserOwner(community);

    return GubScreenBackground(
      variant: GubBackgroundAssignments.profiles,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Members'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: SafeArea(
          top: false,
          child: StreamBuilder<List<CommunityMemberModel>>(
            stream:
                memberStream ??
                CommunityService.instance.communityMembersStream(
                  community.communityId,
                ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Unable to load members.'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final members = snapshot.data!;
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                itemCount: members.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _CommunityMemberTile(
                  community: community,
                  member: members[index],
                  isCurrentUser: members[index].userId == currentUserId,
                  canManage: isOwner && members[index].userId != currentUserId,
                  onRemove: onRemove,
                  onBan: onBan,
                  profileLoader: profileLoader,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CommunityMemberTile extends StatelessWidget {
  final CommunityModel community;
  final CommunityMemberModel member;
  final bool isCurrentUser;
  final bool canManage;
  final Future<void> Function(String userId)? onRemove;
  final Future<void> Function(String userId)? onBan;
  final Future<UserProfileModel?> Function(String userId)? profileLoader;

  const _CommunityMemberTile({
    required this.community,
    required this.member,
    required this.isCurrentUser,
    required this.canManage,
    required this.onRemove,
    required this.onBan,
    required this.profileLoader,
  });

  Future<void> _confirmAction(BuildContext context, String action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$action member?'),
        content: Text('$action ${member.displayName} from this Community?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: ValueKey('confirm-${action.toLowerCase()}'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      if (action == 'Ban') {
        if (onBan != null) {
          await onBan!(member.userId);
        } else {
          await CommunityService.instance.banCommunityMember(
            communityId: community.communityId,
            userId: member.userId,
          );
        }
      } else {
        if (onRemove != null) {
          await onRemove!(member.userId);
        } else {
          await CommunityService.instance.removeCommunityMember(
            communityId: community.communityId,
            userId: member.userId,
          );
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${member.displayName} ${action == 'Ban' ? 'banned' : 'removed'}.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GubContentCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: InkWell(
          key: ValueKey('member-avatar-${member.userId}'),
          borderRadius: BorderRadius.circular(28),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => UserProfileScreen.community(
                communityId: community.communityId,
                communityName: community.name,
                userId: member.userId,
                profileFuture: profileLoader?.call(member.userId),
              ),
            ),
          ),
          child: ChatUserAvatar(
            displayName: member.displayName,
            userId: member.userId,
            photoUrl: member.photoUrl,
            radius: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                member.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (isCurrentUser) ...[
              const SizedBox(width: 8),
              const Chip(
                visualDensity: VisualDensity.compact,
                label: Text('You'),
              ),
            ],
          ],
        ),
        subtitle: Text(member.role == 'owner' ? 'Owner' : 'Member'),
        trailing: canManage
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'assign') {
                    showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Assign role'),
                        content: const Text('Coming soon'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  } else {
                    _confirmAction(context, value);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'assign', child: Text('Assign role')),
                  PopupMenuItem(value: 'Remove', child: Text('Remove')),
                  PopupMenuItem(value: 'Ban', child: Text('Ban')),
                ],
              )
            : null,
      ),
    );
  }
}
