import 'package:flutter/material.dart';

import '../../../modules/goals/widgets/goal_home_card.dart';
import '../../../modules/hub_calendar/widgets/hub_calendar_home_card.dart';
import '../../../modules/proposals/widgets/proposal_home_card.dart';
import 'board_card.dart';

class HubModulesSection extends StatelessWidget {
  final String hubId;
  final int memberCount;
  final String ownerId;
  final List<String> activeModules;

  const HubModulesSection({
    super.key,
    required this.hubId,
    required this.memberCount,
    required this.ownerId,
    required this.activeModules,
  });

  bool isModuleEnabled(String module) {
    return activeModules.contains(module);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BoardCard(hubId: hubId),

        const SizedBox(height: 12),

        ProposalHomeCard(hubId: hubId, memberCount: memberCount),

        const SizedBox(height: 12),

        if (isModuleEnabled("calendar")) ...[
          HubCalendarHomeCard(hubId: hubId, ownerId: ownerId),
          const SizedBox(height: 12),
        ],

        if (isModuleEnabled("goals")) ...[
          GoalHomeCard(hubId: hubId, ownerId: ownerId),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
