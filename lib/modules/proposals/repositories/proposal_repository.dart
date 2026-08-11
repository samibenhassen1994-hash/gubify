import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/models/creation_availability.dart';
import '../../../core/models/deletion_context.dart';
import '../../../repositories/creation_cooldown_repository.dart';
import '../models/proposal_model.dart';

class ProposalRepository {
  ProposalRepository._();

  static final ProposalRepository instance = ProposalRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> proposalsCollection(String gubId) {
    return _firestore.collection("gubs").doc(gubId).collection("proposals");
  }

  Future<void> createProposal(ProposalModel proposal) async {
    await proposalsCollection(
      proposal.gubId,
    ).doc(proposal.proposalId).set(proposal.toFirestore());
  }

  Future<bool> hasActiveProposalCreatedBy({
    required String gubId,
    required String creatorId,
  }) async =>
      await getActiveProposalCreatedBy(gubId: gubId, creatorId: creatorId) !=
      null;

  Future<ProposalModel?> getActiveProposalCreatedBy({
    required String gubId,
    required String creatorId,
  }) async {
    final snapshot = await proposalsCollection(gubId)
        .where("creatorId", isEqualTo: creatorId)
        .where("status", isEqualTo: "voting")
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final document = snapshot.docs.first;
    return ProposalModel.fromFirestore({
      ...document.data(),
      "proposalId": document.data()["proposalId"] ?? document.id,
      "gubId": document.data()["gubId"] ?? gubId,
    });
  }

  Future<void> updateProposal(ProposalModel proposal) async {
    final reference = proposalsCollection(
      proposal.gubId,
    ).doc(proposal.proposalId);
    await _firestore.runTransaction((transaction) async {
      final gubSnapshot = await transaction.get(
        _firestore.collection('gubs').doc(proposal.gubId),
      );
      final snapshot = await transaction.get(reference);
      if (!gubSnapshot.exists ||
          gubSnapshot.data()?['deletionStatus'] == 'deleting') {
        throw StateError('This Gub is no longer available.');
      }
      if (!snapshot.exists || _isDeleted(snapshot.data())) {
        throw StateError("Proposal not found.");
      }
      transaction.update(reference, proposal.toFirestore());
    });
  }

  Future<void> deleteProposal({
    required String gubId,
    required String proposalId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError("You must be signed in to delete a proposal.");
    }

    final proposalReference = proposalsCollection(gubId).doc(proposalId);
    final gubReference = _firestore.collection("gubs").doc(gubId);
    final availableAt = Timestamp.fromDate(
      DateTime.now().add(CreationCooldownRepository.cooldownDuration),
    );

    await _firestore.runTransaction((transaction) async {
      final proposalSnapshot = await transaction.get(proposalReference);
      final gubSnapshot = await transaction.get(gubReference);
      if (!proposalSnapshot.exists) {
        throw StateError("Proposal not found.");
      }
      if (!gubSnapshot.exists) throw StateError("Gub not found.");
      if (gubSnapshot.data()?['deletionStatus'] == 'deleting') {
        throw StateError('This Gub is no longer available.');
      }

      final creatorId = proposalSnapshot.data()?["creatorId"] as String? ?? "";
      final gubOwnerId = gubSnapshot.data()?["ownerId"] as String? ?? "";
      if (user.uid != creatorId && user.uid != gubOwnerId) {
        throw StateError("You don't have permission to delete this proposal.");
      }

      transaction.update(proposalReference, {
        "status": "deleted",
        "deletedAt": FieldValue.serverTimestamp(),
        "deletedBy": user.uid,
      });
      if (creatorId.isNotEmpty && creatorId != gubOwnerId) {
        CreationCooldownRepository.instance.setInTransaction(
          transaction: transaction,
          gubId: gubId,
          creatorId: creatorId,
          moduleType: CreationModuleType.proposal,
          deletedItemId: proposalId,
          deletedBy: user.uid,
          availableAt: availableAt,
        );
      }
    });
  }

  Future<bool> canDeleteProposal({
    required String gubId,
    required String proposalId,
  }) async {
    return (await deletionContext(
      gubId: gubId,
      proposalId: proposalId,
    )).canDelete;
  }

  Future<DeletionContext> deletionContext({
    required String gubId,
    required String proposalId,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return const DeletionContext(
        canDelete: false,
        currentUserIsOwner: false,
        creatorId: null,
        ownerId: '',
      );
    }

    final documents = await Future.wait([
      proposalsCollection(gubId).doc(proposalId).get(),
      _firestore.collection("gubs").doc(gubId).get(),
    ]);
    final proposal = documents[0];
    final gub = documents[1];
    final creatorId = _nonEmptyString(proposal.data()?["creatorId"]);
    final ownerId = _nonEmptyString(gub.data()?["ownerId"]) ?? "";
    return DeletionContext(
      canDelete:
          proposal.exists &&
          gub.exists &&
          !_isDeleted(proposal.data()) &&
          (userId == creatorId || userId == ownerId),
      currentUserIsOwner: userId == ownerId,
      creatorId: creatorId,
      ownerId: ownerId,
    );
  }

  Future<ProposalModel?> getProposal({
    required String gubId,
    required String proposalId,
  }) async {
    final doc = await proposalsCollection(gubId).doc(proposalId).get();
    if (!doc.exists || _isDeleted(doc.data())) return null;
    return ProposalModel.fromFirestore(doc.data()!);
  }

  Stream<ProposalModel?> proposalStream({
    required String gubId,
    required String proposalId,
  }) {
    return proposalsCollection(gubId).doc(proposalId).snapshots().map((doc) {
      if (!doc.exists || _isDeleted(doc.data())) return null;
      return ProposalModel.fromFirestore(doc.data()!);
    });
  }

  Stream<List<ProposalModel>> proposalsStream(
    String gubId, {
    required Timestamp membershipBoundary,
  }) {
    return proposalsCollection(gubId)
        .where(
          Filter.or(
            Filter('status', isEqualTo: 'voting'),
            Filter.and(
              Filter('status', whereIn: const ['approved', 'rejected']),
              Filter('resolvedAt', isGreaterThanOrEqualTo: membershipBoundary),
            ),
          ),
        )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .where((doc) => !_isDeleted(doc.data()))
              .map((doc) => ProposalModel.fromFirestore(doc.data()))
              .toList(),
        );
  }

  Stream<List<ProposalModel>> profileActivityCandidatesStream(
    String gubId, {
    required Timestamp membershipBoundary,
  }) => proposalsStream(gubId, membershipBoundary: membershipBoundary);

  Future<void> vote({
    required String gubId,
    required String proposalId,
    required String uid,
    required String vote,
  }) async {
    final gubReference = _firestore.collection('gubs').doc(gubId);
    final voteReference = proposalsCollection(
      gubId,
    ).doc(proposalId).collection('votes').doc(uid);
    await _firestore.runTransaction((transaction) async {
      final gub = await transaction.get(gubReference);
      if (!gub.exists || gub.data()?['deletionStatus'] == 'deleting') {
        throw StateError('This Gub is no longer available.');
      }
      transaction.set(voteReference, {
        'uid': uid,
        'vote': vote,
        'votedAt': Timestamp.now(),
      });
    });
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

  bool _isDeleted(Map<String, dynamic>? data) {
    return data?["status"] == "deleted" || data?["deletedAt"] != null;
  }

  String? _nonEmptyString(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value;
  }
}
