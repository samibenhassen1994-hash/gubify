import 'package:flutter/material.dart';

class TaskAssigneeTile extends StatelessWidget {
  final String? assignedUserName;

  const TaskAssigneeTile({
    super.key,
    this.assignedUserName,
  });

  @override
  Widget build(BuildContext context) {
    final hasAssignee =
        assignedUserName != null &&
        assignedUserName!.trim().isNotEmpty;

    return Row(
      children: [
        const Icon(
          Icons.person_outline,
          size: 18,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            hasAssignee
                ? assignedUserName!
                : "Unassigned",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}