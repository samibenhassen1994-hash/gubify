import 'package:flutter/material.dart';

import 'invite_members_button.dart';
import 'manage_gub_button.dart';

class GubActionsSection extends StatelessWidget {
  final String gubId;
  final VoidCallback? onExitToMyGubs;

  const GubActionsSection({
    super.key,
    required this.gubId,
    this.onExitToMyGubs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InviteMembersButton(gubId: gubId),

        const SizedBox(height: 15),

        ManageGubButton(
          gubId: gubId,
          onExitToMyGubs: onExitToMyGubs,
        ),
      ],
    );
  }
}
