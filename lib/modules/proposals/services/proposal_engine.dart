class ProposalEngine {
  ProposalEngine._();

  static final ProposalEngine instance = ProposalEngine._();

  ProposalResult checkResult({
    required int yesVotes,
    required int noVotes,
    required int memberCount,
  }) {
    final remainingVotes = memberCount - yesVotes - noVotes;

    // Approvata matematicamente
    if (yesVotes > noVotes + remainingVotes) {
      return ProposalResult.approved;
    }

    // Respinta matematicamente
    if (noVotes >= yesVotes + remainingVotes) {
      return ProposalResult.rejected;
    }

    return ProposalResult.pending;
  }
}

enum ProposalResult { pending, approved, rejected }
