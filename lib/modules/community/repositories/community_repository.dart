import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/community_access_request_model.dart';
import '../models/community_model.dart';
import '../utils/community_slug.dart';

class CommunityRepository {
  CommunityRepository._();

  static final CommunityRepository instance = CommunityRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Set<String> _roleBackfillAttempts = {};

  static const int _batchSize = 400;
  static const int _membershipCleanupPageSize = 200;
  static const String _deletionMembersSubcollection = "deletionMembers";

  // Community deletion is client-side for Firebase Spark compatibility.
  // Every future Community subcollection must be added to this cleanup list.
  static const List<String> _knownCommunitySubcollections = [
    "messages",
    "members",
    "joinRequests",
    "membershipMutations",
    _deletionMembersSubcollection,
  ];

  CollectionReference<Map<String, dynamic>> get _communities =>
      _firestore.collection("communities");

  CollectionReference<Map<String, dynamic>> get _communitySlugs =>
      _firestore.collection('communitySlugs');

  CollectionReference<Map<String, dynamic>> get _communityPublic =>
      _firestore.collection('communityPublic');

  Future<CommunityModel?> createCommunity({
    required String name,
    required String ownerId,
    required String displayName,
    required String? photoUrl,
    required String type,
    required String language,
    required String description,
    required String accessMode,
  }) async {
    final ownershipReference = _firestore
        .collection("communityOwnership")
        .doc(ownerId);
    final legacyOwnedSnapshot = await _communities
        .where("ownerId", isEqualTo: ownerId)
        .limit(1)
        .get();
    final legacyOwnedCommunity = legacyOwnedSnapshot.docs.isEmpty
        ? null
        : legacyOwnedSnapshot.docs.first;
    final baseSlug = CommunitySlug.fromName(name);

    for (var sequence = 1; sequence <= 100; sequence++) {
      final slug = CommunitySlug.withSuffix(baseSlug, sequence);
      try {
        return await _createCommunityWithSlug(
          name: name,
          ownerId: ownerId,
          displayName: displayName,
          photoUrl: photoUrl,
          type: type,
          language: language,
          description: description,
          accessMode: accessMode,
          slug: slug,
          ownershipReference: ownershipReference,
          legacyOwnedCommunity: legacyOwnedCommunity,
        );
      } on _CommunitySlugCollision {
        continue;
      }
    }
    throw StateError('Unable to reserve a unique Community URL.');
  }

