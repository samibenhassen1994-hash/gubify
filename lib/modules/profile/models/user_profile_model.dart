import 'package:cloud_firestore/cloud_firestore.dart';

import '../../goals/models/goal_model.dart';
import '../../gub_calendar/models/event_model.dart';
import '../../proposals/models/proposal_model.dart';
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

class PersonalGubModel {
  final String gubId;
  final String name;
  final String? role;

  const PersonalGubModel({required this.gubId, required this.name, this.role});
}

enum UserActivityType { tasks, proposals, events, groupGoals, sharedBudget }

enum UserActivityKind {
  taskCreated,
  taskAssigned,
  taskCompleted,
  proposalCreated,
  eventCreated,
  sharedBudgetCreated,
}

class UserActivityEntry {
  final String id;
  final String title;
  final String status;
  final UserActivityKind kind;
  final Timestamp occurredAt;
  final TaskModel? task;
  final ProposalModel? proposal;
  final EventModel? event;
  final GoalModel? goal;

  const UserActivityEntry({
    required this.id,
    required this.title,
    required this.status,
    required this.kind,
    required this.occurredAt,
    this.task,
    this.proposal,
    this.event,
    this.goal,
  });
}
