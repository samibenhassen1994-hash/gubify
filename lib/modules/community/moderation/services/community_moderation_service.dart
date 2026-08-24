import 'package:firebase_auth/firebase_auth.dart';

import '../../models/community_model.dart';
import '../../../profile/models/user_profile_model.dart';
import '../models/community_report_model.dart';
import '../repositories/community_moderation_repository.dart';

class CommunityModerationService {
  CommunityModerationService._();

  static final CommunityModerationService instance =
      CommunityModerationService._();

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
    final created = await CommunityModerationRepository.instance.createReport(
      CommunityModerationReport(
        reportId: report.reportId,
        reporterId: report.reporterId,
        communityId: report.communityId,
        targetType: report.targetType,
        targetId: report.targetId,
        targetUserId: report.targetUserId,
        reason: report.reason,
        details: normalizedDetails,
        communityNameSnapshot: report.communityNameSnapshot,
        targetNameSnapshot: report.targetNameSnapshot,
      ),
    );
    if (!created) throw const CommunityReportAlreadyExistsException();
  }

  String _currentUserId() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      throw StateError('You must be signed in to submit a report.');
    }
    return userId;
  }
}
