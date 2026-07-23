import 'package:flutter/material.dart';

import '../models/chat_message_model.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isCurrentUser;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isCurrentUser ? const Color(0xFF2563EB) : Colors.white;
    final foregroundColor = isCurrentUser
        ? Colors.white
        : const Color(0xFF0F172A);

    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
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
          border: isCurrentUser
              ? null
              : Border.all(color: const Color(0xFFDCE6F5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
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
      ),
    );
  }

  String _formatTime(DateTime date) {
    final hours = date.hour.toString().padLeft(2, "0");
    final minutes = date.minute.toString().padLeft(2, "0");
    return "$hours:$minutes";
  }
}
