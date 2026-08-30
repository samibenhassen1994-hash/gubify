import 'package:flutter/material.dart';

import '../../chat/widgets/chat_user_avatar.dart';
import '../models/community_ask_model.dart';

class CommunityAskCard extends StatelessWidget {
  const CommunityAskCard({super.key, required this.ask, required this.onTap});

  final CommunityAskModel ask;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ChatUserAvatar(
                    displayName: ask.authorDisplayName,
                    userId: ask.authorId,
                    radius: 18,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      ask.authorDisplayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  _AskTypeBadge(type: ask.type),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                ask.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(height: 1.35),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatCommunityAskDate(ask.createdAt.toDate()),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Active',
                    style: TextStyle(
                      color: Color(0xFF059669),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CommunityAskTypeBadge extends StatelessWidget {
  const CommunityAskTypeBadge({super.key, required this.type});

  final CommunityAskType type;

  @override
  Widget build(BuildContext context) => _AskTypeBadge(type: type);
}

class _AskTypeBadge extends StatelessWidget {
  const _AskTypeBadge({required this.type});

  final CommunityAskType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        type.label,
        style: const TextStyle(
          color: Color(0xFF2563EB),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String formatCommunityAskDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/${date.year} · $hour:$minute';
}
