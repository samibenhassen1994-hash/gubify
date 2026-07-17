import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/member_option.dart';
import '../config/app_limits.dart';
import '../repositories/user_repository.dart';

class GubService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> createHub({
    required String name,
    required Map<String, bool> modules,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not authenticated.");
    }

    final ownedHubs = await _firestore
        .collection("hubs")
        .where("ownerId", isEqualTo: user.uid)
        .count()
        .get();

    if ((ownedHubs.count ?? 0) >= AppLimits.freeMaxHubs) {
      throw Exception(
        "You have reached the maximum number of Hubs (${AppLimits.freeMaxHubs}).",
      );
    }

    final userData = await UserRepository.instance.getUser(user.uid);

    final displayName = userData?["displayName"] ?? "User";

    final hubRef = _firestore.collection("hubs").doc();

    final random = Random();

    final prefix = name
        .trim()
        .substring(0, min(3, name.trim().length))
        .toUpperCase();

    final inviteCode = "$prefix-${1000 + random.nextInt(9000)}";

    final batch = _firestore.batch();

    batch.set(hubRef, {
      "hubId": hubRef.id,
      "name": name.trim(),
      "ownerId": user.uid,
      "inviteCode": inviteCode,
      "memberCount": 1,
      "modules": modules,
      "createdAt": FieldValue.serverTimestamp(),
    });

    batch.set(hubRef.collection("members").doc(user.uid), {
      "uid": user.uid,
      "displayName": displayName,
      "photoUrl": user.photoURL,
      "role": "owner",
      "joinedAt": FieldValue.serverTimestamp(),
    });

    batch.set(
      _firestore
          .collection("users")
          .doc(user.uid)
          .collection("hubs")
          .doc(hubRef.id),
      {
        "hubId": hubRef.id,
        "name": name.trim(),
        "inviteCode": inviteCode,
        "memberCount": 1,
        "ownerId": user.uid,
        "modules": modules,
        "joinedAt": FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();

    return hubRef.id;
}

  Future<String> joinHub({required String inviteCode}) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not authenticated.");
    }

    final userData = await UserRepository.instance.getUser(user.uid);

    final displayName = userData?["displayName"] ?? "User";

    QuerySnapshot<Map<String, dynamic>> query;

    try {
      query = await _firestore
          .collection("hubs")
          .where("inviteCode", isEqualTo: inviteCode.trim().toUpperCase())
          .limit(1)
          .get();
    } on FirebaseException catch (e) {
      switch (e.code) {
        case "unavailable":
          throw Exception(
            "No internet connection. Please check your connection and try again.",
          );

        case "permission-denied":
          throw Exception("You don't have permission to access Hubfy.");

        case "deadline-exceeded":
          throw Exception("The connection timed out. Please try again.");

        default:
          throw Exception(e.message ?? "Unexpected connection error.");
      }
    }

    if (query.docs.isEmpty) {
      throw Exception("Invalid Hub code.");
    }

    final hubDoc = query.docs.first;
    final hubId = hubDoc.id;

    final memberRef = _firestore
        .collection("hubs")
        .doc(hubId)
        .collection("members")
        .doc(user.uid);

    if ((await memberRef.get()).exists) {
      return hubId;
    }

    final batch = _firestore.batch();

    batch.set(memberRef, {
      "uid": user.uid,
      "displayName": displayName,
      "photoUrl": user.photoURL,
      "role": "member",
      "joinedAt": FieldValue.serverTimestamp(),
    });

    batch.update(_firestore.collection("hubs").doc(hubId), {
      "memberCount": FieldValue.increment(1),
    });

    batch.set(
      _firestore
          .collection("users")
          .doc(user.uid)
          .collection("hubs")
          .doc(hubId),
      {
        "hubId": hubId,
        "name": hubDoc["name"],
        "inviteCode": hubDoc["inviteCode"],
        "memberCount": (hubDoc["memberCount"] ?? 1) + 1,
        "ownerId": hubDoc["ownerId"],
        "modules": hubDoc["modules"],
        "joinedAt": FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();

    return hubId;
  }

  /// Deletes a Hub.
  ///
  /// Current implementation:
  /// - deletes the Hub document
  /// - removes the owner's Hub reference
  ///
  /// Future versions will also delete:
  /// - members
  /// - goals
  /// - board
  /// - tasks
  /// - shopping
  /// - expenses
  Future<void> deleteHub({required String hubId}) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not authenticated.");
    }

    final hubDoc = await _firestore.collection("hubs").doc(hubId).get();

    if (!hubDoc.exists) {
      throw Exception("Hub not found.");
    }

    final data = hubDoc.data()!;

    if (data["ownerId"] != user.uid) {
      throw Exception("Only the owner can delete this Hub.");
    }

    final batch = _firestore.batch();

    batch.delete(_firestore.collection("hubs").doc(hubId));

    batch.delete(
      _firestore
          .collection("users")
          .doc(user.uid)
          .collection("hubs")
          .doc(hubId),
    );

    await batch.commit();
  }
  Stream<List<MemberOption>> membersStream(String hubId) {
    return _firestore
        .collection("hubs")
        .doc(hubId)
        .collection("members")
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();

            return MemberOption(
              userId: data["uid"] ?? "",
              userName: data["displayName"] ?? "User",
            );
          }).toList(),
        );
  }

  Future<List<MemberOption>> getMembers(String hubId) async {
    final snapshot = await _firestore
        .collection("hubs")
        .doc(hubId)
        .collection("members")
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      return MemberOption(
        userId: data["uid"] ?? "",
        userName: data["displayName"] ?? "User",
      );
    }).toList();
  }
}

