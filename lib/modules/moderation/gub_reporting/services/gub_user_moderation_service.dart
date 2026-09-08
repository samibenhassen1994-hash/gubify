import 'package:firebase_auth/firebase_auth.dart';

import '../../../../repositories/gub_repository.dart';
import '../../../../repositories/member_repository.dart';
import '../../../community/moderation/models/community_report_model.dart';
import '../../../profile/models/user_profile_model.dart';
import '../models/gub_user_moderation_report.dart';
import '../repositories/gub_user_moderation_repository.dart';

class GubUserModerationService {
  GubUserModerationService._({
    String? Function()? currentUserId,
    Future<Map<String, dynamic>?> Function(String gubId)? loadGub,
    Future<Map<String, dynamic>?> Function(String gubId, String userId)?
    loadMember,
    Future<bool> Function(GubUserModerationReport report)? createReport,
  }) : _currentUserId =
           currentUserId ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _loadGub =
           loadGub ??
           ((gubId) => GubRepository.instance.getHubAuthoritatively(gubId)),
       _loadMember =
           loadMember ??
           ((gubId, userId) =>
               MemberRepository.instance.getMember(gubId: gubId, uid: userId)),
       _createReport =
           createReport ?? GubUserModerationRepository.instance.createReport;

  static final GubUserModerationService instance = GubUserModerationService._();

  factory GubUserModerationService.forTesting({
    required String? Function() currentUserId,
    required Future<Map<String, dynamic>?> Function(String gubId) loadGub,
    required Future<Map<String, dynamic>?> Function(String gubId, String userId)
    loadMember,
    required Future<bool> Function(GubUserModerationReport report) createReport,
  }) => GubUserModerationService._(
    currentUserId: currentUserId,
    loadGub: loadGub,
    loadMember: loadMember,
    createReport: createReport,
  );

  final String? Function() _currentUserId;
  final Future<Map<String, dynamic>?> Function(String gubId) _loadGub;
  final Future<Map<String, dynamic>?> Function(String gubId, String userId)
  _loadMember;
  final Future<bool> Function(GubUserModerationReport report) _createReport;

  Future<void> reportUser({
    required String gubId,
    required UserProfileModel user,
    required String reason,
    required String details,
  }) async {
    final reporterId = _requireCurrentUserId();
    final normalizedGubId = gubId.trim();
    final targetUserId = user.userId.trim();
    final normalizedDetails = details.trim();
    if (normalizedGubId.isEmpty) {
      throw ArgumentError.value(gubId, 'gubId');
    }
    if (targetUserId.isEmpty) {
      throw ArgumentError.value(user.userId, 'user.userId');
    }
    if (targetUserId == reporterId) {
      throw ArgumentError.value(
        user.userId,
        'user.userId',
        'Cannot report yourself.',
      );
    }
    if (!CommunityReportReason.values.any((item) => item.value == reason)) {
      throw ArgumentError('Select a report reason.');
    }
    if (normalizedDetails.length > GubUserModerationReport.maxDetailsLength) {
      throw ArgumentError('Details must be 500 characters or fewer.');
    }

    final gub = await _loadGub(normalizedGubId);
    final gubName = gub?['name'];
    if (gub == null ||
        gub['deletionStatus'] == 'deleting' ||
        gubName is! String ||
        gubName.trim().isEmpty) {
      throw StateError('This Gub is no longer available.');
    }
    final member = await _loadMember(normalizedGubId, targetUserId);
    final targetName = member?['displayName'];
    if (member == null || targetName is! String || targetName.trim().isEmpty) {
      throw StateError('This user is no longer a member of this Gub.');
    }

    final report = GubUserModerationReport(
      reportId: 'user__gub__${normalizedGubId}__${targetUserId}__$reporterId',
      reporterId: reporterId,
      gubId: normalizedGubId,
      targetId: targetUserId,
      targetUserId: targetUserId,
      reason: reason,
      details: normalizedDetails,
      gubNameSnapshot: gubName.trim(),
      targetNameSnapshot: targetName.trim(),
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
