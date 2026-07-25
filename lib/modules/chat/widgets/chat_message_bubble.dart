import 'package:flutter/material.dart';

import '../models/chat_message_model.dart';
import 'chat_user_avatar.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isCurrentUser;
  final VoidCallback? onLongPress;
  final VoidCallback? onAvatarTap;
  final bool isHighlighted;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.onLongPress,
    this.onAvatarTap,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isCurrentUser ? const Color(0xFF2563EB) : Colors.white;
    final foregroundColor = isCurrentUser
        ? Colors.white
        : const Color(0xFF0F172A);

    final bubble = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      constraints: BoxConstraints(
        maxWidth:
            MediaQuery.sizeOf(context).width * (isCurrentUser ? 0.78 : 0.68),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isCurrentUser ? 18 : 5),
          bottomRight: Radius.circular(isCurrentUser ? 5 : 18),
        ),
        border: Border.all(
          color: isHighlighted
              ? const Color(0xFF60A5FA)
              : isCurrentUser
              ? Colors.transparent
              : const Color(0xFFDCE6F5),
          width: isHighlighted ? 3 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isHighlighted
                ? const Color(0xFF2563EB).withValues(alpha: 0.28)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: isHighlighted ? 14 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCurrentUser) ...[
            Text(
              message.senderName,
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
            style: TextStyle(
              color: foregroundColor,
              fontSize: 15,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _formatTime(message.createdAt.toDate()),
              style: TextStyle(
                color: foregroundColor.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );

    final interactiveBubble = GestureDetector(
      onLongPress: onLongPress,
      child: bubble,
    );

    final avatar = Padding(
      padding: const EdgeInsets.only(top: 2),
      child: ChatUserAvatar(
        displayName: message.senderName,
        userId: message.senderId,
        onTap: onAvatarTap,
      ),
    );

    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: isCurrentUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: isCurrentUser
            ? [
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: interactiveBubble,
                  ),
                ),
                const SizedBox(width: 8),
                avatar,
              ]
            : [
                avatar,
                const SizedBox(width: 8),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: interactiveBubble,
                  ),
                ),
              ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    final hours = date.hour.toString().padLeft(2, "0");
    final minutes = date.minute.toString().padLeft(2, "0");
    return "$hours:$minutes";
  }
}
