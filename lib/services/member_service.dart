import '../repositories/member_repository.dart';
import '../repositories/goal_repository.dart';

class MemberService {
  MemberService._();

  static final MemberService instance = MemberService._();

  Future<void> removeMember({
    required String gubId,
    required String uid,
    required String ownerId,
    required String currentUserId,
  }) async {
    // Solo il proprietario può rimuovere membri
    if (currentUserId != ownerId) {
      throw Exception("Only the Hub owner can remove members.");
    }

    // Il proprietario non può rimuovere sé stesso
    if (uid == ownerId) {
      throw Exception("The Hub owner cannot remove themselves.");
    }

    // Rimuove il membro
    await MemberRepository.instance.removeMember(gubId: gubId, uid: uid);
    await GoalRepository.instance.removeMemberFromAllGoals(
      gubId: gubId,
      uid: uid,
    );
    // Aggiorna il numero di membri
    final memberCount = await MemberRepository.instance.getMemberCount(gubId);

    await MemberRepository.instance.updateMemberCount(
      gubId: gubId,
      memberCount: memberCount,
    );
  }
}
