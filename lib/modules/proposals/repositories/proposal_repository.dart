import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/proposal_model.dart';

class ProposalRepository {
  ProposalRepository._();

  static final ProposalRepository instance = ProposalRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> proposalsCollection(String gubId) {
    return _firestore.collection("gubs").doc(gubId).collection("proposals");
  }

  Future<void> createProposal(ProposalModel proposal) async {
    await proposalsCollection(
      proposal.gubId,
    ).doc(proposal.proposalId).set(proposal.toFirestore());
  }

  Future<void> updateProposal(ProposalModel proposal) async {
    await proposalsCollection(
      proposal.gubId,
    ).doc(proposal.proposalId).update(proposal.toFirestore());
  }

  Future<void> deleteProposal({
    required String gubId,
    required String proposalId,
  }) async {
    await proposalsCollection(gubId).doc(proposalId).delete();
  }

  Future<ProposalModel?> getProposal({
    required String gubId,
    required String proposalId,
  }) async {
    final doc = await proposalsCollection(gubId).doc(proposalId).get();
    if (!doc.exists) return null;
    return ProposalModel.fromFirestore(doc.data()!);
  }

  Stream<ProposalModel?> proposalStream({
    required String gubId,
    required String proposalId,
  }) {
    return proposalsCollection(gubId).doc(proposalId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ProposalModel.fromFirestore(doc.data()!);
    });
  }

  Stream<List<ProposalModel>> proposalsStream(String gubId) {
    return proposalsCollection(gubId)
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ProposalModel.fromFirestore(doc.data()))
              .toList(),
        );
  }

  Future<void> vote({
    required String gubId,
    required String proposalId,
    required String uid,
    required String vote,
  }) async {
    await proposalsCollection(gubId)
        .doc(proposalId)
        .collection("votes")
        .doc(uid)
        .set({"uid": uid, "vote": vote, "votedAt": Timestamp.now()});
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getVotes({
    required String gubId,
    required String proposalId,
  }) {
    return proposalsCollection(gubId).doc(proposalId).collection("votes").get();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> votesStream({
    required String gubId,
    required String proposalId,
  }) {
    return proposalsCollection(
      gubId,
    ).doc(proposalId).collection("votes").snapshots();
  }

  Stream<String?> userVoteStream({
    required String gubId,
    required String proposalId,
    required String uid,
  }) {
    return proposalsCollection(
      gubId,
    ).doc(proposalId).collection("votes").doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return doc.data()?["vote"] as String?;
    });
  }
}
