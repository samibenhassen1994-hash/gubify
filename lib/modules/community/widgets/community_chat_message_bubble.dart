import 'package:flutter/material.dart';

import '../../chat/widgets/chat_user_avatar.dart';
import '../../chat/widgets/deleted_user_identity_builder.dart';
import '../models/community_chat_message_model.dart';

class CommunityChatMessageBubble extends StatelessWidget {
  final CommunityChatMessageModel message;
  final bool isCurrentUser;
  final Stream<bool>? profileExists;

  const CommunityChatMessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.profileExists,
  });

  @override
  Widget build(BuildContext context) {
    return DeletedUserIdentityBuilder(
      userId: message.senderId,
      currentDisplayName: message.senderName,
      profileExists: profileExists,
      builder: (context, displayName, deleted) =>
          _buildBubble(context, displayName: displayName),
    );
  }

  Widget _buildBubble(BuildContext context, {required String displayName}) {
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
        );
        final avatar = Padding(
          padding: const EdgeInsets.only(top: 2),
          child: ChatUserAvatar(
            displayName: displayName,
            userId: message.senderId,
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
