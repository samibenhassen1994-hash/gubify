import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityAskAnswerModel {
  const CommunityAskAnswerModel({
    required this.answerId,
    required this.authorId,
    required this.authorDisplayName,
    required this.text,
    required this.createdAt,
    this.updatedAt,
  });

  final String answerId;
  final String authorId;
  final String authorDisplayName;
  final String text;
  final Timestamp createdAt;
  final Timestamp? updatedAt;

  factory CommunityAskAnswerModel.fromFirestore(
    Map<String, dynamic> data, {
    required String answerId,
  }) => CommunityAskAnswerModel(
    answerId: answerId,
    authorId: data['authorId'] as String? ?? '',
    authorDisplayName: data['authorDisplayName'] as String? ?? 'User',
    text: data['text'] as String? ?? '',
    createdAt: data['createdAt'] is Timestamp
        ? data['createdAt'] as Timestamp
        : Timestamp(0, 0),
    updatedAt: data['updatedAt'] is Timestamp
        ? data['updatedAt'] as Timestamp
        : null,
  );

  Map<String, dynamic> toFirestore() => {
    'answerId': answerId,
    'authorId': authorId,
    'authorDisplayName': authorDisplayName,
    'text': text,
    'createdAt': createdAt,
    if (updatedAt != null) 'updatedAt': updatedAt,
  };

  @override
  bool operator ==(Object other) =>
      other is CommunityAskAnswerModel &&
      other.answerId == answerId &&
      other.authorId == authorId &&
      other.authorDisplayName == authorDisplayName &&
      other.text == text &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    answerId,
    authorId,
    authorDisplayName,
    text,
    createdAt,
    updatedAt,
  );
}
