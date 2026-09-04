import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityReportReason {
  final String value;
  final String label;

  const CommunityReportReason(this.value, this.label);

  static const values = <CommunityReportReason>[
    CommunityReportReason('spam', 'Spam'),
    CommunityReportReason('harassment_or_bullying', 'Harassment or bullying'),
    CommunityReportReason('hate_or_abusive_content', 'Hate or abusive content'),
    CommunityReportReason('inappropriate_content', 'Inappropriate content'),
    CommunityReportReason('scam_or_fraud', 'Scam or fraud'),
    CommunityReportReason('impersonation', 'Impersonation'),
    CommunityReportReason('other', 'Other'),
  ];
}

class CommunityModerationReport {
  static const int maxDetailsLength = 500;

  final String reportId;
  final String reporterId;
  final String communityId;
  final String targetType;
  final String targetId;
  final String? askId;
  final String? targetUserId;
  final String? contentSnapshot;
  final String reason;
  final String details;
  final String communityNameSnapshot;
  final String? targetNameSnapshot;

  const CommunityModerationReport({
    required this.reportId,
    required this.reporterId,
    required this.communityId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.details,
    required this.communityNameSnapshot,
    this.targetUserId,
    this.askId,
    this.contentSnapshot,
    this.targetNameSnapshot,
  });

  String get moderationTargetKey => switch (targetType) {
    'community' => 'community__$targetId',
    'user' => 'user__$targetId',
    'ask' => 'ask__${communityId}__$targetId',
    'answer' => 'answer__${communityId}__${askId}__$targetId',
    _ => throw StateError('Unsupported moderation target type.'),
  };

  String get moderationTargetNameSnapshot =>
      targetType == 'community' ? communityNameSnapshot : targetNameSnapshot!;

  Map<String, dynamic> toFirestore() => {
    'reportId': reportId,
    'reporterId': reporterId,
    'communityId': communityId,
    'targetType': targetType,
    'targetId': targetId,
    if (askId != null) 'askId': askId,
    if (targetUserId != null) 'targetUserId': targetUserId,
    if (contentSnapshot != null) 'contentSnapshot': contentSnapshot,
    'reason': reason,
    'details': details,
    'createdAt': FieldValue.serverTimestamp(),
    'status': 'open',
    'communityNameSnapshot': communityNameSnapshot,
    if (targetNameSnapshot != null) 'targetNameSnapshot': targetNameSnapshot,
  };
}

class CommunityReportAlreadyExistsException implements Exception {
  const CommunityReportAlreadyExistsException();
}
