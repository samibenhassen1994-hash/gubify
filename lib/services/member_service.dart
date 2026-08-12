import 'package:firebase_auth/firebase_auth.dart';

import '../repositories/gub_repository.dart';
import '../repositories/member_repository.dart';
import '../repositories/shared_budget_repository.dart';
import '../modules/tasks/repositories/task_repository.dart';

class MemberService {
  MemberService._();

  static final MemberService instance = MemberService._();

  Stream<List<Map<String, dynamic>>> bannedUsersStream(String gubId) =>
      MemberRepository.instance.bannedUsersStream(gubId);

  Future<void> unbanMember({required String gubId, required String uid}) =>
      MemberRepository.instance.unbanMember(gubId: gubId, uid: uid);

  Future<void> removeMember({
    required String gubId,
    required String uid,
    required String ownerId,
    required String currentUserId,
  }) async {
    final gub = await GubRepository.instance.getHubAuthoritatively(gubId);
    final authoritativeOwnerId = gub?['ownerId'] as String?;
    if (gub == null || gub['deletionStatus'] == 'deleting') {
      throw Exception('This Gub is no longer available.');
    }
    // ownerId is retained for the UI API, but never trusted for authorization.
    if (currentUserId != authoritativeOwnerId) {
      throw Exception('Only the Hub owner can remove members.');
    }
    if (uid == authoritativeOwnerId) {
      throw Exception('The Hub owner cannot remove themselves.');
    }

    await _removeMemberAndCleanUp(
      gubId: gubId,
      uid: uid,
      actorId: currentUserId,
    );
  }

  Future<void> leaveGub({required String gubId}) async {
    final currentUserId = await _currentUserId();
    final gub = await GubRepository.instance.getHubAuthoritatively(gubId);
    final ownerId = gub?['ownerId'] as String?;
    if (gub == null || gub['deletionStatus'] == 'deleting') {
      throw Exception('This Gub is no longer available.');
    }
    if (ownerId == currentUserId) {
      throw Exception('The Gub owner cannot leave their own Gub.');
    }
    await _removeMemberAndCleanUp(
      gubId: gubId,
      uid: currentUserId,
      actorId: currentUserId,
    );
  }

  Future<void> banMember({
    required String gubId,
    required String uid,
    required String currentUserId,
  }) async {
    final gub = await GubRepository.instance.getHubAuthoritatively(gubId);
    final ownerId = gub?['ownerId'] as String?;
    if (ownerId == null || currentUserId != ownerId || uid == ownerId) {
      throw Exception('Only the Gub owner can ban members.');
    }
    await TaskRepository.instance.unassignActiveTasksForMember(
      gubId: gubId,
      uid: uid,
    );
    await SharedBudgetRepository.instance.removeMemberFromAllSharedBudgets(
      gubId: gubId,
      uid: uid,
    );
    await MemberRepository.instance.banMember(
      gubId: gubId,
      uid: uid,
      ownerId: ownerId,
    );
  }

  Future<void> _removeMemberAndCleanUp({
    required String gubId,
    required String uid,
    required String actorId,
  }) async {
    await TaskRepository.instance.unassignActiveTasksForMember(
      gubId: gubId,
      uid: uid,
    );
    await SharedBudgetRepository.instance.removeMemberFromAllSharedBudgets(
      gubId: gubId,
      uid: uid,
    );
    await MemberRepository.instance.removeMember(
      gubId: gubId,
      uid: uid,
      actorId: actorId,
    );
  }

  Future<String> _currentUserId() async {
    // The repository validates authorization again inside the transaction.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Please sign in again.');
    return user.uid;
  }
}
