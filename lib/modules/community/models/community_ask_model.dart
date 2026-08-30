import 'package:cloud_firestore/cloud_firestore.dart';

enum CommunityAskType {
  help('help', 'Help', 'Need a solution to a problem'),
  information('information', 'Information', 'Looking for a specific answer'),
  advice('advice', 'Advice', 'Looking for suggestions or opinions');

  const CommunityAskType(this.value, this.label, this.description);

  final String value;
  final String label;
  final String description;

  static CommunityAskType fromValue(String value) =>
      values.firstWhere((type) => type.value == value, orElse: () => help);
}

enum CommunityAskStatus {
  active('active'),
  closed('closed');

  const CommunityAskStatus(this.value);

  final String value;

  static CommunityAskStatus fromValue(String value) => values.firstWhere(
    (status) => status.value == value,
    orElse: () => active,
  );
}

class CommunityAskModel {
  const CommunityAskModel({
    required this.askId,
    required this.communityId,
    required this.authorId,
    required this.authorDisplayName,
    required this.type,
    required this.text,
    this.sourceMessageId,
    required this.createdAt,
    required this.status,
  });

  final String askId;
  final String communityId;
  final String authorId;
  final String authorDisplayName;
  final CommunityAskType type;
  final String text;
  final String? sourceMessageId;
  final Timestamp createdAt;
  final CommunityAskStatus status;

  factory CommunityAskModel.fromFirestore(
    Map<String, dynamic> data, {
    required String askId,
  }) {
    final createdAt = data['createdAt'];
    return CommunityAskModel(
      askId: askId,
      communityId: data['communityId'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      authorDisplayName: data['authorDisplayName'] as String? ?? 'User',
      type: CommunityAskType.fromValue(data['type'] as String? ?? ''),
      text: data['text'] as String? ?? '',
      sourceMessageId: data['sourceMessageId'] as String?,
      createdAt: createdAt is Timestamp ? createdAt : Timestamp(0, 0),
      status: CommunityAskStatus.fromValue(data['status'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toFirestore() => <String, dynamic>{
    'askId': askId,
    'communityId': communityId,
    'authorId': authorId,
    'authorDisplayName': authorDisplayName,
    'type': type.value,
    'text': text,
    if (sourceMessageId != null) 'sourceMessageId': sourceMessageId,
    'createdAt': createdAt,
    'status': status.value,
  };
}
