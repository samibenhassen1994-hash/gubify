import 'package:flutter/material.dart';

class TaskStatusChip extends StatelessWidget {
  final String status;

  const TaskStatusChip({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case "completed":
        return const Chip(
          label: Text("Completed"),
          avatar: Icon(
            Icons.check_circle,
            size: 18,
          ),
        );

      case "active":
      default:
        return const Chip(
          label: Text("Active"),
          avatar: Icon(
            Icons.pending_actions,
            size: 18,
          ),
        );
    }
  }
}