import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/community_model.dart';

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
    _deletionMembersSubcollection,
  ];

  CollectionReference<Map<String, dynamic>> get _communities =>
      _firestore.collection("communities");

  Future<CommunityModel?> createCommunity({
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

    final ownerMemberReference = communityReference
        .collection("members")
        .doc(ownerId);
    final userCommunityReference = _firestore
        .collection("users")
        .doc(ownerId)
        .collection("communities")
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

      transaction.set(communityReference, communityData);
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

      for (final subcollection in _knownCommunitySubcollections) {
        if (subcollection == _deletionMembersSubcollection) continue;
        await _deleteCollectionInBatches(
          communityReference.collection(subcollection),
        );
      }

      await _deleteUserMembershipCopies(
        communityId: normalizedCommunityId,
        communityReference: communityReference,
      );
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
      transaction.delete(communityReference);
    });
  }

  Stream<List<CommunityModel>> publicCommunitiesStream() {
    return _communities
        .where("visibility", isEqualTo: CommunityModel.publicVisibility)
        .snapshots()
        .map((snapshot) {
          final communities = snapshot.docs
              .where(
                (document) => document.data()["deletionStatus"] != "deleting",
              )
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
            controller.add(_immediateCommunityMemberships(copies, userId));
            if (copies.isEmpty) return;

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
                  .catchError((Object _) {
                    // Secondary enrichment must not replace already visible data.
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

  List<CommunityMembershipModel> _immediateCommunityMemberships(
    Map<String, Map<String, dynamic>> copies,
    String userId,
  ) {
    final memberships = [
      for (final entry in copies.entries)
        _communityMembershipFromCopy(
          communityId: entry.key,
          data: entry.value,
          userId: userId,
        ),
    ];
    _sortCommunityMemberships(memberships);
    return memberships;
  }

  Future<
    ({List<CommunityMembershipModel> items, Map<String, String> roleBackfills})
  >
  _enrichCommunityMemberships(
    Map<String, Map<String, dynamic>> copies,
    String userId,
  ) async {
    final ids = copies.keys.toList(growable: false);
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

    final memberEntries = await Future.wait(
      documents.map((document) async {
        final community = CommunityModel.fromFirestore(document);
        final userCopy = copies[community.communityId]!;
        if (community.ownerId == userId ||
            _nonEmptyString(userCopy["role"]) != null) {
          return MapEntry(community.communityId, const <String, dynamic>{});
        }
        final member = await document.reference
            .collection("members")
            .doc(userId)
            .get();
        return MapEntry(
          community.communityId,
          member.data() ?? const <String, dynamic>{},
        );
      }),
    );
    final membersById = Map.fromEntries(memberEntries);
    final roleBackfills = <String, String>{};
    final memberships = <CommunityMembershipModel>[];

    for (final document in documents) {
      final community = CommunityModel.fromFirestore(document);
      final userCopy = copies[community.communityId]!;
      final member = membersById[community.communityId]!;
      final role = community.ownerId == userId
          ? "owner"
          : _nonEmptyString(userCopy["role"]) ??
                _nonEmptyString(member["role"]) ??
                "member";
      final joinedAt =
          _timestampValue(userCopy["joinedAt"]) ??
          _timestampValue(member["joinedAt"]) ??
          (community.ownerId == userId ? community.createdAt : null);
      memberships.add(
        CommunityMembershipModel(
          community: community,
          role: role,
          joinedAt: joinedAt,
        ),
      );
      if (_nonEmptyString(userCopy["role"]) == null) {
        final authoritativeRole = community.ownerId == userId
            ? "owner"
            : _nonEmptyString(member["role"]);
        if (authoritativeRole != null) {
          roleBackfills[community.communityId] = authoritativeRole;
        }
      }
    }
    _sortCommunityMemberships(memberships);
    return (items: memberships, roleBackfills: roleBackfills);
  }

  CommunityMembershipModel _communityMembershipFromCopy({
    required String communityId,
    required Map<String, dynamic> data,
    required String userId,
  }) {
    final ownerId = _nonEmptyString(data["ownerId"]) ?? "";
    final community = CommunityModel(
      communityId: communityId,
      name: _nonEmptyString(data["name"]) ?? "",
      ownerId: ownerId,
      memberCount: data["memberCount"] is num
          ? (data["memberCount"] as num).toInt()
          : 0,
      visibility:
          _nonEmptyString(data["visibility"]) ??
          CommunityModel.publicVisibility,
      createdAt: _timestampValue(data["createdAt"]),
      type: CommunityModel.normalizeType(_nonEmptyString(data["type"])),
      language: CommunityModel.normalizeLanguage(
        _nonEmptyString(data["language"]),
      ),
      description: _nonEmptyString(data["description"]) ?? "",
    );
    return CommunityMembershipModel(
      community: community,
      role:
          _nonEmptyString(data["role"]) ??
          (ownerId == userId ? "owner" : "member"),
      joinedAt: _timestampValue(data["joinedAt"]),
    );
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
        "role": "member",
        "joinedAt": FieldValue.serverTimestamp(),
      });

      return community.copyWith(memberCount: updatedMemberCount);
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

class CommunityDeletionException implements Exception {
  final String message;

  const CommunityDeletionException(this.message);

  @override
  String toString() => message;
}
