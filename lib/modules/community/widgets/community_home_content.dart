import 'package:flutter/material.dart';

import '../../../widgets/gub_content_card.dart';
import '../models/community_model.dart';
import '../images/community_image_view.dart';
import '../services/community_service.dart';
import 'community_chat_view.dart';

class CommunityHomeContent extends StatelessWidget {
  final CommunityModel community;
  final bool isKeyboardOpen;
  final bool? isOwner;
  final Widget? chatView;

  const CommunityHomeContent({
    super.key,
    required this.community,
    required this.isKeyboardOpen,
    this.isOwner,
    this.chatView,
  });

  @override
  Widget build(BuildContext context) {
    final memberLabel = community.memberCount == 1 ? 'member' : 'members';
    final isOwner =
        this.isOwner ?? CommunityService.instance.isCurrentUserOwner(community);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isKeyboardOpen)
          Padding(
            padding: EdgeInsets.fromLTRB(80, 12, isOwner ? 148 : 80, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  CommunityImageView(imageUrl: community.imageUrl, size: 36),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          community.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${community.memberCount} $memberLabel · ${isOwner ? 'Owner' : 'Member'}',
                          maxLines: 1,
                          style: const TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 76, 24, 10),
            child: SizedBox(
              height: 84,
              child: GubContentCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    CommunityImageView(imageUrl: community.imageUrl, size: 56),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 28,
                            width: double.infinity,
                            child: FittedBox(
                              alignment: Alignment.centerLeft,
                              fit: BoxFit.scaleDown,
                              child: Text(
                                community.name,
                                maxLines: 1,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontSize: 25,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 22,
                            width: double.infinity,
                            child: FittedBox(
                              alignment: Alignment.centerLeft,
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _CommunityChip(
                                    icon: Icons.people_outline,
                                    label:
                                        '${community.memberCount} $memberLabel',
                                  ),
                                  const SizedBox(width: 4),
                                  _CommunityChip(
                                    icon: Icons.workspace_premium_outlined,
                                    label: isOwner ? 'Owner' : 'Member',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child:
              chatView ?? CommunityChatView(communityId: community.communityId),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF2563EB)),
          const SizedBox(width: 3),
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
