import 'package:flutter/material.dart';

class HubMembersBadge extends StatelessWidget {
  final int memberCount;

  const HubMembersBadge({
    super.key,
    required this.memberCount,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .75),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          "$memberCount member${memberCount == 1 ? "" : "s"}",
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}