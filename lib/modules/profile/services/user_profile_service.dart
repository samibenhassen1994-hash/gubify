import 'package:firebase_auth/firebase_auth.dart';

import '../../../repositories/member_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../tasks/repositories/task_repository.dart';
import '../models/user_profile_model.dart';

class UserProfileService {
  UserProfileService._();

  static final UserProfileService instance = UserProfileService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserProfileModel?> loadProfile({
    required String gubId,
    required String userId,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      throw StateError("You must be signed in to view profiles.");
    }

    final memberships = await Future.wait<Map<String, dynamic>?>([
      MemberRepository.instance.getMember(gubId: gubId, uid: currentUserId),
      MemberRepository.instance.getMember(gubId: gubId, uid: userId),
    ]);

    if (memberships.first == null) {
      throw StateError("You no longer have access to this Gub.");
    }

    final targetMembership = memberships.last;
    if (targetMembership == null) return null;

    Map<String, dynamic>? userData;
    try {
      userData = await UserRepository.instance.getUser(userId);
    } catch (_) {
      // Membership data remains a safe fallback if user documents are private.
    }

    final displayName = _firstNonEmptyString([
      userData?["displayName"],
      targetMembership["displayName"],
    ]);
    final photoUrl = _firstNonEmptyString([targetMembership["photoUrl"]]);

    return UserProfileModel(
      userId: userId,
      displayName: displayName ?? "Unknown user",
      photoUrl: photoUrl,
      role: _asNonEmptyString(targetMembership["role"]),
      isCurrentUser: currentUserId == userId,
    );
  }

  Stream<List<UserTaskActivity>> taskActivityStream({
    required String gubId,
    required String userId,
  }) {
    return TaskRepository.instance.tasksStream(gubId).map((tasks) {
      final activities = <UserTaskActivity>[];

      for (final task in tasks) {
        if (task.completedBy == userId) {
          activities.add(
            UserTaskActivity(
              task: task,
              type: UserTaskActivityType.completed,
              occurredAt: task.completedAt ?? task.createdAt,
            ),
          );
        } else if (task.creatorId == userId) {
          activities.add(
            UserTaskActivity(
              task: task,
              type: UserTaskActivityType.created,
              occurredAt: task.createdAt,
            ),
          );
        } else if (task.assignedUserId == userId) {
          activities.add(
            UserTaskActivity(
              task: task,
              type: UserTaskActivityType.assigned,
              occurredAt: task.createdAt,
            ),
          );
        }
      }

      activities.sort(
        (first, second) => second.occurredAt.compareTo(first.occurredAt),
      );
      return activities;
    });
  }

  String? _firstNonEmptyString(List<Object?> values) {
    for (final value in values) {
      final normalized = _asNonEmptyString(value);
      if (normalized != null) return normalized;
    }
    return null;
  }

  String? _asNonEmptyString(Object? value) {
    if (value is! String) return null;
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
