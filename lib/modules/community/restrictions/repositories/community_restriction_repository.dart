import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/community_restriction_model.dart';

class CommunityRestrictionRepository {
  CommunityRestrictionRepository._();

  static final CommunityRestrictionRepository instance =
      CommunityRestrictionRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<PlatformRestriction> platformRestrictionStream(String userId) {
    return _firestore
        .collection('platformRestrictions')
        .doc(userId)
        .snapshots()
        .map((document) => PlatformRestriction.fromFirestore(document.data()));
  }

  /// Creates the immutable client-side baseline once, without ever changing
  /// an existing moderation decision.
  Future<bool> initializePlatformRestriction(String userId) {
    final reference = _firestore.collection('platformRestrictions').doc(userId);
    return _firestore.runTransaction<bool>((transaction) async {
      final snapshot = await transaction.get(reference);
      if (snapshot.exists) return false;

      transaction.set(reference, {
        'communityChatRestricted': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  Stream<CommunityRestriction> communityRestrictionStream(String communityId) {
    return _firestore
        .collection('communityRestrictions')
        .doc(communityId)
        .snapshots()
        .map((document) => CommunityRestriction.fromFirestore(document.data()));
  }

  /// Creates the safe Community baseline once for its owner. The transaction
  /// deliberately leaves any existing manual moderation decision untouched.
  Future<bool> initializeCommunityRestriction({
    required String communityId,
    required String ownerId,
  }) {
    final communityReference = _firestore
        .collection('communities')
        .doc(communityId);
    final restrictionReference = _firestore
        .collection('communityRestrictions')
        .doc(communityId);
    return _firestore.runTransaction<bool>((transaction) async {
      final communitySnapshot = await transaction.get(communityReference);
      final restrictionSnapshot = await transaction.get(restrictionReference);
      if (!communitySnapshot.exists || restrictionSnapshot.exists) return false;

      final community = communitySnapshot.data();
      if (community?['ownerId'] != ownerId ||
          community?['visibility'] != 'public' ||
          community?['deletionStatus'] == 'deleting') {
        return false;
      }

      transaction.set(restrictionReference, {
        'hiddenFromDiscovery': false,
        'joiningRestricted': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  Future<Set<String>> hiddenCommunityIds(Iterable<String> communityIds) async {
    final uniqueIds = communityIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final snapshots = await Future.wait(
      uniqueIds.map(
        (communityId) => _firestore
            .collection('communityRestrictions')
            .doc(communityId)
            .get(),
      ),
    );
    return {
      for (final document in snapshots)
        if (CommunityRestriction.fromFirestore(
          document.data(),
        ).hiddenFromDiscovery)
          document.id,
    };
  }
}
