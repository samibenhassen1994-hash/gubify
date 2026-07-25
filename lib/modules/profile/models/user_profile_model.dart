import 'package:cloud_firestore/cloud_firestore.dart';

import '../../tasks/models/task_model.dart';

class UserProfileModel {
  final String userId;
  final String displayName;
  final String? photoUrl;
  final String? role;
  final bool isCurrentUser;

  const UserProfileModel({
    required this.userId,
    required this.displayName,
    this.photoUrl,
    this.role,
    required this.isCurrentUser,
  });
}

enum UserTaskActivityType { created, assigned, completed }

class UserTaskActivity {
  final TaskModel task;
  final UserTaskActivityType type;
  final Timestamp occurredAt;

  const UserTaskActivity({
    required this.task,
    required this.type,
    required this.occurredAt,
  });
}
