import '../models/proposal_model.dart';
import '../repositories/proposal_repository.dart';
import 'proposal_engine.dart';
import '../../gub_calendar/services/event_service.dart';
import '../../notifications/services/notification_service.dart';

class ProposalService {
  ProposalService._();

  static final ProposalService instance = ProposalService._();

  Stream<List<ProposalModel>> proposalsStream(String gubId) {
    return ProposalRepository.instance.proposalsStream(gubId);
  }

  Stream<ProposalModel?> proposalStream({
    required String gubId,
    required String proposalId,
  }) {
    return ProposalRepository.instance.proposalStream(
      gubId: gubId,
      proposalId: proposalId,
    );
  }

  Stream<String?> userVoteStream({
    required String gubId,
    required String proposalId,
    required String uid,
  }) {
    return ProposalRepository.instance.userVoteStream(
      gubId: gubId,
      proposalId: proposalId,
      uid: uid,
    );
  }

  Future<void> createProposal({required ProposalModel proposal}) async {
    await ProposalRepository.instance.createProposal(proposal);

    await NotificationService.instance.send(
      gubId: proposal.gubId,
      title: "New proposal",
      body: "${proposal.creatorName} created a new proposal.",
      type: "proposal_created",
      senderId: proposal.creatorId,
      senderName: proposal.creatorName,
      markSenderAsRead: true,
      data: {"screen": "proposal", "proposalId": proposal.proposalId},
    );
  }

  Future<void> vote({
    required String gubId,
    required String proposalId,
    required String uid,
    required String vote,
  }) async {
    final existingVote = await ProposalRepository.instance
        .userVoteStream(gubId: gubId, proposalId: proposalId, uid: uid)
        .first;

    if (existingVote != null) return;

    await ProposalRepository.instance.vote(
      gubId: gubId,
      proposalId: proposalId,
      uid: uid,
      vote: vote,
    );

    final proposal = await ProposalRepository.instance.getProposal(
      gubId: gubId,
      proposalId: proposalId,
    );

    if (proposal == null) return;

    if (proposal.resultProcessed) {
      return;
    }
    final votes = await ProposalRepository.instance.getVotes(
      gubId: gubId,
      proposalId: proposalId,
    );

    int yesVotes = 0;
    int noVotes = 0;

    for (final doc in votes.docs) {
      final data = doc.data();

      if (data["vote"] == "yes") yesVotes++;
      if (data["vote"] == "no") noVotes++;
    }

    await ProposalRepository.instance.updateProposal(
      proposal.copyWith(yesVotes: yesVotes, noVotes: noVotes),
    );

    final result = ProposalEngine.instance.checkResult(
      yesVotes: yesVotes,
      noVotes: noVotes,
      memberCount: proposal.memberCount,
    );

    if (result == ProposalResult.approved) {
      final updatedProposal = proposal.copyWith(
        yesVotes: yesVotes,
        noVotes: noVotes,
        status: "approved",
        resultProcessed: true,
      );

      await ProposalRepository.instance.updateProposal(updatedProposal);

      await NotificationService.instance.send(
        gubId: updatedProposal.gubId,
        title: "Proposal approved",
        body: "\"${updatedProposal.title}\" has been approved.",
        type: "proposal_approved",
        senderId: updatedProposal.creatorId,
        senderName: updatedProposal.creatorName,
        markSenderAsRead: false,
        data: {"screen": "calendar", "proposalId": updatedProposal.proposalId},
      );

      await EventService.instance.createFromProposal(updatedProposal);
    }

    if (result == ProposalResult.rejected) {
      final updatedProposal = proposal.copyWith(
        yesVotes: yesVotes,
        noVotes: noVotes,
        status: "rejected",
        resultProcessed: true,
      );

      await ProposalRepository.instance.updateProposal(updatedProposal);

      await NotificationService.instance.send(
        gubId: updatedProposal.gubId,
        title: "Proposal rejected",
        body: "\"${updatedProposal.title}\" has been rejected.",
        type: "proposal_rejected",
        senderId: updatedProposal.creatorId,
        senderName: updatedProposal.creatorName,
        data: {"screen": "proposal", "proposalId": updatedProposal.proposalId},
      );
    }
  }
}
