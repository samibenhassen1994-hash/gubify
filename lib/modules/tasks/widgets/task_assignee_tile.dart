import 'package:flutter/material.dart';

import '../../chat/widgets/deleted_user_identity_builder.dart';
import '../../../repositories/user_repository.dart';

class TaskAssigneeTile extends StatelessWidget {
  final String? assignedUserId;
  final String? assignedUserName;
  final Stream<UserIdentity>? identity;

  const TaskAssigneeTile({
    super.key,
    this.assignedUserId,
    this.assignedUserName,
    this.identity,
  });

  @override
  Widget build(BuildContext context) {
    final hasAssignee =
        assignedUserId?.trim().isNotEmpty == true ||
        assignedUserName?.trim().isNotEmpty == true;

    if (!hasAssignee) {
      return _buildTile(context, 'Unassigned');
    }

    final hasStableIdentity = assignedUserId?.trim().isNotEmpty == true;
    if (!hasStableIdentity) {
      return _buildTile(context, assignedUserName!.trim());
    }

    return DeletedUserIdentityBuilder(
      userId: assignedUserId!,
      currentDisplayName: assignedUserName ?? '',
      identity: identity,
      resolveCurrentDisplayName: true,
      builder: (context, displayName, deleted) =>
          _buildTile(context, displayName),
    );
  }

  Widget _buildTile(BuildContext context, String displayName) {
    return Row(
      children: [
        const Icon(Icons.person_outline, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
