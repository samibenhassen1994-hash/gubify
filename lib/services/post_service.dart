import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/board_post_model.dart';
import '../models/board_comment_model.dart';
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

  Stream<Map<String, dynamic>?> boardStateStream(String gubId) =>
      PostRepository.instance.gubBoardStateStream(gubId);

  Future<void> setPinnedPost({required String gubId, String? postId}) async {
    await GubRepository.instance.ensureActive(gubId);
    await PostRepository.instance.setPinnedPost(gubId: gubId, postId: postId);
  }

  Future<Timestamp> _membershipBoundary(String gubId, String userId) async {
    final membership = await _firestore
        .collection('gubs')
        .doc(gubId)
        .collection('members')
        .doc(userId)
        .get(const GetOptions(source: Source.server));
    final joinedAt = membership.data()?['joinedAt'];
    if (!membership.exists || joinedAt is! Timestamp) {
      throw StateError('A valid Board membership is required.');
    }
    return joinedAt;
  }

  Stream<List<BoardCommentModel>> commentsStream({
    required String gubId,
    required String postId,
  }) {
    final user = _auth.currentUser;
    if (user == null) return Stream.error(StateError('Sign in required.'));
    return Stream.fromFuture(_membershipBoundary(gubId, user.uid)).asyncExpand(
      (joinedAt) => PostRepository.instance.commentsStream(
        gubId: gubId,
        postId: postId,
        joinedAt: joinedAt,
      ),
    );
  }

  Future<void> addComment({
    required String gubId,
    required String postId,
    required String text,
  }) async {
    final user = _auth.currentUser;
    final value = text.trim();
    if (user == null) throw StateError('Sign in required.');
    if (value.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Comment is empty.');
    }
    if (value.length > 1000) {
      throw ArgumentError.value(text, 'text', 'Comment is too long.');
    }
    await GubRepository.instance.ensureActive(gubId);
    final profile = await _firestore.collection('users').doc(user.uid).get();
    final displayName = profile.data()?['displayName'] as String? ?? 'User';
    await PostRepository.instance.addComment(
      gubId: gubId,
      postId: postId,
      authorId: user.uid,
      authorName: displayName,
      text: value,
    );
  }

  Stream<bool> isLikedStream({required String gubId, required String postId}) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(false);
    return PostRepository.instance.isLikedStream(
      gubId: gubId,
      postId: postId,
      userId: user.uid,
    );
  }

  Future<void> toggleLike({
    required String gubId,
    required String postId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in required.');
    await GubRepository.instance.ensureActive(gubId);
    await PostRepository.instance.toggleLike(
      gubId: gubId,
      postId: postId,
      userId: user.uid,
    );
  }
}
