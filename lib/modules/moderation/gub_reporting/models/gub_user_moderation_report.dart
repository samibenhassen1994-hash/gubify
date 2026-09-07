import 'package:cloud_firestore/cloud_firestore.dart';

class GubUserModerationReport {
  static const int maxDetailsLength = 500;

  const GubUserModerationReport({
    required this.reportId,
    required this.reporterId,
    required this.gubId,
    required this.targetId,
    required this.targetUserId,
    required this.reason,
    required this.details,
    required this.gubNameSnapshot,
    required this.targetNameSnapshot,
  });

  final String reportId;
  final String reporterId;
  final String gubId;
  final String targetId;
  final String targetUserId;
  final String reason;
  final String details;
  final String gubNameSnapshot;
  final String targetNameSnapshot;

  String get targetType => 'user';

  String get moderationTargetKey => 'user__$targetUserId';

  Map<String, dynamic> toFirestore() => {
    'reportId': reportId,
    'reporterId': reporterId,
    'gubId': gubId,
    'targetType': targetType,
    'targetId': targetId,
    'targetUserId': targetUserId,
    'reason': reason,
    'details': details,
    'createdAt': FieldValue.serverTimestamp(),
    'status': 'open',
    'gubNameSnapshot': gubNameSnapshot,
    'targetNameSnapshot': targetNameSnapshot,
  };
}
