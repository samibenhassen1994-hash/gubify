import 'package:flutter/material.dart';

import '../invite_members_screen.dart';

class InviteMembersButton extends StatelessWidget {
  final String gubId;

  const InviteMembersButton({super.key, required this.gubId});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: FilledButton.icon(
        icon: const Icon(Icons.person_add),
        label: const Text("Invite Members"),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InviteMembersScreen(gubId: gubId),
            ),
          );
        },
      ),
    );
  }
}
