import 'package:flutter/material.dart';

import '../models/chat_message_model.dart';
import 'chat_user_avatar.dart';
import 'deleted_user_identity_builder.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isCurrentUser;
  final VoidCallback? onLongPress;
  final VoidCallback? onAvatarTap;
  final bool isHighlighted;
  final Stream<bool>? profileExists;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.onLongPress,
    this.onAvatarTap,
    this.isHighlighted = false,
    this.profileExists,
  });

  @override
  Widget build(BuildContext context) {
    return DeletedUserIdentityBuilder(
      userId: message.senderId,
      currentDisplayName: message.senderName,
      profileExists: profileExists,
      builder: (context, displayName, deleted) =>
          _buildBubble(context, displayName: displayName, deleted: deleted),
    );
  }

  Widget _buildBubble(
    BuildContext context, {
    required String displayName,
    required bool deleted,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBubbleWidth = constraints.maxWidth * 0.78;
        final bubbleColor = isCurrentUser
            ? const Color(0xFFDDEBFF)
            : const Color(0xFFF7F8FA);

        final bubble = GestureDetector(
          onLongPress: onLongPress,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            padding: const EdgeInsets.fromLTRB(13, 9, 13, 7),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isCurrentUser ? 18 : 6),
                bottomRight: Radius.circular(isCurrentUser ? 6 : 18),
              ),
              border: Border.all(
                color: isHighlighted
                    ? const Color(0xFF60A5FA)
                    : isCurrentUser
                    ? const Color(0xFFC7DBFA)
                    : const Color(0xFFE2E8F0),
                width: isHighlighted ? 3 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isHighlighted
                      ? const Color(0xFF2563EB).withValues(alpha: 0.28)
                      : const Color(0xFF0F172A).withValues(alpha: 0.035),
                  blurRadius: isHighlighted ? 14 : 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isCurrentUser) ...[
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF2563EB),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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
          ),
        );

        final avatar = Padding(
          padding: const EdgeInsets.only(top: 2),
          child: ChatUserAvatar(
            displayName: displayName,
            userId: message.senderId,
            onTap: deleted ? null : onAvatarTap,
          ),
        );

        if (isCurrentUser) {
          return Padding(
            padding: const EdgeInsets.only(right: 2, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Align(alignment: Alignment.centerRight, child: bubble),
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
                child: Align(alignment: Alignment.centerLeft, child: bubble),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime date) {
    final hours = date.hour.toString().padLeft(2, "0");
    final minutes = date.minute.toString().padLeft(2, "0");
    return "$hours:$minutes";
  }
}
