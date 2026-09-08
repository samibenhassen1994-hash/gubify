import 'package:cloud_firestore/cloud_firestore.dart';

class GubMessageModerationReport {
  static const int maxDetailsLength = 500;

  const GubMessageModerationReport({
    required this.reportId,
    required this.reporterId,
    required this.gubId,
    required this.targetId,
    required this.targetUserId,
    required this.messageId,
    required this.reason,
    required this.details,
    required this.gubNameSnapshot,
    required this.targetNameSnapshot,
    required this.contentSnapshot,
  });

  final String reportId;
  final String reporterId;
  final String gubId;
  final String targetId;
  final String targetUserId;
  final String messageId;
  final String reason;
  final String details;
  final String gubNameSnapshot;
  final String targetNameSnapshot;
  final String contentSnapshot;

  String get targetType => 'user';

  String get moderationTargetKey => 'user__$targetUserId';

  Map<String, dynamic> toFirestore() => {
    'reportId': reportId,
    'reporterId': reporterId,
    'gubId': gubId,
    'targetType': targetType,
    'targetId': targetId,
    'targetUserId': targetUserId,
    'messageId': messageId,
    'reason': reason,
    'details': details,
    'createdAt': FieldValue.serverTimestamp(),
    'status': 'open',
    'gubNameSnapshot': gubNameSnapshot,
    'targetNameSnapshot': targetNameSnapshot,
    'contentSnapshot': contentSnapshot,
  };
}
