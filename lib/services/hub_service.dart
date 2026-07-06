import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HubService {
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

    batch.set(
      hubRef.collection("members").doc(user.uid),
      {
        "uid": user.uid,
        "displayName": user.displayName ?? "User",
        "photoUrl": user.photoURL,
        "role": "owner",
        "joinedAt": FieldValue.serverTimestamp(),
      },
    );

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

  Future<String> joinHub({
    required String inviteCode,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not authenticated.");
    }

    final query = await _firestore
        .collection("hubs")
        .where(
          "inviteCode",
          isEqualTo: inviteCode.trim().toUpperCase(),
        )
        .limit(1)
        .get();

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

    batch.set(
      memberRef,
      {
        "uid": user.uid,
        "displayName": user.displayName ?? "User",
        "photoUrl": user.photoURL,
        "role": "member",
        "joinedAt": FieldValue.serverTimestamp(),
      },
    );

    batch.update(
      _firestore.collection("hubs").doc(hubId),
      {
        "memberCount": FieldValue.increment(1),
      },
    );

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
}