  Future<CommunityModel?> _createCommunityWithSlug({
    required String name,
    required String ownerId,
    required String displayName,
    required String? photoUrl,
    required String type,
    required String language,
    required String description,
    required String accessMode,
    required String slug,
    required DocumentReference<Map<String, dynamic>> ownershipReference,
    required QueryDocumentSnapshot<Map<String, dynamic>>? legacyOwnedCommunity,
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
      accessMode: accessMode,
      slug: slug,
      slugAssignedAt: localCreatedAt,
    );
    final communityData = community.toFirestore()
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['slugAssignedAt'] = FieldValue.serverTimestamp();
    final slugReference = _communitySlugs.doc(slug);
    final publicReference = _communityPublic.doc(slug);
    final ownerMemberReference = communityReference
        .collection('members')
        .doc(ownerId);
    final userCommunityReference = _firestore
        .collection('users')
        .doc(ownerId)
        .collection('communities')
        .doc(communityId);

    return _firestore.runTransaction<CommunityModel?>((transaction) async {
      final ownershipSnapshot = await transaction.get(ownershipReference);
      if (ownershipSnapshot.exists) return null;

      if (legacyOwnedCommunity != null) {
        transaction.set(ownershipReference, {
          "ownerId": ownerId,
          "communityId": legacyOwnedCommunity.id,
          "createdAt": FieldValue.serverTimestamp(),
        });
        return null;
      }

      final slugSnapshot = await transaction.get(slugReference);
      if (slugSnapshot.exists) throw const _CommunitySlugCollision();

      transaction.set(communityReference, communityData);
      transaction.set(slugReference, {
        'slug': slug,
        'communityId': communityId,
        'ownerId': ownerId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(publicReference, {
        'communityId': communityId,
        'slug': slug,
        'name': name,
        'description': description,
        'language': language,
        'accessMode': accessMode,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(ownerMemberReference, {
        "uid": ownerId,
        "displayName": displayName,
        "photoUrl": photoUrl,
        "role": "owner",
        "joinedAt": FieldValue.serverTimestamp(),
      });
      transaction.set(userCommunityReference, {
        "communityId": communityId,
        "name": name,
        "ownerId": ownerId,
        "memberCount": 1,
        "visibility": CommunityModel.publicVisibility,
        "role": "owner",
        "joinedAt": FieldValue.serverTimestamp(),
      });
      transaction.set(ownershipReference, {
        "ownerId": ownerId,
        "communityId": communityId,
        "createdAt": FieldValue.serverTimestamp(),
      });

      return community;
    });
  }

  Future<CommunityModel?> getCommunity(String communityId) async {
    final document = await _communities.doc(communityId).get();
    if (!document.exists) return null;

    return CommunityModel.fromFirestore(document);
  }

  Stream<CommunityModel?> communityForMemberStream({
    required String communityId,
    required String userId,
  }) {
    final communityReference = _communities.doc(communityId);
    final memberReference = communityReference
        .collection("members")
        .doc(userId);
    return _combineCommunityAccessDocuments(
      communityReference: communityReference,
      memberReference: memberReference,
      requireMembership: true,
    ).map((state) => state?.community);
  }

  Stream<CommunityPublicAccessState?> publicAccessStateStream({
    required String communityId,
    required String userId,
  }) {
    final communityReference = _communities.doc(communityId);
    return _combineCommunityAccessDocuments(
      communityReference: communityReference,
      memberReference: communityReference.collection("members").doc(userId),
      requestReference: communityReference
          .collection("joinRequests")
          .doc(userId),
      requireMembership: false,
    );
  }

  Stream<CommunityPublicAccessState?> _combineCommunityAccessDocuments({
    required DocumentReference<Map<String, dynamic>> communityReference,
    required DocumentReference<Map<String, dynamic>> memberReference,
    DocumentReference<Map<String, dynamic>>? requestReference,
    required bool requireMembership,
  }) {
    late final StreamController<CommunityPublicAccessState?> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? communitySub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? memberSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? requestSub;
    DocumentSnapshot<Map<String, dynamic>>? communitySnapshot;
    DocumentSnapshot<Map<String, dynamic>>? memberSnapshot;
    DocumentSnapshot<Map<String, dynamic>>? requestSnapshot;
    var communityLoaded = false;
    var memberLoaded = false;
    var requestLoaded = requestReference == null;

    void emit() {
      if (!communityLoaded ||
          !memberLoaded ||
          !requestLoaded ||
          controller.isClosed) {
        return;
      }
      final communityDocument = communitySnapshot;
      final memberDocument = memberSnapshot;
      if (communityDocument == null || !communityDocument.exists) {
        controller.add(null);
        return;
      }
      final community = CommunityModel.fromFirestore(communityDocument);
      final isMember =
          memberDocument?.exists == true &&
          memberDocument?.data()?["uid"] == memberReference.id;
      if (requireMembership && !isMember) {
        controller.add(null);
        return;
      }
      controller.add(
        CommunityPublicAccessState(
          community: community,
          isMember: isMember,
          isOwner: community.ownerId == memberReference.id,
          request: requestSnapshot?.exists == true
              ? CommunityAccessRequestModel.fromFirestore(requestSnapshot!)
              : null,
        ),
      );
    }

    void addError(Object error, StackTrace stackTrace) {
      if (!controller.isClosed) controller.addError(error, stackTrace);
    }

    controller = StreamController<CommunityPublicAccessState?>(
      onListen: () {
        communitySub = communityReference.snapshots().listen((snapshot) {
          communitySnapshot = snapshot;
          communityLoaded = true;
          emit();
        }, onError: addError);
        memberSub = memberReference.snapshots().listen((snapshot) {
          memberSnapshot = snapshot;
          memberLoaded = true;
          emit();
        }, onError: addError);
        if (requestReference != null) {
          requestSub = requestReference.snapshots().listen((snapshot) {
            requestSnapshot = snapshot;
            requestLoaded = true;
            emit();
          }, onError: addError);
        }
      },
      onCancel: () async {
        await Future.wait([
          if (communitySub != null) communitySub!.cancel(),
          if (memberSub != null) memberSub!.cancel(),
          if (requestSub != null) requestSub!.cancel(),
        ]);
      },
    );
    return controller.stream;
  }

  Future<CommunityModel?> getCommunityForMember({
    required String communityId,
    required String userId,
  }) async {
    final member = await _communities
        .doc(communityId)
        .collection("members")
        .doc(userId)
        .get();
    if (!member.exists || member.data()?["uid"] != userId) return null;

    return getCommunity(communityId);
  }

  Future<bool> ownsCommunity(String userId) async {
    final ownershipReference = _firestore
        .collection("communityOwnership")
        .doc(userId);
    final ownership = await ownershipReference.get();
    if (ownership.exists) return true;

    final legacyOwnedSnapshot = await _communities
        .where("ownerId", isEqualTo: userId)
        .limit(1)
        .get();
    if (legacyOwnedSnapshot.docs.isEmpty) return false;

    final legacyCommunityId = legacyOwnedSnapshot.docs.first.id;
    await _firestore.runTransaction((transaction) async {
      final currentOwnership = await transaction.get(ownershipReference);
      if (currentOwnership.exists) return;
      transaction.set(ownershipReference, {
        "ownerId": userId,
        "communityId": legacyCommunityId,
        "createdAt": FieldValue.serverTimestamp(),
      });
    });
    return true;
  }

  Future<String> getMemberRole({
    required String communityId,
    required String userId,
  }) async {
    final member = await _communities
        .doc(communityId)
        .collection("members")
        .doc(userId)
        .get();
    final role = member.data()?["role"];
    return role is String && role.trim().isNotEmpty ? role.trim() : "member";
  }

  Stream<List<CommunityMemberModel>> communityMembersStream(
    String communityId,
  ) {
    return _communities.doc(communityId).collection('members').snapshots().map((
      snapshot,
    ) {
      final members = snapshot.docs.map((document) {
        final data = document.data();
        final displayName = data['displayName'];
        final photoUrl = data['photoUrl'];
        final role = data['role'];
        return CommunityMemberModel(
          userId: document.id,
          displayName: displayName is String && displayName.trim().isNotEmpty
              ? displayName.trim()
              : 'User',
          photoUrl: photoUrl is String && photoUrl.trim().isNotEmpty
              ? photoUrl.trim()
              : null,
          role: role is String && role.trim().isNotEmpty
              ? role.trim()
              : 'member',
          joinedAt: _timestampValue(data['joinedAt']),
        );
      }).toList();
      members.sort((first, second) {
        final roleComparison = (first.role == 'owner' ? 0 : 1).compareTo(
          second.role == 'owner' ? 0 : 1,
        );
        if (roleComparison != 0) return roleComparison;
        final joinedComparison = (first.joinedAt?.millisecondsSinceEpoch ?? 0)
            .compareTo(second.joinedAt?.millisecondsSinceEpoch ?? 0);
        if (joinedComparison != 0) return joinedComparison;
        return first.displayName.toLowerCase().compareTo(
          second.displayName.toLowerCase(),
        );
      });
      return members;
    });
  }

  Stream<List<Map<String, dynamic>>> bannedUsersStream(String communityId) =>
      _communities
          .doc(communityId)
          .collection('bans')
          .snapshots()
          .asyncMap(
            (snapshot) => Future.wait(
              snapshot.docs.map((document) async {
                final data = <String, dynamic>{
                  ...document.data(),
                  'uid': document.id,
                };
                final name = data['displayName'];
                if (name is String && name.trim().isNotEmpty) return data;
                final profile = await _firestore
                    .collection('users')
                    .doc(document.id)
                    .get();
                final profileName = profile.data()?['displayName'];
                if (profileName is String && profileName.trim().isNotEmpty) {
                  data['displayName'] = profileName.trim();
                }
                return data;
              }),
            ),
          );

  Future<CommunityMemberModel?> getCommunityMember({
    required String communityId,
    required String userId,
  }) async {
    final member = await _communities
        .doc(communityId)
        .collection('members')
        .doc(userId)
        .get();
    if (!member.exists) return null;
    final data = member.data()!;
    final displayName = data['displayName'];
    final photoUrl = data['photoUrl'];
    final role = data['role'];
    return CommunityMemberModel(
      userId: member.id,
      displayName: displayName is String && displayName.trim().isNotEmpty
          ? displayName.trim()
          : 'User',
      photoUrl: photoUrl is String && photoUrl.trim().isNotEmpty
          ? photoUrl.trim()
          : null,
      role: role is String && role.trim().isNotEmpty ? role.trim() : 'member',
      joinedAt: _timestampValue(data['joinedAt']),
    );
  }

  Future<void> leaveCommunity({
    required String communityId,
    required String userId,
  }) async {
    return removeCommunityMember(
      communityId: communityId,
      userId: userId,
      actorId: userId,
    );
  }

  Future<void> removeCommunityMember({
    required String communityId,
    required String userId,
    required String actorId,
  }) async {
    final communityReference = _communities.doc(communityId);
    final memberReference = communityReference
        .collection('members')
        .doc(userId);
    final userCommunityReference = _firestore
        .collection('users')
        .doc(userId)
        .collection('communities')
        .doc(communityId);
    await _firestore.runTransaction((transaction) async {
      final community = await transaction.get(communityReference);
      final member = await transaction.get(memberReference);
      if (!community.exists ||
          community.data()?['deletionStatus'] == 'deleting') {
        throw StateError('This Community is no longer available.');
      }
      if (!member.exists || member.data()?['uid'] != userId) {
        throw StateError('You are no longer a member of this Community.');
      }
      final ownerId = community.data()?['ownerId'] as String?;
      if (ownerId == userId) {
        throw StateError(
          'The Community owner cannot leave their own Community.',
        );
      }
      if (actorId != userId && actorId != ownerId) {
        throw StateError('Only the Community owner can remove members.');
      }
      final memberCount =
          (community.data()?['memberCount'] as num?)?.toInt() ?? 1;
      transaction.delete(memberReference);
      transaction.delete(userCommunityReference);
      transaction.update(communityReference, {
        'memberCount': (memberCount - 1).clamp(1, memberCount),
      });
    });
  }

  Future<void> banCommunityMember({
    required String communityId,
    required String userId,
    required String ownerId,
  }) async {
    final communityReference = _communities.doc(communityId);
    final memberReference = communityReference
        .collection('members')
        .doc(userId);
    final copyReference = _firestore
        .collection('users')
        .doc(userId)
        .collection('communities')
        .doc(communityId);
    final banReference = communityReference.collection('bans').doc(userId);
    await _firestore.runTransaction((transaction) async {
      final community = await transaction.get(communityReference);
      final member = await transaction.get(memberReference);
      if (!community.exists ||
          community.data()?['ownerId'] != ownerId ||
          !member.exists ||
          userId == ownerId) {
        throw StateError('This member cannot be banned.');
      }
      final count = (community.data()?['memberCount'] as num?)?.toInt() ?? 1;
      transaction.set(banReference, {
        'userId': userId,
        'displayName': member.data()?['displayName'] ?? 'User',
        'photoUrl': member.data()?['photoUrl'],
        'bannedBy': ownerId,
        'bannedAt': FieldValue.serverTimestamp(),
      });
      transaction.delete(memberReference);
      transaction.delete(copyReference);
      transaction.update(communityReference, {
        'memberCount': (count - 1).clamp(1, count),
      });
    });
  }

  Future<void> unbanMember({
    required String communityId,
    required String uid,
  }) => _communities.doc(communityId).collection('bans').doc(uid).delete();

  Future<bool> isUserBanned({
    required String communityId,
    required String userId,
  }) async =>
      (await _communities.doc(communityId).collection('bans').doc(userId).get())
          .exists;

  Future<void> deleteCommunityClientSide({
    required String communityId,
    required String? confirmationName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const CommunityDeletionException("Please sign in again.");
    }

    final normalizedCommunityId = communityId.trim();
    if (normalizedCommunityId.isEmpty) {
      throw const CommunityDeletionException(
        "The deletion was not completed. Keep the app open and try again.",
      );
    }

    final communityReference = _communities.doc(normalizedCommunityId);
    try {
      final ownerId = await _markCommunityForDeletion(
        communityReference: communityReference,
        confirmationName: confirmationName,
        currentUserId: user.uid,
      );

      await _captureDeletionMembers(
        communityReference: communityReference,
        ownerId: ownerId,
      );

      await _deleteUserMembershipCopies(
        communityId: normalizedCommunityId,
        communityReference: communityReference,
      );

      for (final subcollection in _knownCommunitySubcollections) {
        if (subcollection == _deletionMembersSubcollection) continue;
        await _deleteCollectionInBatches(
          communityReference.collection(subcollection),
        );
      }

      await _deleteOwnershipAndCommunity(
        ownerId: ownerId,
        communityId: normalizedCommunityId,
        communityReference: communityReference,
        currentUserId: user.uid,
      );
    } on CommunityDeletionException {
      rethrow;
    } on FirebaseException {
      throw const CommunityDeletionException(
        "The deletion was not completed. Keep the app open and try again.",
      );
    } catch (_) {
      throw const CommunityDeletionException(
        "The deletion was not completed. Keep the app open and try again.",
      );
    }
  }

  Future<String> _markCommunityForDeletion({
    required DocumentReference<Map<String, dynamic>> communityReference,
    required String? confirmationName,
    required String currentUserId,
  }) {
    return _firestore.runTransaction<String>((transaction) async {
      final snapshot = await transaction.get(communityReference);
      if (!snapshot.exists) {
        throw const CommunityDeletionException(
          "This Community no longer exists.",
        );
      }

      final data = snapshot.data()!;
      final ownerId = data["ownerId"];
      if (ownerId != currentUserId) {
        throw const CommunityDeletionException(
          "Only the Community owner can delete it.",
        );
      }
      final deleting = data['deletionStatus'] == 'deleting';
      if (!deleting && data["name"] != confirmationName) {
        throw const CommunityDeletionException(
          "The Community name does not match.",
        );
      }

      if (!deleting) {
        transaction.update(communityReference, {
          "deletionStatus": "deleting",
          "deletionStartedAt": FieldValue.serverTimestamp(),
          "deletionStartedBy": currentUserId,
          "deletionRequestedBy": currentUserId,
        });
      } else if (data['deletionRequestedBy'] != null &&
          data['deletionRequestedBy'] != currentUserId) {
        throw const CommunityDeletionException(
          'Only the owner who started this deletion can resume it.',
        );
      }
      return currentUserId;
    });
  }

  Future<void> _captureDeletionMembers({
    required DocumentReference<Map<String, dynamic>> communityReference,
    required String ownerId,
  }) async {
    final currentSnapshot = await communityReference.get();
    if (!currentSnapshot.exists) {
      throw const CommunityDeletionException(
        "This Community no longer exists.",
      );
    }
    if (currentSnapshot.data()?["deletionMembersCapturedAt"] is Timestamp) {
      return;
    }

    final members = communityReference.collection("members");
    final deletionMembers = communityReference.collection(
      _deletionMembersSubcollection,
    );
    await deletionMembers.doc(ownerId).set({"uid": ownerId});

    QueryDocumentSnapshot<Map<String, dynamic>>? lastDocument;
    while (true) {
      Query<Map<String, dynamic>> query = members
          .orderBy(FieldPath.documentId)
          .limit(_batchSize);
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      final page = await query.get();
      if (page.docs.isEmpty) break;

      final batch = _firestore.batch();
      for (final member in page.docs) {
        batch.set(deletionMembers.doc(member.id), {"uid": member.id});
      }
      await batch.commit();
      lastDocument = page.docs.last;
      if (page.docs.length < _batchSize) break;
    }

    await communityReference.update({
      "deletionMembersCapturedAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteCollectionInBatches(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final page = await collection.limit(_batchSize).get();
      if (page.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final document in page.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _deleteUserMembershipCopies({
    required String communityId,
    required DocumentReference<Map<String, dynamic>> communityReference,
  }) async {
    final deletionMembers = communityReference.collection(
      _deletionMembersSubcollection,
    );

    while (true) {
      final page = await deletionMembers
          .limit(_membershipCleanupPageSize)
          .get();
      if (page.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final marker in page.docs) {
        batch.delete(
          _firestore
              .collection("users")
              .doc(marker.id)
              .collection("communities")
              .doc(communityId),
        );
        batch.delete(marker.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _deleteOwnershipAndCommunity({
    required String ownerId,
    required String communityId,
    required DocumentReference<Map<String, dynamic>> communityReference,
    required String currentUserId,
  }) {
    final ownershipReference = _firestore
        .collection("communityOwnership")
        .doc(ownerId);
    return _firestore.runTransaction((transaction) async {
      final communitySnapshot = await transaction.get(communityReference);
      final ownershipSnapshot = await transaction.get(ownershipReference);
      final slug = _nonEmptyString(communitySnapshot.data()?['slug']);
      final slugReference = slug == null ? null : _communitySlugs.doc(slug);
      final publicReference = slug == null ? null : _communityPublic.doc(slug);
      if (slugReference != null) await transaction.get(slugReference);
      if (publicReference != null) await transaction.get(publicReference);
      if (!communitySnapshot.exists) {
        throw const CommunityDeletionException(
          "This Community no longer exists.",
        );
      }
      final data = communitySnapshot.data()!;
      if (data["ownerId"] != currentUserId) {
        throw const CommunityDeletionException(
          "Only the Community owner can delete it.",
        );
      }
      if (data["deletionStatus"] != "deleting") {
        throw const CommunityDeletionException(
          "The deletion was not completed. Keep the app open and try again.",
        );
      }
      if (ownershipSnapshot.data()?["communityId"] == communityId) {
        transaction.delete(ownershipReference);
      }
      if (slugReference != null) transaction.delete(slugReference);
      if (publicReference != null) transaction.delete(publicReference);
      transaction.delete(communityReference);
    });
  }

  Future<CommunityExplorerPage> loadPublicCommunitiesPage({
    CommunityExplorerCursor? after,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> query = _communities
        .where("visibility", isEqualTo: CommunityModel.publicVisibility)
        .where(
          "accessMode",
          whereIn: const [
            CommunityModel.openAccessMode,
            CommunityModel.approvalAccessMode,
          ],
        )
        .orderBy("createdAt", descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(limit);
    if (after != null) query = query.startAfterDocument(after._document);

    final snapshot = await query.get();
    final communities = snapshot.docs
        .where((document) => document.data()["deletionStatus"] != "deleting")
        .map(CommunityModel.fromFirestore)
        .where((community) => community.communityId.isNotEmpty)
        .toList(growable: false);
    return CommunityExplorerPage(
      communities: communities,
      nextCursor: snapshot.docs.isEmpty
          ? null
          : CommunityExplorerCursor._(snapshot.docs.last),
      hasMore: snapshot.docs.length == limit,
    );
  }

  Stream<Set<String>> userCommunityIdsStream(String userId) {
    return userCommunityMembershipsStream(userId).map(
      (memberships) => memberships
          .map((membership) => membership.community.communityId)
          .toSet(),
    );
  }

  Stream<List<CommunityModel>> userCommunitiesStream(String userId) {
    return userCommunityMembershipsStream(userId).map(
      (items) => items.map((item) => item.community).toList(growable: false),
    );
  }

  Stream<List<CommunityMembershipModel>> userCommunityMembershipsStream(
    String userId,
  ) {
    final userCommunities = _firestore
        .collection("users")
        .doc(userId)
        .collection("communities");
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subscription;
    late final StreamController<List<CommunityMembershipModel>> controller;
    var generation = 0;
    var cancelled = false;

    controller = StreamController<List<CommunityMembershipModel>>(
      onListen: () {
        subscription = userCommunities.snapshots().listen(
          (snapshot) {
            if (cancelled || controller.isClosed) return;
            final snapshotGeneration = ++generation;
            final copies = _userCommunityCopies(snapshot);
            if (copies.isEmpty) {
              controller.add(const []);
              return;
            }

            unawaited(
              _enrichCommunityMemberships(copies, userId)
                  .then((enrichment) {
                    if (cancelled ||
                        controller.isClosed ||
                        snapshotGeneration != generation) {
                      return;
                    }
                    controller.add(enrichment.items);
                    for (final entry in enrichment.roleBackfills.entries) {
                      unawaited(
                        _backfillUserCommunityRole(
                          userId: userId,
                          communityId: entry.key,
                          role: entry.value,
                        ),
                      );
                    }
                  })
                  .catchError((Object error, StackTrace stackTrace) {
                    if (!cancelled &&
                        !controller.isClosed &&
                        snapshotGeneration == generation) {
                      controller.addError(error, stackTrace);
                    }
                  }),
            );
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!cancelled && !controller.isClosed) {
              controller.addError(error, stackTrace);
            }
          },
          onDone: () {
            if (!controller.isClosed) {
              unawaited(controller.close());
            }
          },
        );
      },
      onCancel: () async {
        cancelled = true;
        generation++;
        await subscription?.cancel();
        if (!controller.isClosed) {
          unawaited(controller.close());
        }
      },
    );

    return controller.stream;
  }

  Map<String, Map<String, dynamic>> _userCommunityCopies(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final copies = <String, Map<String, dynamic>>{};
    for (final document in snapshot.docs) {
      final data = document.data();
      final communityId = _nonEmptyString(data["communityId"]) ?? document.id;
      if (communityId.isNotEmpty) copies[communityId] = data;
    }
    return copies;
  }

  Future<
    ({List<CommunityMembershipModel> items, Map<String, String> roleBackfills})
  >
  _enrichCommunityMemberships(
    Map<String, Map<String, dynamic>> copies,
    String userId,
  ) async {
    final memberEntries = await Future.wait(
      copies.keys.map((communityId) async {
        final member = await _communities
            .doc(communityId)
            .collection("members")
            .doc(userId)
            .get();
        return MapEntry(
          communityId,
          member.exists && member.data()?["uid"] == userId
              ? member.data()
              : null,
        );
      }),
    );
    final membersById = <String, Map<String, dynamic>>{
      for (final entry in memberEntries)
        if (entry.value != null) entry.key: entry.value!,
    };
    final ids = membersById.keys.toList(growable: false);
    if (ids.isEmpty) {
      return (
        items: const <CommunityMembershipModel>[],
        roleBackfills: const <String, String>{},
      );
    }

    final queryFutures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
    for (var start = 0; start < ids.length; start += 30) {
      final end = (start + 30).clamp(0, ids.length);
      queryFutures.add(
        _communities
            .where(FieldPath.documentId, whereIn: ids.sublist(start, end))
            .get(),
      );
    }
    final querySnapshots = await Future.wait(queryFutures);
    final documents = [for (final snapshot in querySnapshots) ...snapshot.docs];
    final roleBackfills = <String, String>{};
    final memberships = <CommunityMembershipModel>[];

    for (final document in documents) {
      final community = CommunityModel.fromFirestore(document);
      final userCopy = copies[community.communityId]!;
      final member = membersById[community.communityId]!;
      final role = community.ownerId == userId ? "owner" : "member";
      final joinedAt =
          _timestampValue(member["joinedAt"]) ??
          _timestampValue(userCopy["joinedAt"]) ??
          (community.ownerId == userId ? community.createdAt : null);
      memberships.add(
        CommunityMembershipModel(
          community: community,
          role: role,
          joinedAt: joinedAt,
        ),
      );
      if (_nonEmptyString(userCopy["role"]) != role) {
        roleBackfills[community.communityId] = role;
      }
    }
    _sortCommunityMemberships(memberships);
    return (items: memberships, roleBackfills: roleBackfills);
  }

  void _sortCommunityMemberships(List<CommunityMembershipModel> memberships) {
    memberships.sort((first, second) {
      final firstMillis =
          first.joinedAt?.millisecondsSinceEpoch ??
          first.community.createdAt?.millisecondsSinceEpoch ??
          0;
      final secondMillis =
          second.joinedAt?.millisecondsSinceEpoch ??
          second.community.createdAt?.millisecondsSinceEpoch ??
          0;
      return secondMillis.compareTo(firstMillis);
    });
  }

  Future<void> _backfillUserCommunityRole({
    required String userId,
    required String communityId,
    required String role,
  }) async {
    final attemptKey = "$userId/$communityId";
    if (!_roleBackfillAttempts.add(attemptKey)) return;
    try {
      await _firestore
          .collection("users")
          .doc(userId)
          .collection("communities")
          .doc(communityId)
          .set({"role": role}, SetOptions(merge: true));
    } catch (_) {
      // The authoritative membership remains the fallback if writes are denied.
    }
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
      if (communitySnapshot.data()?["deletionStatus"] == "deleting") {
        throw StateError("This Community is being deleted.");
      }

      final community = CommunityModel.fromFirestore(communitySnapshot);
      if (community.visibility != CommunityModel.publicVisibility) {
        throw StateError("This community is not public.");
      }
      if (community.accessMode != CommunityModel.openAccessMode) {
        throw StateError("This Community requires owner approval.");
      }
      final userCommunitySnapshot = await transaction.get(
        userCommunityReference,
      );
      final memberSnapshot = await transaction.get(memberReference);
      if (memberSnapshot.exists) {
        if (!userCommunitySnapshot.exists) {
          final memberData = memberSnapshot.data();
          final joinedAt = memberData?["joinedAt"];
          if (joinedAt is Timestamp) {
            transaction.set(userCommunityReference, {
              "communityId": community.communityId,
              "name": community.name,
              "ownerId": community.ownerId,
              "memberCount": community.memberCount,
              "visibility": community.visibility,
              "role": community.ownerId == userId ? "owner" : "member",
              "joinedAt": joinedAt,
            });
          }
        }
        return community;
      }

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
        "role": "member",
        "joinedAt": FieldValue.serverTimestamp(),
      });

      return community.copyWith(memberCount: updatedMemberCount);
    });
  }

  Future<CommunityPublicAccessState?> getPublicAccessState({
    required String communityId,
    required String userId,
  }) async {
    final communitySnapshot = await _communities.doc(communityId).get();
    if (!communitySnapshot.exists) return null;

    final community = CommunityModel.fromFirestore(communitySnapshot);
    final memberSnapshot = await _communities
        .doc(communityId)
        .collection("members")
        .doc(userId)
        .get();
    final requestSnapshot = await _communities
        .doc(communityId)
        .collection("joinRequests")
        .doc(userId)
        .get();
    return CommunityPublicAccessState(
      community: community,
      isMember:
          memberSnapshot.exists && memberSnapshot.data()?["uid"] == userId,
      isOwner: community.ownerId == userId,
      request: requestSnapshot.exists
          ? CommunityAccessRequestModel.fromFirestore(requestSnapshot)
          : null,
    );
  }

  Future<void> createJoinRequest({
    required String communityId,
    required String userId,
    required String displayName,
  }) {
    final communityReference = _communities.doc(communityId);
    final memberReference = communityReference
        .collection("members")
        .doc(userId);
    final requestReference = communityReference
        .collection("joinRequests")
        .doc(userId);
    return _firestore.runTransaction((transaction) async {
      final community = await transaction.get(communityReference);
      final member = await transaction.get(memberReference);
      final request = await transaction.get(requestReference);
      if (!community.exists) throw StateError("Community not found.");
      final model = CommunityModel.fromFirestore(community);
      if (model.deletionStatus == "deleting") {
        throw StateError("This Community is being deleted.");
      }
      if (model.accessMode != CommunityModel.approvalAccessMode) {
        throw StateError("This Community does not require approval.");
      }
      if (member.exists) throw StateError("You are already a member.");
      final existingRequestStatus = request.data()?['status'];
      final canResetExistingRequest =
          existingRequestStatus == CommunityAccessRequestModel.rejectedStatus ||
          existingRequestStatus == CommunityAccessRequestModel.approvedStatus;
      if (request.exists && !canResetExistingRequest) {
        throw StateError("A request for this Community already exists.");
      }
      if (request.exists) {
        transaction.update(requestReference, {
          "status": CommunityAccessRequestModel.pendingStatus,
          "resolvedAt": FieldValue.delete(),
          "resolvedBy": FieldValue.delete(),
        });
      } else {
        transaction.set(requestReference, {
          "userId": userId,
          "displayName": displayName,
          "status": CommunityAccessRequestModel.pendingStatus,
          "createdAt": FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> cancelJoinRequest({
    required String communityId,
    required String userId,
  }) {
    final requestReference = _communities
        .doc(communityId)
        .collection("joinRequests")
        .doc(userId);
    return _firestore.runTransaction((transaction) async {
      final request = await transaction.get(requestReference);
      if (!request.exists ||
          request.data()?["status"] !=
              CommunityAccessRequestModel.pendingStatus) {
        throw StateError("This request is no longer pending.");
      }
      transaction.delete(requestReference);
    });
  }

  Future<List<CommunityAccessRequestModel>> pendingJoinRequests({
    required String communityId,
    int limit = 50,
  }) async {
    final snapshot = await _communities
        .doc(communityId)
        .collection("joinRequests")
        .where("status", isEqualTo: CommunityAccessRequestModel.pendingStatus)
        .limit(limit)
        .get();
    final requests = snapshot.docs
        .map(CommunityAccessRequestModel.fromFirestore)
        .toList(growable: false);
    requests.sort((first, second) {
      final firstMillis = first.createdAt?.millisecondsSinceEpoch ?? 0;
      final secondMillis = second.createdAt?.millisecondsSinceEpoch ?? 0;
      return firstMillis.compareTo(secondMillis);
    });
    return requests;
  }

  Stream<int> pendingJoinRequestCountStream(String communityId) {
    return _communities
        .doc(communityId)
        .collection("joinRequests")
        .where("status", isEqualTo: CommunityAccessRequestModel.pendingStatus)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.where((document) {
            final data = document.data();
            return data["status"] ==
                    CommunityAccessRequestModel.pendingStatus &&
                data["userId"] == document.id &&
                data["displayName"] is String &&
                (data["displayName"] as String).trim().isNotEmpty;
          }).length,
        );
  }

  Future<void> approveJoinRequest({
    required String communityId,
    required String ownerId,
    required String userId,
  }) {
    final communityReference = _communities.doc(communityId);
    final requestReference = communityReference
        .collection("joinRequests")
        .doc(userId);
    final memberReference = communityReference
        .collection("members")
        .doc(userId);
    final userCommunityReference = _firestore
        .collection("users")
        .doc(userId)
        .collection("communities")
        .doc(communityId);
    final mutationReference = communityReference
        .collection("membershipMutations")
        .doc("current");
    return _firestore.runTransaction((transaction) async {
      final communitySnapshot = await transaction.get(communityReference);
      final requestSnapshot = await transaction.get(requestReference);
      final memberSnapshot = await transaction.get(memberReference);
      if (!communitySnapshot.exists) throw StateError("Community not found.");
      final community = CommunityModel.fromFirestore(communitySnapshot);
      if (community.ownerId != ownerId) {
        throw StateError("Only the Community owner can approve requests.");
      }
      if (community.deletionStatus == "deleting") {
        throw StateError("This Community is being deleted.");
      }
      if (!requestSnapshot.exists ||
          requestSnapshot.data()?["status"] !=
              CommunityAccessRequestModel.pendingStatus) {
        throw StateError("This request is no longer pending.");
      }
      if (memberSnapshot.exists) {
        throw StateError("This user is already a member.");
      }
      final requestData = requestSnapshot.data()!;
      final displayName = requestData["displayName"] as String? ?? "User";
      final updatedMemberCount = community.memberCount + 1;
      transaction.update(communityReference, {
        "memberCount": updatedMemberCount,
      });
      transaction.set(memberReference, {
        "uid": userId,
        "displayName": displayName,
        "photoUrl": null,
        "role": "member",
        "joinedAt": FieldValue.serverTimestamp(),
      });
      transaction.set(userCommunityReference, {
        "communityId": communityId,
        "name": community.name,
        "ownerId": community.ownerId,
        "memberCount": updatedMemberCount,
        "visibility": community.visibility,
        "role": "member",
        "joinedAt": FieldValue.serverTimestamp(),
      });
      transaction.update(requestReference, {
        "status": CommunityAccessRequestModel.approvedStatus,
        "resolvedAt": FieldValue.serverTimestamp(),
        "resolvedBy": ownerId,
      });
      transaction.set(mutationReference, {
        "action": "approve",
        "userId": userId,
        "ownerId": ownerId,
        "createdAt": FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> rejectJoinRequest({
    required String communityId,
    required String ownerId,
    required String userId,
  }) {
    final communityReference = _communities.doc(communityId);
    final requestReference = communityReference
        .collection("joinRequests")
        .doc(userId);
    return _firestore.runTransaction((transaction) async {
      final community = await transaction.get(communityReference);
      final request = await transaction.get(requestReference);
      if (!community.exists || community.data()?["ownerId"] != ownerId) {
        throw StateError("Only the Community owner can reject requests.");
      }
      if (!request.exists ||
          request.data()?["status"] !=
              CommunityAccessRequestModel.pendingStatus) {
        throw StateError("This request is no longer pending.");
      }
      transaction.update(requestReference, {
        "status": CommunityAccessRequestModel.rejectedStatus,
        "resolvedAt": FieldValue.serverTimestamp(),
        "resolvedBy": ownerId,
      });
    });
  }

  String? _nonEmptyString(Object? value) {
    if (value is! String) return null;
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  Timestamp? _timestampValue(Object? value) {
    return value is Timestamp ? value : null;
  }
}

class CommunityExplorerCursor {
  final QueryDocumentSnapshot<Map<String, dynamic>> _document;

  const CommunityExplorerCursor._(this._document);
}

class CommunityExplorerPage {
  final List<CommunityModel> communities;
  final CommunityExplorerCursor? nextCursor;
  final bool hasMore;

  const CommunityExplorerPage({
    required this.communities,
    required this.nextCursor,
    required this.hasMore,
  });
}

class CommunityDeletionException implements Exception {
  final String message;

  const CommunityDeletionException(this.message);

  @override
  String toString() => message;
}

class _CommunitySlugCollision implements Exception {
  const _CommunitySlugCollision();
}
