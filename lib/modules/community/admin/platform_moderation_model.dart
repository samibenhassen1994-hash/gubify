import 'package:cloud_firestore/cloud_firestore.dart';

import '../moderation/models/community_report_model.dart';

enum PlatformContentKind { messages, asks, answers }

class PlatformModerationItem {
  const PlatformModerationItem({
    required this.id,
    required this.text,
    required this.author,
    required this.hidden,
    this.status = '',
    this.bestAnswerId,
  });

  final String id;
  final String text;
  final String author;
  final bool hidden;
  final String status;
  final String? bestAnswerId;

  factory PlatformModerationItem.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) => PlatformModerationItem(
    id: id,
    text: data['text'] as String? ?? '',
    author:
        (data['senderName'] ?? data['authorDisplayName']) as String? ?? 'User',
    hidden: data['moderationHidden'] == true,
    status: data['status'] as String? ?? '',
    bestAnswerId: data['bestAnswerId'] as String?,
  );
}

class PlatformReportItem {
  const PlatformReportItem({
    required this.id,
    required this.reason,
    required this.status,
    required this.sourceName,
    required this.sourceKind,
    required this.targetType,
    required this.targetId,
    required this.reporterId,
    required this.priority,
    this.targetName,
    this.details = '',
    this.contentSnapshot,
    this.actionNote = '',
    this.createdAt,
  });

  final String id;
  final String reason;
  final String status;
  final String sourceName;
  final String sourceKind;
  final String targetType;
  final String targetId;
  final String reporterId;
  final String priority;
  final String? targetName;
  final String details;
  final String? contentSnapshot;
  final String actionNote;
  final Timestamp? createdAt;

  bool get isChildSafety => CommunityReportReason.isChildSafety(reason);
  bool get isCritical => priority == 'critical' || isChildSafety;

  String get reasonLabel {
    for (final item in CommunityReportReason.values) {
      if (item.value == reason) return item.label;
    }
    return reason.isEmpty ? 'Unknown' : reason.replaceAll('_', ' ');
  }

  factory PlatformReportItem.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final reason = data['reason'] as String? ?? '';
    final gubName = data['gubNameSnapshot'] as String?;
    final communityName = data['communityNameSnapshot'] as String?;
    return PlatformReportItem(
      id: id,
      reason: reason,
      status: data['status'] as String? ?? 'open',
      sourceName: gubName ?? communityName ?? 'Unknown space',
      sourceKind: gubName != null ? 'Private Gub' : 'Community',
      targetType: data['targetType'] as String? ?? 'unknown',
      targetId: data['targetId'] as String? ?? '',
      reporterId: data['reporterId'] as String? ?? '',
      targetName: data['targetNameSnapshot'] as String?,
      priority:
          data['priority'] as String? ??
          CommunityReportReason.priorityFor(reason),
      details: data['details'] as String? ?? '',
      contentSnapshot: data['contentSnapshot'] as String?,
      actionNote: data['actionNote'] as String? ?? '',
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}

class PlatformReportEvent {
  const PlatformReportEvent({
    required this.id,
    required this.previousStatus,
    required this.status,
    required this.actorId,
    required this.actionNote,
    this.createdAt,
  });

  final String id;
  final String previousStatus;
  final String status;
  final String actorId;
  final String actionNote;
  final Timestamp? createdAt;

  factory PlatformReportEvent.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) => PlatformReportEvent(
    id: id,
    previousStatus: data['previousStatus'] as String? ?? '',
    status: data['status'] as String? ?? '',
    actorId: data['actorId'] as String? ?? '',
    actionNote: data['actionNote'] as String? ?? '',
    createdAt: data['createdAt'] as Timestamp?,
  );
}
