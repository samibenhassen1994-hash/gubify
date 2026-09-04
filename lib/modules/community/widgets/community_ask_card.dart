import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/community_ask_model.dart';
import '../moderation/services/community_moderation_service.dart';
import '../moderation/widgets/community_report_dialog.dart';
import 'community_level_avatar.dart';

class CommunityAskCard extends StatelessWidget {
  const CommunityAskCard({
    super.key,
    required this.ask,
    required this.onTap,
    this.onOpenAuthor,
    this.authorXp,
    this.currentUserId,
    this.onReport,
    this.communityName,
  });

  final CommunityAskModel ask;
  final VoidCallback onTap;
  final VoidCallback? onOpenAuthor;
  final int? authorXp;
  final String? currentUserId;
  final Future<void> Function()? onReport;
  final String? communityName;

  @override
  Widget build(BuildContext context) {
    final isResolved = ask.status == CommunityAskStatus.resolved;
    final statusDate = isResolved
        ? ask.resolvedAt ?? ask.createdAt
        : ask.createdAt;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onReport != null || communityName != null
            ? () => _showReportAction(context)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    key: ValueKey('ask-author-${ask.askId}'),
                    borderRadius: BorderRadius.circular(18),
                    onTap: onOpenAuthor,
                    child: CommunityLevelAvatar(
                      displayName: ask.authorDisplayName,
                      userId: ask.authorId,
                      photoUrl: null,
                      radius: 18,
                      xp: authorXp,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: InkWell(
                      onTap: onOpenAuthor,
                      child: Text(
                        ask.authorDisplayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
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
                      formatCommunityAskDate(statusDate.toDate()),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isResolved ? 'Resolved' : 'Active',
                    style: TextStyle(
                      color: isResolved
                          ? const Color(0xFF475569)
                          : const Color(0xFF059669),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (ask.updatedAt != null) ...[
                const SizedBox(height: 5),
                Text(
                  'Edited ${formatCommunityAskDate(ask.updatedAt!.toDate())}',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showReportAction(BuildContext context) async {
    final reporterId = currentUserId ?? FirebaseAuth.instance.currentUser?.uid;
    if (reporterId == null || reporterId == ask.authorId) return;
    final report = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.flag_outlined),
          title: const Text('Report Ask'),
          onTap: () => Navigator.pop(sheetContext, true),
        ),
      ),
    );
    if (report != true) return;
    if (onReport != null) return onReport!();
    if (!context.mounted) return;
    await showCommunityReportDialog(
      context: context,
      title: 'Report Ask',
      onSubmit: (reason, details) =>
          CommunityModerationService.instance.reportAsk(
            ask: ask,
            communityName: communityName!,
            reason: reason,
            details: details,
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
