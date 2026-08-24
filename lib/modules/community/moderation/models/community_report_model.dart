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
  final String? targetUserId;
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
    this.targetNameSnapshot,
  });

  String get moderationTargetKey =>
      targetType == 'community' ? 'community__$targetId' : 'user__$targetId';

  String get moderationTargetNameSnapshot =>
      targetType == 'community' ? communityNameSnapshot : targetNameSnapshot!;

  Map<String, dynamic> toFirestore() => {
    'reportId': reportId,
    'reporterId': reporterId,
    'communityId': communityId,
    'targetType': targetType,
    'targetId': targetId,
    if (targetUserId != null) 'targetUserId': targetUserId,
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
