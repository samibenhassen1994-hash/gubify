import 'package:cloud_firestore/cloud_firestore.dart';

class BoardCommentModel {
  const BoardCommentModel({
    required this.commentId,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  final String commentId;
  final String authorId;
  final String authorName;
  final String text;
  final Timestamp? createdAt;

  factory BoardCommentModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return BoardCommentModel(
      commentId: document.id,
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? 'User',
      text: data['text'] as String? ?? '',
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}
