import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/board_post_model.dart';
import '../repositories/post_repository.dart';
import '../repositories/gub_repository.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> createPost({
    required String gubId,
    required String message,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("You must be signed in to create a Board post.");
    }
    await GubRepository.instance.ensureActive(gubId);

    final userDoc = await _firestore.collection("users").doc(user.uid).get();

    final displayName = userDoc.data()?["displayName"] ?? "User";

    await PostRepository.instance.createPost(
      gubId: gubId,
      authorId: user.uid,
      authorName: displayName,
      authorPhoto: user.photoURL,
      message: message.trim(),
    );

    return displayName;
  }

  Stream<List<BoardPostModel>> postsStream(String gubId) {
    return PostRepository.instance.postsStream(gubId);
  }
}
