import 'package:flutter/material.dart';

class ChatFloatingButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ChatFloatingButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: null,
      tooltip: "Open chat",
      onPressed: onPressed,
      backgroundColor: const Color(0xFF2563EB),
      foregroundColor: Colors.white,
      child: const Icon(Icons.chat_bubble_rounded),
    );
  }
}
