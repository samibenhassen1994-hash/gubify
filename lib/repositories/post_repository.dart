import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/board_post_model.dart';
import '../models/board_comment_model.dart';

class PostRepository {
  PostRepository._();

  static final PostRepository instance = PostRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> postsCollection(String gubId) {
    return _firestore.collection('gubs').doc(gubId).collection('posts');
  }

  Future<void> createPost({
    required String gubId,
    required String authorId,
    required String authorName,
    required String? authorPhoto,
    required String message,
  }) {
    return postsCollection(gubId).add({
      'gubId': gubId,
      'authorId': authorId,
      'authorName': authorName,
      'authorPhoto': authorPhoto,
      'message': message,
      'likes': 0,
      'comments': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<BoardPostModel>> postsStream(String gubId) {
    return postsCollection(gubId)
        .orderBy('createdAt', descending: true)
        .limit(25)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(BoardPostModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Stream<List<BoardPostModel>> postsAfterStream({
    required String gubId,
    required Timestamp lastReadAt,
  }) {
    return postsCollection(gubId)
        .orderBy('updatedAt')
        .where('updatedAt', isGreaterThan: lastReadAt)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(BoardPostModel.fromFirestore)
              .toList(growable: false),
        );
  }

  Stream<Map<String, dynamic>?> gubBoardStateStream(String gubId) => _firestore
      .collection('gubs')
      .doc(gubId)
      .snapshots()
      .map((doc) => doc.data());

  Future<void> setPinnedPost({required String gubId, String? postId}) =>
      _firestore.collection('gubs').doc(gubId).update({
        'pinnedBoardPostId': postId,
      });

  CollectionReference<Map<String, dynamic>> commentsCollection(
    String gubId,
    String postId,
  ) => postsCollection(gubId).doc(postId).collection('comments');

  Stream<List<BoardCommentModel>> commentsStream({
    required String gubId,
    required String postId,
    required Timestamp joinedAt,
  }) => commentsCollection(gubId, postId)
      .where('createdAt', isGreaterThanOrEqualTo: joinedAt)
      .orderBy('createdAt')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(BoardCommentModel.fromFirestore)
            .toList(growable: false),
      );

  Future<void> addComment({
    required String gubId,
    required String postId,
    required String authorId,
    required String authorName,
    required String text,
  }) async {
    final post = postsCollection(gubId).doc(postId);
    final comment = commentsCollection(gubId, postId).doc();
    final batch = _firestore.batch();
    batch.set(comment, {
      'commentId': comment.id,
      'authorId': authorId,
      'authorName': authorName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(post, {
      'comments': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastCommentAuthorId': authorId,
      'lastCommentId': comment.id,
    });
    await batch.commit();
  }

  DocumentReference<Map<String, dynamic>> likeDocument({
    required String gubId,
    required String postId,
    required String userId,
  }) => postsCollection(gubId).doc(postId).collection('likes').doc(userId);

  Stream<bool> isLikedStream({
    required String gubId,
    required String postId,
    required String userId,
  }) => likeDocument(
    gubId: gubId,
    postId: postId,
    userId: userId,
  ).snapshots().map((doc) => doc.exists);

  Future<void> toggleLike({
    required String gubId,
    required String postId,
    required String userId,
  }) => _firestore.runTransaction((transaction) async {
    final post = postsCollection(gubId).doc(postId);
    final like = likeDocument(gubId: gubId, postId: postId, userId: userId);
    final snapshots = await Future.wait([
      transaction.get(post),
      transaction.get(like),
    ]);
    if (!snapshots[0].exists) throw StateError('Board post not found.');
    final liked = snapshots[1].exists;
    if (liked) {
      transaction.delete(like);
    } else {
      transaction.set(like, {
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    transaction.update(post, {'likes': FieldValue.increment(liked ? -1 : 1)});
  });
}
