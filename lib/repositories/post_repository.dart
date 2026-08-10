import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/board_post_model.dart';

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

  Stream<List<BoardPostModel>> postsStream({
    required String gubId,
    required Timestamp membershipBoundary,
  }) {
    return postsCollection(gubId)
        .where('createdAt', isGreaterThanOrEqualTo: membershipBoundary)
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
    required Timestamp membershipBoundary,
  }) {
    return postsCollection(gubId)
        .where('createdAt', isGreaterThanOrEqualTo: membershipBoundary)
        .orderBy('createdAt')
        .where('createdAt', isGreaterThan: lastReadAt)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(BoardPostModel.fromFirestore)
              .toList(growable: false),
        );
  }
}
