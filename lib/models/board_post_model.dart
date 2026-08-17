import 'package:cloud_firestore/cloud_firestore.dart';

class BoardPostModel {
  final String postId;
  final String authorId;
  final String authorName;
  final String message;
  final int likes;
  final int comments;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final String? lastCommentAuthorId;

  const BoardPostModel({
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.message,
    required this.likes,
    required this.comments,
    required this.createdAt,
    this.updatedAt,
    this.lastCommentAuthorId,
  });

  factory BoardPostModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};

    return BoardPostModel(
      postId: document.id,
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? 'User',
      message: data['message'] as String? ?? '',
      likes: (data['likes'] as num?)?.toInt() ?? 0,
      comments: (data['comments'] as num?)?.toInt() ?? 0,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
      lastCommentAuthorId: data['lastCommentAuthorId'] as String?,
    );
  }
}
