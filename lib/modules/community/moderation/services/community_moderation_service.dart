import 'package:firebase_auth/firebase_auth.dart';

import '../../models/community_model.dart';
import '../../models/community_ask_answer_model.dart';
import '../../models/community_ask_model.dart';
import '../../models/community_chat_message_model.dart';
import '../../../profile/models/user_profile_model.dart';
import '../models/community_report_model.dart';
import '../repositories/community_moderation_repository.dart';

class CommunityModerationService {
  CommunityModerationService._([
    this._currentUserIdOverride,
    this._createReport,
  ]);

  static final CommunityModerationService instance =
      CommunityModerationService._();

  factory CommunityModerationService.forTesting({
    required String? Function() currentUserId,
    required Future<bool> Function(CommunityModerationReport) createReport,
  }) => CommunityModerationService._(currentUserId, createReport);

  final String? Function()? _currentUserIdOverride;
  final Future<bool> Function(CommunityModerationReport)? _createReport;

  Future<void> reportCommunity({
    required CommunityModel community,
    required String reason,
    required String details,
  }) async {
    final reporterId = _currentUserId();
    await _submit(
      CommunityModerationReport(
        reportId: 'community__${community.communityId}__$reporterId',
        reporterId: reporterId,
        communityId: community.communityId,
        targetType: 'community',
        targetId: community.communityId,
        reason: reason,
        details: details,
        communityNameSnapshot: community.name,
      ),
    );
  }

  Future<void> reportUser({
    required String communityId,
    required String communityName,
    required UserProfileModel user,
    required String reason,
    required String details,
  }) async {
    final reporterId = _currentUserId();
    await _submit(
      CommunityModerationReport(
        reportId: 'user__${communityId}__${user.userId}__$reporterId',
        reporterId: reporterId,
        communityId: communityId,
        targetType: 'user',
        targetId: user.userId,
        targetUserId: user.userId,
        reason: reason,
        details: details,
        communityNameSnapshot: communityName,
        targetNameSnapshot: user.displayName,
      ),
    );
  }

  Future<void> reportAsk({
    required CommunityAskModel ask,
    required String communityName,
    required String reason,
    required String details,
  }) async {
    final reporterId = _currentUserId();
    await _submit(
      CommunityModerationReport(
        reportId: 'ask__${ask.communityId}__${ask.askId}__$reporterId',
        reporterId: reporterId,
        communityId: ask.communityId,
        targetType: 'ask',
        targetId: ask.askId,
        targetUserId: ask.authorId,
        reason: reason,
        details: details,
        communityNameSnapshot: communityName,
        targetNameSnapshot: ask.authorDisplayName,
        contentSnapshot: ask.text,
      ),
    );
  }

  Future<void> reportMessage({
    required CommunityChatMessageModel message,
    required String communityName,
    required String reason,
    required String details,
  }) async {
    final reporterId = _currentUserId();
    if (message.senderId == reporterId) {
      throw ArgumentError.value(
        message.senderId,
        'message.senderId',
        'Cannot report your own message.',
      );
    }
    await _submit(
      CommunityModerationReport(
        reportId:
            'message__community__${message.communityId}__${message.messageId}__$reporterId',
        reporterId: reporterId,
        communityId: message.communityId,
        targetType: 'user',
        targetId: message.senderId,
        targetUserId: message.senderId,
        messageId: message.messageId,
        reason: reason,
        details: details,
        communityNameSnapshot: communityName,
        targetNameSnapshot: message.senderName,
        contentSnapshot: message.text,
      ),
    );
  }

  Future<void> reportAnswer({
    required CommunityAskModel ask,
    required CommunityAskAnswerModel answer,
    required String communityName,
    required String reason,
    required String details,
  }) async {
    final reporterId = _currentUserId();
    await _submit(
      CommunityModerationReport(
        reportId:
            'answer__${ask.communityId}__${ask.askId}__${answer.answerId}__$reporterId',
        reporterId: reporterId,
        communityId: ask.communityId,
        askId: ask.askId,
        targetType: 'answer',
        targetId: answer.answerId,
        targetUserId: answer.authorId,
        reason: reason,
        details: details,
        communityNameSnapshot: communityName,
        targetNameSnapshot: answer.authorDisplayName,
        contentSnapshot: answer.text,
      ),
    );
  }

  Future<void> _submit(CommunityModerationReport report) async {
    final normalizedDetails = report.details.trim();
    if (!CommunityReportReason.values.any(
      (reason) => reason.value == report.reason,
    )) {
      throw ArgumentError('Select a report reason.');
    }
    if (normalizedDetails.length > CommunityModerationReport.maxDetailsLength) {
      throw ArgumentError('Details must be 500 characters or fewer.');
    }
    final sanitizedReport = CommunityModerationReport(
      reportId: report.reportId,
      reporterId: report.reporterId,
      communityId: report.communityId,
      targetType: report.targetType,
      targetId: report.targetId,
      askId: report.askId,
      messageId: report.messageId,
      targetUserId: report.targetUserId,
      contentSnapshot: report.contentSnapshot,
      reason: report.reason,
      details: normalizedDetails,
      communityNameSnapshot: report.communityNameSnapshot,
      targetNameSnapshot: report.targetNameSnapshot,
    );
    final created =
        await (_createReport?.call(sanitizedReport) ??
            CommunityModerationRepository.instance.createReport(
              sanitizedReport,
            ));
    if (!created) throw const CommunityReportAlreadyExistsException();
  }

  String _currentUserId() {
    final userId =
        _currentUserIdOverride?.call() ??
        FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      throw StateError('You must be signed in to submit a report.');
    }
    return userId;
  }
}
