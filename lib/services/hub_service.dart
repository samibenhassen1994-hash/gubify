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
      throw Exception("Utente non autenticato.");
    }

    final hubRef = _firestore.collection('hubs').doc();

    final random = Random();

    final prefix = name
        .trim()
        .substring(0, min(3, name.trim().length))
        .toUpperCase();

    final inviteCode = "$prefix-${1000 + random.nextInt(9000)}";

    await hubRef.set({
      'hubId': hubRef.id,
      'name': name.trim(),
      'ownerId': user.uid,
      'inviteCode': inviteCode,
      'memberCount': 1,
      'modules': modules,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await hubRef.collection('members').doc(user.uid).set({
      'uid': user.uid,
      'displayName': user.displayName ?? "Utente",
      'photoUrl': user.photoURL,
      'role': 'owner',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    return hubRef.id;
  }

  Future<String> joinHub({
    required String inviteCode,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("Utente non autenticato");
    }

    final query = await _firestore
        .collection("hubs")
        .where("inviteCode", isEqualTo: inviteCode.trim().toUpperCase())
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception("Codice Hub non valido.");
    }

    final hubDoc = query.docs.first;
    final hubId = hubDoc.id;

    final memberRef = _firestore
        .collection("hubs")
        .doc(hubId)
        .collection("members")
        .doc(user.uid);

    final alreadyMember = await memberRef.get();

    if (!alreadyMember.exists) {
      await memberRef.set({
        "uid": user.uid,
        "displayName": user.displayName ?? "Utente",
        "photoUrl": user.photoURL,
        "role": "member",
        "joinedAt": FieldValue.serverTimestamp(),
      });

      await _firestore.collection("hubs").doc(hubId).update({
        "memberCount": FieldValue.increment(1),
      });
    }

    return hubId;
  }
}