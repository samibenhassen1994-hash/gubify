import 'package:flutter/material.dart';

import 'invite_members_button.dart';
import 'manage_gub_button.dart';

class GubActionsSection extends StatelessWidget {
  final String hubId;

  const GubActionsSection({super.key, required this.hubId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InviteMembersButton(hubId: hubId),

        const SizedBox(height: 15),

        ManageGubButton(hubId: hubId),
      ],
    );
  }
}
