import 'package:flutter/material.dart';

import '../../models/community_model.dart';
import '../services/community_moderation_service.dart';
import 'community_report_dialog.dart';

class CommunityReportMenu extends StatelessWidget {
  final CommunityModel community;
  final bool isOwner;
  final CommunityReportSubmit? reportSubmit;

  const CommunityReportMenu({
    super.key,
    required this.community,
    required this.isOwner,
    this.reportSubmit,
  });

  @override
  Widget build(BuildContext context) {
    if (isOwner) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      tooltip: 'Community actions',
      onSelected: (value) {
        if (value != 'report') return;
        showCommunityReportDialog(
          context: context,
          title: 'Report Community',
          onSubmit:
              reportSubmit ??
              (reason, details) =>
                  CommunityModerationService.instance.reportCommunity(
                    community: community,
                    reason: reason,
                    details: details,
                  ),
        );
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'report',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.flag_outlined),
            title: Text('Report Community'),
          ),
        ),
      ],
    );
  }
}
