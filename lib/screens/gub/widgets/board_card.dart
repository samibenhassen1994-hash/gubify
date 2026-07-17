import 'package:flutter/material.dart';

import '../board_screen.dart';

class BoardCard extends StatelessWidget {
  final String hubId;

  const BoardCard({super.key, required this.hubId});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.campaign),
        title: const Text("Board"),
        subtitle: const Text("All group activities will appear here."),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BoardScreen(hubId: hubId)),
          );
        },
      ),
    );
  }
}
