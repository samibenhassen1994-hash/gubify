import 'package:flutter/material.dart';

class ChatFloatingButton extends StatelessWidget {
  final VoidCallback onPressed;
  final int? unreadCount;

  const ChatFloatingButton({
    super.key,
    required this.onPressed,
    required this.unreadCount,
  });

  @override
  Widget build(BuildContext context) {
    final count = unreadCount;
    final showBadge = count != null && count > 0;
    final badgeText = count != null && count > 99 ? "99+" : "$count";
    final tooltip = showBadge
        ? "Open chat, $count unread ${count == 1 ? 'message' : 'messages'}"
        : "Open chat";

    return Stack(
      clipBehavior: Clip.none,
      children: [
        FloatingActionButton(
          heroTag: null,
          tooltip: tooltip,
          onPressed: onPressed,
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          child: const Icon(Icons.chat_bubble_rounded),
        ),
        if (showBadge)
          Positioned(
            top: -5,
            right: -7,
            child: ExcludeSemantics(
              child: Container(
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  badgeText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    height: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
