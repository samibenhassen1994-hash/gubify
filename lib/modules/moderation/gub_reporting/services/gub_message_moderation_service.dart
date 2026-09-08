import 'package:firebase_auth/firebase_auth.dart';

import '../../../../repositories/gub_repository.dart';
import '../../../chat/models/chat_message_model.dart';
import '../../../community/moderation/models/community_report_model.dart';
import '../models/gub_message_moderation_report.dart';
import '../repositories/gub_message_moderation_repository.dart';

class GubMessageModerationService {
  GubMessageModerationService._({
    String? Function()? currentUserId,
    Future<Map<String, dynamic>?> Function(String gubId)? loadGub,
    Future<bool> Function(GubMessageModerationReport report)? createReport,
  }) : _currentUserId =
           currentUserId ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _loadGub =
           loadGub ??
           ((gubId) => GubRepository.instance.getHubAuthoritatively(gubId)),
       _createReport =
           createReport ?? GubMessageModerationRepository.instance.createReport;

  static final GubMessageModerationService instance =
      GubMessageModerationService._();

  factory GubMessageModerationService.forTesting({
    required String? Function() currentUserId,
    required Future<Map<String, dynamic>?> Function(String gubId) loadGub,
    required Future<bool> Function(GubMessageModerationReport report)
    createReport,
  }) => GubMessageModerationService._(
    currentUserId: currentUserId,
    loadGub: loadGub,
    createReport: createReport,
  );

  final String? Function() _currentUserId;
  final Future<Map<String, dynamic>?> Function(String gubId) _loadGub;
  final Future<bool> Function(GubMessageModerationReport report) _createReport;

  Future<void> reportMessage({
    required ChatMessageModel message,
    required String reason,
    required String details,
  }) async {
    final reporterId = _requireCurrentUserId();
    final gubId = message.gubId.trim();
    final messageId = message.messageId.trim();
    final targetUserId = message.senderId.trim();
    final normalizedDetails = details.trim();
    if (gubId.isEmpty) throw ArgumentError.value(message.gubId, 'message.gubId');
    if (messageId.isEmpty) {
      throw ArgumentError.value(message.messageId, 'message.messageId');
    }
    if (targetUserId.isEmpty) {
      throw ArgumentError.value(message.senderId, 'message.senderId');
    }
    if (targetUserId == reporterId) {
      throw ArgumentError.value(
        message.senderId,
        'message.senderId',
        'Cannot report your own message.',
      );
    }
    if (!CommunityReportReason.values.any((item) => item.value == reason)) {
      throw ArgumentError('Select a report reason.');
    }
    if (normalizedDetails.length > GubMessageModerationReport.maxDetailsLength) {
      throw ArgumentError('Details must be 500 characters or fewer.');
    }

    final gub = await _loadGub(gubId);
    final gubName = gub?['name'];
    if (gub == null ||
        gub['deletionStatus'] == 'deleting' ||
        gubName is! String ||
        gubName.trim().isEmpty) {
      throw StateError('This Gub is no longer available.');
    }

    final report = GubMessageModerationReport(
      reportId: 'message__gub__${gubId}__${messageId}__$reporterId',
      reporterId: reporterId,
      gubId: gubId,
      targetId: targetUserId,
      targetUserId: targetUserId,
      messageId: messageId,
      reason: reason,
      details: normalizedDetails,
      gubNameSnapshot: gubName.trim(),
      targetNameSnapshot: message.senderName,
      contentSnapshot: message.text,
    );
    if (!await _createReport(report)) {
      throw const CommunityReportAlreadyExistsException();
    }
  }

  String _requireCurrentUserId() {
    final userId = _currentUserId()?.trim();
    if (userId == null || userId.isEmpty) {
      throw StateError('You must be signed in to submit a report.');
    }
    return userId;
  }
}
