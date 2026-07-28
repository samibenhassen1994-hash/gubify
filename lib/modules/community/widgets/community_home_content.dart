import 'package:flutter/material.dart';

import '../../../widgets/gub_content_card.dart';
import '../models/community_model.dart';
import 'community_chat_view.dart';

class CommunityHomeContent extends StatelessWidget {
  final CommunityModel community;

  const CommunityHomeContent({super.key, required this.community});

  @override
  Widget build(BuildContext context) {
    final memberLabel = community.memberCount == 1 ? "member" : "members";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 76, 24, 16),
          child: GubContentCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.groups_rounded,
                  size: 48,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(height: 16),
                Text(
                  community.name,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Public community",
                  style: TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _CommunityChip(
                      icon: Icons.people_outline,
                      label: "${community.memberCount} $memberLabel",
                    ),
                    const _CommunityChip(
                      icon: Icons.workspace_premium_outlined,
                      label: "Owner",
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(child: CommunityChatView(communityId: community.communityId)),
      ],
    );
  }
}

class CommunityStateMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? details;

  const CommunityStateMessage({
    super.key,
    required this.icon,
    required this.message,
    this.details,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GubContentCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: const Color(0xFF2563EB)),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              if (details != null) ...[
                const SizedBox(height: 8),
                Text(
                  details!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunityChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CommunityChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF2563EB)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
