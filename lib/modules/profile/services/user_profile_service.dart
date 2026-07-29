import 'package:firebase_auth/firebase_auth.dart';

import '../../../repositories/member_repository.dart';
import '../../../repositories/shared_budget_repository.dart';
import '../../../repositories/gub_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../community/models/community_model.dart';
import '../../community/services/community_service.dart';
import '../../gub_calendar/repositories/event_repository.dart';
import '../../proposals/repositories/proposal_repository.dart';
import '../../tasks/repositories/task_repository.dart';
import '../models/user_profile_model.dart';

class UserProfileService {
  UserProfileService._();

  static final UserProfileService instance = UserProfileService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserProfileModel> loadPersonalProfile({required String userId}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid != userId) {
      throw StateError("You must be signed in to view your profile.");
    }

    final userData = await UserRepository.instance.getUser(userId);
    final displayName = _firstNonEmptyString([
      userData?["displayName"],
      currentUser.displayName,
    ]);
    final photoUrl = _firstNonEmptyString([
      userData?["photoUrl"],
      userData?["photoURL"],
      currentUser.photoURL,
    ]);

    return UserProfileModel(
      userId: userId,
      displayName: displayName ?? "User",
      photoUrl: photoUrl,
      isCurrentUser: true,
    );
  }

  Stream<List<PersonalGubModel>> personalGubsStream({required String userId}) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null || currentUserId != userId) {
      return Stream.error(
        StateError("You must be signed in to view your Gubs."),
      );
    }

    return GubRepository.instance
        .userGubsStream(userId)
        .map(
          (gubs) => [
            for (final gub in gubs)
              PersonalGubModel(
                gubId: _asNonEmptyString(gub["gubId"]) ?? "",
                name: _asNonEmptyString(gub["name"]) ?? "Unnamed Gub",
                role: _asNonEmptyString(gub["role"]),
                isFounder: gub["isFounder"] == true,
                joinedAt: gub["joinedAtDate"] is DateTime
                    ? gub["joinedAtDate"] as DateTime
                    : null,
              ),
          ].where((gub) => gub.gubId.isNotEmpty).toList(growable: false),
        );
  }

  Stream<List<CommunityMembershipModel>> personalCommunitiesStream({
    required String userId,
  }) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null || currentUserId != userId) {
      return Stream.error(
        StateError("You must be signed in to view your Communities."),
      );
    }
    return CommunityService.instance.myCommunityMembershipsStream();
  }

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
    final photoUrl = _firstNonEmptyString([
      userData?["photoUrl"],
      userData?["photoURL"],
      targetMembership["photoUrl"],
    ]);

    return UserProfileModel(
      userId: userId,
      displayName: displayName ?? "Unknown user",
      photoUrl: photoUrl,
      role: _asNonEmptyString(targetMembership["role"]),
      isCurrentUser: currentUserId == userId,
    );
  }

  Stream<List<UserActivityEntry>> activityStream({
    required String gubId,
    required String userId,
    required UserActivityType type,
  }) {
    return switch (type) {
      UserActivityType.tasks => _taskActivityStream(gubId, userId),
      UserActivityType.proposals => _proposalActivityStream(gubId, userId),
      UserActivityType.events => _eventActivityStream(gubId, userId),
      UserActivityType.sharedBudget => _sharedBudgetActivityStream(
        gubId,
        userId,
      ),
    };
  }

  Stream<List<UserActivityEntry>> _taskActivityStream(
    String gubId,
    String userId,
  ) {
    return TaskRepository.instance.profileActivityCandidatesStream(gubId).map((
      tasks,
    ) {
      final activities = <UserActivityEntry>[];

      for (final task in tasks) {
        final kind = task.completedBy == userId
            ? UserActivityKind.taskCompleted
            : task.creatorId == userId
            ? UserActivityKind.taskCreated
            : task.assignedUserId == userId
            ? UserActivityKind.taskAssigned
            : null;
        if (kind == null) continue;

        activities.add(
          UserActivityEntry(
            id: task.taskId,
            title: task.title,
            status: task.status,
            kind: kind,
            occurredAt: kind == UserActivityKind.taskCompleted
                ? task.completedAt ?? task.createdAt
                : task.createdAt,
            task: task,
          ),
        );
      }

      return _sortActivities(activities);
    });
  }

  Stream<List<UserActivityEntry>> _proposalActivityStream(
    String gubId,
    String userId,
  ) {
    return ProposalRepository.instance
        .profileActivityCandidatesStream(gubId)
        .map(
          (proposals) => _sortActivities([
            for (final proposal in proposals)
              if (proposal.creatorId == userId)
                UserActivityEntry(
                  id: proposal.proposalId,
                  title: proposal.title,
                  status: proposal.status,
                  kind: UserActivityKind.proposalCreated,
                  occurredAt: proposal.createdAt,
                  proposal: proposal,
                ),
          ]),
        );
  }

  Stream<List<UserActivityEntry>> _eventActivityStream(
    String gubId,
    String userId,
  ) {
    return EventRepository.instance
        .profileActivityCandidatesStream(gubId)
        .map(
          (events) => _sortActivities([
            for (final event in events)
              if (event.creatorId == userId)
                UserActivityEntry(
                  id: event.eventId,
                  title: event.title,
                  status: event.status,
                  kind: UserActivityKind.eventCreated,
                  occurredAt: event.createdAt,
                  event: event,
                ),
          ]),
        );
  }

  Stream<List<UserActivityEntry>> _sharedBudgetActivityStream(
    String gubId,
    String userId,
  ) {
    return SharedBudgetRepository.instance
        .profileActivityCandidatesStream(gubId)
        .map(
          (sharedBudgets) => _sortActivities([
            for (final sharedBudget in sharedBudgets)
              if (sharedBudget.ownerId == userId)
                UserActivityEntry(
                  id: sharedBudget.sharedBudgetId,
                  title: sharedBudget.title,
                  status: sharedBudget.status,
                  kind: UserActivityKind.sharedBudgetCreated,
                  occurredAt: sharedBudget.createdAt,
                  sharedBudget: sharedBudget,
                ),
          ]),
        );
  }

  List<UserActivityEntry> _sortActivities(List<UserActivityEntry> activities) {
    activities.sort((first, second) {
      final dateComparison = second.occurredAt.compareTo(first.occurredAt);
      return dateComparison != 0
          ? dateComparison
          : second.id.compareTo(first.id);
    });
    return activities;
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
