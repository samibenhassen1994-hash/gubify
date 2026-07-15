import 'package:flutter/material.dart';

import 'invite_members_button.dart';
import 'manage_hub_button.dart';

class HubActionsSection extends StatelessWidget {
  final String hubId;

  const HubActionsSection({
    super.key,
    required this.hubId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InviteMembersButton(
          hubId: hubId,
        ),

        const SizedBox(height: 15),

        ManageHubButton(
          hubId: hubId,
        ),
      ],
    );
  }
}