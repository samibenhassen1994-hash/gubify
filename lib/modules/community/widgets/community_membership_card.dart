import 'package:flutter/material.dart';

import '../../../widgets/gub_content_card.dart';
import '../../../widgets/membership_details.dart';
import '../images/community_image_view.dart';
import '../models/community_model.dart';

class CommunityMembershipCard extends StatelessWidget {
  final CommunityMembershipModel membership;
  final VoidCallback onTap;

  const CommunityMembershipCard({
    super.key,
    required this.membership,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GubContentCard(
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 8,
          ),
          leading: CommunityImageView(
            imageUrl: membership.community.imageUrl,
            size: 52,
          ),
          title: Text(
            membership.community.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: MembershipDetails(
              role: membership.role == 'owner'
                  ? 'Owner'
                  : formatRoleLabel(membership.role, fallback: 'Member'),
              joinedAt: membership.joinedAtDate,
            ),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, size: 22),
          onTap: onTap,
        ),
      ),
    );
  }
}
