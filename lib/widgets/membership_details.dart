import 'package:flutter/material.dart';

class MembershipDetails extends StatelessWidget {
  final String role;
  final DateTime? joinedAt;

  const MembershipDetails({
    super.key,
    required this.role,
    required this.joinedAt,
  });

  @override
  Widget build(BuildContext context) {
    final memberSince = formatMemberSince(joinedAt);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: 14,
                color: Color(0xFF2563EB),
              ),
              const SizedBox(width: 4),
              Text(
                role,
                style: const TextStyle(
                  color: Color(0xFF1D4ED8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (memberSince != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              memberSince,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
            ),
          ),
        ],
      ],
    );
  }
}

String formatRoleLabel(String? role, {required String fallback}) {
  final normalized = role?.trim() ?? '';
  if (normalized.isEmpty) return fallback;
  return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
}

String? formatMemberSince(DateTime? joinedAt, {DateTime? now}) {
  if (joinedAt == null) return null;
  final current = now ?? DateTime.now();
  if (joinedAt.isAfter(current)) return 'Member since today';

  final difference = current.difference(joinedAt);
  if (difference.inDays == 0) return 'Member since today';
  if (difference.inDays < 30) {
    final days = difference.inDays;
    return 'Member since $days ${days == 1 ? 'day' : 'days'}';
  }
  if (difference.inDays < 365) {
    final months = (difference.inDays / 30).floor();
    return 'Member since $months ${months == 1 ? 'month' : 'months'}';
  }

  final years = (difference.inDays / 365).floor();
  return 'Member since $years ${years == 1 ? 'year' : 'years'}';
}
