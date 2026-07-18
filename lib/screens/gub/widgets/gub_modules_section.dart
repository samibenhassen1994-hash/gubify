import 'package:flutter/material.dart';

import '../../../modules/goals/widgets/goal_home_card.dart';
import '../../../modules/gub_calendar/widgets/gub_calendar_home_card.dart';
import '../../../modules/proposals/widgets/proposal_home_card.dart';
import 'board_card.dart';

class GubModulesSection extends StatelessWidget {
  final String gubId;
  final int memberCount;
  final String ownerId;
  final List<String> activeModules;

  const GubModulesSection({
    super.key,
    required this.gubId,
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
        BoardCard(gubId: gubId),

        const SizedBox(height: 12),

        ProposalHomeCard(gubId: gubId, memberCount: memberCount),

        const SizedBox(height: 12),

        if (isModuleEnabled("calendar")) ...[
          GubCalendarHomeCard(gubId: gubId, ownerId: ownerId),
          const SizedBox(height: 12),
        ],

        if (isModuleEnabled("goals")) ...[
          GoalHomeCard(gubId: gubId, ownerId: ownerId),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
