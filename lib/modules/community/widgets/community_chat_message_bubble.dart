import 'package:flutter/material.dart';

import '../../../repositories/user_repository.dart';
import '../../chat/widgets/deleted_user_identity_builder.dart';
import '../models/community_chat_message_model.dart';
import 'community_level_avatar.dart';

class CommunityChatMessageBubble extends StatelessWidget {
  final CommunityChatMessageModel message;
  final bool isCurrentUser;
  final Stream<bool>? profileExists;
  final Stream<UserIdentity>? identity;
  final VoidCallback? onProfileTap;
  final VoidCallback? onCreateAsk;
  final int? xp;

  const CommunityChatMessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.profileExists,
    this.identity,
    this.onProfileTap,
    this.onCreateAsk,
    this.xp,
  });

  @override
  Widget build(BuildContext context) {
    return DeletedUserIdentityBuilder(
      userId: message.senderId,
      currentDisplayName: message.senderName,
      profileExists: profileExists,
      identity: identity,
      resolveCurrentDisplayName: true,
      builder: (context, displayName, deleted) => _buildBubble(
        context,
        displayName: displayName,
        profileAvailable: !deleted,
      ),
    );
  }

  Widget _buildBubble(
    BuildContext context, {
    required String displayName,
    required bool profileAvailable,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bubble = Container(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.78),
          padding: const EdgeInsets.fromLTRB(13, 9, 13, 7),
          decoration: BoxDecoration(
            color: isCurrentUser
                ? const Color(0xFFDDEBFF)
                : const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isCurrentUser ? 18 : 6),
              bottomRight: Radius.circular(isCurrentUser ? 6 : 18),
            ),
            border: Border.all(
              color: isCurrentUser
                  ? const Color(0xFFC7DBFA)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.035),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isCurrentUser) ...[
                GestureDetector(
                  onTap: profileAvailable ? onProfileTap : null,
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF2563EB),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
              ],
              Text(
                message.text,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 3),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _formatTime(message.createdAt.toDate()),
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
        final avatar = Padding(
          padding: const EdgeInsets.only(top: 2),
          child: CommunityLevelAvatar(
            displayName: displayName,
            userId: message.senderId,
            photoUrl: null,
            xp: xp,
            onTap: profileAvailable ? onProfileTap : null,
          ),
        );

        final interactiveBubble = onCreateAsk == null
            ? bubble
            : GestureDetector(
                onLongPress: () => _showMessageActions(context),
                child: bubble,
              );

        if (isCurrentUser) {
          return Padding(
            padding: const EdgeInsets.only(right: 2, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: interactiveBubble,
                  ),
                ),
                const SizedBox(width: 7),
                avatar,
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              avatar,
              const SizedBox(width: 7),
              Flexible(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: interactiveBubble,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showMessageActions(BuildContext context) async {
    final create = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.help_outline_rounded),
          title: const Text('Create ask'),
          onTap: () => Navigator.pop(context, true),
        ),
      ),
    );
    if (create == true) onCreateAsk?.call();
  }

  String _formatTime(DateTime date) {
    final hours = date.hour.toString().padLeft(2, "0");
    final minutes = date.minute.toString().padLeft(2, "0");
    return "$hours:$minutes";
  }
}
