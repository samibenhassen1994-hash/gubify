import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/errors/active_creation_limit_exception.dart';
import '../../../core/models/creation_availability.dart';
import '../../../core/models/deletion_context.dart';
import '../../../repositories/creation_cooldown_repository.dart';
import '../../../repositories/gub_repository.dart';
import '../../../services/app_sound_service.dart';
import '../models/proposal_model.dart';
import '../repositories/proposal_repository.dart';
import 'proposal_engine.dart';
import '../../gub_calendar/services/event_service.dart';
import '../../notifications/services/notification_service.dart';

class ProposalService {
  ProposalService._();

  static final ProposalService instance = ProposalService._();

  final Set<String> _creationsInProgress = {};

  Future<CreationAvailability> creationAvailability({
    required String gubId,
    String? creatorId,
  }) async {
    final effectiveCreatorId =
        creatorId ?? FirebaseAuth.instance.currentUser?.uid;
    if (effectiveCreatorId == null) {
      throw StateError("You must be signed in to create a proposal.");
    }
    if (await GubRepository.instance.isAuthoritativeOwner(
      gubId: gubId,
      userId: effectiveCreatorId,
    )) {
      return const CreationAvailability(isUnlimited: true);
    }

    final activeFuture = ProposalRepository.instance.getActiveProposalCreatedBy(
      gubId: gubId,
      creatorId: effectiveCreatorId,
    );
    final cooldownFuture = CreationCooldownRepository.instance.get(
      gubId: gubId,
      creatorId: effectiveCreatorId,
      moduleType: CreationModuleType.proposal,
    );
    final results = await Future.wait<Object?>([activeFuture, cooldownFuture]);
    final activeProposal = results[0] as ProposalModel?;
    final cooldown = results[1] as CreationCooldown?;
    return CreationAvailability(
      activeItemId: activeProposal?.proposalId,
      activeItemTitle: activeProposal?.title,
      activeItem: activeProposal,
      cooldown: cooldown,
    );
  }

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
    await GubRepository.instance.ensureActive(proposal.gubId);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || currentUserId != proposal.creatorId) {
      throw StateError("You must be signed in as the proposal creator.");
    }

    final creationKey = "${proposal.gubId}/${proposal.creatorId}";
    if (!_creationsInProgress.add(creationKey)) {
      throw StateError("A proposal creation is already in progress.");
    }

    try {
      final availability = await creationAvailability(
        gubId: proposal.gubId,
        creatorId: proposal.creatorId,
      );
      if (availability.hasActiveItem) {
        throw const ActiveCreationLimitException(
          "You already have an active proposal. Close it before creating another one.",
        );
      }
      if (availability.isCoolingDown) {
        throw CreationCooldownException(
          "You can create another proposal in "
          "${formatCooldownRemaining(availability.cooldown!.remaining)}.",
        );
      }

      await ProposalRepository.instance.createProposal(proposal);
      await AppSoundService.instance.playCreated();

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
    } finally {
      _creationsInProgress.remove(creationKey);
    }
  }

  Future<void> vote({
    required String gubId,
    required String proposalId,
    required String uid,
    required String vote,
  }) async {
    await GubRepository.instance.ensureActive(gubId);
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

  Future<void> deleteProposal({
    required String gubId,
    required String proposalId,
  }) async {
    await GubRepository.instance.ensureActive(gubId);
    if (!await canDeleteProposal(gubId: gubId, proposalId: proposalId)) {
      throw StateError("You don't have permission to delete this proposal.");
    }
    await ProposalRepository.instance.deleteProposal(
      gubId: gubId,
      proposalId: proposalId,
    );
  }

  Future<bool> canDeleteProposal({
    required String gubId,
    required String proposalId,
  }) {
    return ProposalRepository.instance.canDeleteProposal(
      gubId: gubId,
      proposalId: proposalId,
    );
  }

  Future<DeletionContext> deletionContext({
    required String gubId,
    required String proposalId,
  }) {
    return ProposalRepository.instance.deletionContext(
      gubId: gubId,
      proposalId: proposalId,
    );
  }
}
