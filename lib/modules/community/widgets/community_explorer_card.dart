import 'package:flutter/material.dart';

import '../../../widgets/gub_content_card.dart';
import '../models/community_model.dart';

class CommunityExplorerCard extends StatelessWidget {
  final CommunityModel community;
  final bool isJoined;
  final bool isJoining;
  final VoidCallback onJoin;
  final VoidCallback onOpen;

  const CommunityExplorerCard({
    super.key,
    required this.community,
    required this.isJoined,
    required this.isJoining,
    required this.onJoin,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: isJoined,
      label: isJoined
          ? "Open ${community.name}"
          : "${community.name}. Join community.",
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: isJoined ? onOpen : null,
        child: GubContentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      community.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StatusBadge(
                    label: isJoined ? "Joined" : "Public",
                    color: isJoined
                        ? const Color(0xFF059669)
                        : const Color(0xFF2563EB),
                  ),
                ],
              ),
              if (community.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  community.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.category_outlined,
                    label: community.type,
                  ),
                  _InfoChip(
                    icon: Icons.language_outlined,
                    label: community.language,
                  ),
                  _InfoChip(
                    icon: Icons.people_outline,
                    label: "${community.memberCount}",
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: isJoined
                    ? OutlinedButton.icon(
                        onPressed: onOpen,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text("Open community"),
                      )
                    : FilledButton.icon(
                        onPressed: isJoining ? null : onJoin,
                        icon: isJoining
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.group_add_outlined),
                        label: Text(isJoining ? "Joining..." : "Join"),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF475569)),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Color(0xFF475569))),
        ],
      ),
    );
  }
}
