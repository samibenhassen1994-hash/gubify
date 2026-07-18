import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> createPost({
    required String gubId,
    required String message,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("Utente non autenticato");
    }

    final userDoc = await _firestore.collection("users").doc(user.uid).get();

    final displayName = userDoc.data()?["displayName"] ?? "Utente";

    await _firestore.collection("gubs").doc(gubId).collection("posts").add({
      "authorId": user.uid,
      "authorName": displayName,
      "message": message.trim(),
      "likes": 0,
      "comments": 0,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }
}
