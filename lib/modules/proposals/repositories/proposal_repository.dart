import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/proposal_model.dart';

class ProposalRepository {
  ProposalRepository._();

  static final ProposalRepository instance = ProposalRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> proposalsCollection(String hubId) {
    return _firestore
        .collection("hubs")
        .doc(hubId)
        .collection("proposals");
  }

  Future<void> createProposal(ProposalModel proposal) async {
    await proposalsCollection(proposal.hubId)
        .doc(proposal.proposalId)
        .set(proposal.toFirestore());
  }

  Future<void> updateProposal(ProposalModel proposal) async {
    await proposalsCollection(proposal.hubId)
        .doc(proposal.proposalId)
        .update(proposal.toFirestore());
  }

  Future<void> deleteProposal({
    required String hubId,
    required String proposalId,
  }) async {
    await proposalsCollection(hubId).doc(proposalId).delete();
  }

  Future<ProposalModel?> getProposal({
    required String hubId,
    required String proposalId,
  }) async {
    final doc = await proposalsCollection(hubId).doc(proposalId).get();
    if (!doc.exists) return null;
    return ProposalModel.fromFirestore(doc.data()!);
  }

  Stream<ProposalModel?> proposalStream({
    required String hubId,
    required String proposalId,
  }) {
    return proposalsCollection(hubId).doc(proposalId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ProposalModel.fromFirestore(doc.data()!);
    });
  }

  Stream<List<ProposalModel>> proposalsStream(String hubId) {
    return proposalsCollection(hubId)
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ProposalModel.fromFirestore(doc.data()))
            .toList());
  }

  Future<void> vote({
    required String hubId,
    required String proposalId,
    required String uid,
    required String vote,
  }) async {
    await proposalsCollection(hubId)
        .doc(proposalId)
        .collection("votes")
        .doc(uid)
        .set({
      "uid": uid,
      "vote": vote,
      "votedAt": Timestamp.now(),
    });
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getVotes({
    required String hubId,
    required String proposalId,
  }) {
    return proposalsCollection(hubId)
        .doc(proposalId)
        .collection("votes")
        .get();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> votesStream({
    required String hubId,
    required String proposalId,
  }) {
    return proposalsCollection(hubId)
        .doc(proposalId)
        .collection("votes")
        .snapshots();
  }

  Stream<String?> userVoteStream({
    required String hubId,
    required String proposalId,
    required String uid,
  }) {
    return proposalsCollection(hubId)
        .doc(proposalId)
        .collection("votes")
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return doc.data()?["vote"] as String?;
    });
  }
}
