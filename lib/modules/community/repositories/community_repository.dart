import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/community_model.dart';

class CommunityRepository {
  CommunityRepository._();

  static final CommunityRepository instance = CommunityRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _communities =>
      _firestore.collection("communities");

  Future<CommunityModel> createCommunity({
    required String name,
    required String ownerId,
    required String displayName,
    required String? photoUrl,
    required String type,
    required String language,
    required String description,
  }) async {
    final communityReference = _communities.doc();
    final communityId = communityReference.id;
    final localCreatedAt = Timestamp.now();
    final community = CommunityModel(
      communityId: communityId,
      name: name,
      ownerId: ownerId,
      memberCount: 1,
      visibility: CommunityModel.publicVisibility,
      createdAt: localCreatedAt,
      type: type,
      language: language,
      description: description,
    );
    final communityData = community.toFirestore()
      ..["createdAt"] = FieldValue.serverTimestamp();

    final batch = _firestore.batch();

    batch.set(communityReference, communityData);
    batch.set(communityReference.collection("members").doc(ownerId), {
      "uid": ownerId,
      "displayName": displayName,
      "photoUrl": photoUrl,
      "role": "owner",
      "joinedAt": FieldValue.serverTimestamp(),
    });
    batch.set(
      _firestore
          .collection("users")
          .doc(ownerId)
          .collection("communities")
          .doc(communityId),
      {
        "communityId": communityId,
        "name": name,
        "ownerId": ownerId,
        "memberCount": 1,
        "visibility": CommunityModel.publicVisibility,
        "joinedAt": FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
    return community;
  }

  Future<CommunityModel?> getCommunity(String communityId) async {
    final document = await _communities.doc(communityId).get();
    if (!document.exists) return null;

    return CommunityModel.fromFirestore(document);
  }

  Stream<List<CommunityModel>> publicCommunitiesStream() {
    return _communities
        .where("visibility", isEqualTo: CommunityModel.publicVisibility)
        .snapshots()
        .map((snapshot) {
          final communities = snapshot.docs
              .map(CommunityModel.fromFirestore)
              .toList(growable: false);
          communities.sort((first, second) {
            final firstMillis = first.createdAt?.millisecondsSinceEpoch ?? 0;
            final secondMillis = second.createdAt?.millisecondsSinceEpoch ?? 0;
            return secondMillis.compareTo(firstMillis);
          });
          return communities;
        });
  }

  Stream<Set<String>> userCommunityIdsStream(String userId) {
    return _firestore
        .collection("users")
        .doc(userId)
        .collection("communities")
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((document) => document.id).toSet(),
        );
  }

  Future<CommunityModel> joinCommunity({
    required String communityId,
    required String userId,
    required String displayName,
    required String? photoUrl,
  }) {
    final communityReference = _communities.doc(communityId);
    final memberReference = communityReference
        .collection("members")
        .doc(userId);
    final userCommunityReference = _firestore
        .collection("users")
        .doc(userId)
        .collection("communities")
        .doc(communityId);

    return _firestore.runTransaction((transaction) async {
      final communitySnapshot = await transaction.get(communityReference);
      if (!communitySnapshot.exists) {
        throw StateError("Community not found.");
      }

      final community = CommunityModel.fromFirestore(communitySnapshot);
      if (community.visibility != CommunityModel.publicVisibility) {
        throw StateError("This community is not public.");
      }

      final userCommunitySnapshot = await transaction.get(
        userCommunityReference,
      );
      if (userCommunitySnapshot.exists) return community;

      final updatedMemberCount = community.memberCount + 1;
      transaction.set(memberReference, {
        "uid": userId,
        "displayName": displayName,
        "photoUrl": photoUrl,
        "role": "member",
        "joinedAt": FieldValue.serverTimestamp(),
      });
      transaction.update(communityReference, {
        "memberCount": updatedMemberCount,
      });
      transaction.set(userCommunityReference, {
        "communityId": community.communityId,
        "name": community.name,
        "ownerId": community.ownerId,
        "memberCount": updatedMemberCount,
        "visibility": CommunityModel.publicVisibility,
        "joinedAt": FieldValue.serverTimestamp(),
      });

      return community.copyWith(memberCount: updatedMemberCount);
    });
  }
}
