import '../repositories/gub_repository.dart';
import '../repositories/member_repository.dart';
import '../repositories/shared_budget_repository.dart';

class MemberService {
  MemberService._();

  static final MemberService instance = MemberService._();

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

    await MemberRepository.instance.removeMember(gubId: gubId, uid: uid);
    await SharedBudgetRepository.instance.removeMemberFromAllSharedBudgets(
      gubId: gubId,
      uid: uid,
    );
    final memberCount = await MemberRepository.instance.getMemberCount(gubId);
    await MemberRepository.instance.updateMemberCount(
      gubId: gubId,
      memberCount: memberCount,
    );
  }
}
