import 'package:flutter/material.dart';

class CommunityLeaderboardTrophy extends StatelessWidget {
  const CommunityLeaderboardTrophy({super.key, required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final color = switch (rank) {
      1 => const Color(0xFFFFB300),
      2 => const Color(0xFF94A3B8),
      3 => const Color(0xFFB87333),
      _ => null,
    };
    if (color == null) return const SizedBox.shrink();
    final label = switch (rank) { 1 => 'gold', 2 => 'silver', _ => 'bronze' };
    return Icon(
      Icons.emoji_events_rounded,
      key: ValueKey('leaderboard-trophy-$label'),
      color: color,
      size: 22,
    );
  }
}
