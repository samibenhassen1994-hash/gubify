import 'package:flutter/material.dart';

import '../../../repositories/user_repository.dart';
import '../../chat/widgets/deleted_user_identity_builder.dart';
import '../models/notification_model.dart';

class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.notification,
    required this.trailing,
    this.onTap,
    this.identity,
  });

  final NotificationModel notification;
  final VoidCallback? onTap;
  final Widget trailing;
  final Stream<UserIdentity>? identity;

  @override
  Widget build(BuildContext context) {
    final senderId = notification.senderId.trim();
    return DeletedUserIdentityBuilder(
      userId: senderId,
      currentDisplayName: notification.senderName,
      resolveCurrentDisplayName:
          senderId.isNotEmpty && senderId != '__deleted_user__',
      identity: identity,
      builder: (context, displayName, _) => Card(
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          onTap: onTap,
          leading: const CircleAvatar(child: Icon(Icons.notifications)),
          title: Text(notification.title),
          subtitle: Text(_bodyWithCurrentSender(displayName)),
          trailing: trailing,
        ),
      ),
    );
  }

  String _bodyWithCurrentSender(String displayName) {
    final value = notification.body;
    final snapshotName = notification.senderName.trim();
    if (snapshotName.isNotEmpty && value.contains(snapshotName)) {
      return value.replaceFirst(snapshotName, displayName);
    }
    return value.isEmpty ? displayName : '$displayName · $value';
  }
}
