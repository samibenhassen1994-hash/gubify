import 'package:flutter/material.dart';

class InviteCodeCard extends StatelessWidget {
  final String inviteCode;

  const InviteCodeCard({super.key, required this.inviteCode});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.vpn_key),
        title: const Text("Invite Code"),
        subtitle: Text(inviteCode),
      ),
    );
  }
}
