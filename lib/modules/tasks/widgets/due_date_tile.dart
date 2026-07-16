import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DueDateTile extends StatelessWidget {
  final Timestamp? dueDate;
  final VoidCallback onTap;

  const DueDateTile({
    super.key,
    required this.dueDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.schedule),
      title: const Text("Due date"),
      subtitle: Text(
        dueDate == null
            ? "No due date"
            : "${dueDate!.toDate().day}/${dueDate!.toDate().month}/${dueDate!.toDate().year}",
      ),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: onTap,
    );
  }
}