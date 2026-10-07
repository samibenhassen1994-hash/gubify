import '../models/community_model.dart';
import 'platform_admin_service.dart';
import 'platform_moderation_model.dart';
import 'platform_moderation_repository.dart';

class PlatformModerationService {
  PlatformModerationService({
    required this.role,
    PlatformModerationRepository? repository,
  }) : _repository = repository ?? PlatformModerationRepository();

  static const reportStatuses = <String>[
    'open',
    'reviewed',
    'action_taken',
    'escalated',
    'closed',
  ];

  final PlatformAdminService role;
  final PlatformModerationRepository _repository;

  Stream<List<CommunityModel>> communities(int limit) {
    role.requireAdmin();
    return _repository.communities(limit);
  }

  Stream<List<PlatformReportItem>> reports(int limit) {
    role.requireAdmin();
    return _repository.reports(limit);
  }

  Stream<List<PlatformModerationItem>> content(
    String communityId,
    PlatformContentKind kind,
    String? askId,
    int limit,
  ) {
    role.requireAdmin();
    return _repository.content(communityId, kind, askId, limit);
  }

  Future<void> updateReportStatus({
    required String reportId,
    required String status,
    required String actionNote,
  }) async {
    role.requireAdmin();
    if (!reportStatuses.contains(status)) {
      throw ArgumentError.value(status, 'status', 'Unsupported report status.');
    }
    if (actionNote.trim().length > 500) {
      throw ArgumentError('Action note must be 500 characters or fewer.');
    }
    await _repository.updateReportStatus(
      reportId: reportId,
      status: status,
      actorId: role.adminUid!,
      actionNote: actionNote,
    );
  }

  Future<void> setHidden({
    required String communityId,
    required PlatformContentKind kind,
    String? askId,
    required String itemId,
    required bool hidden,
  }) async {
    role.requireAdmin();
    if (kind == PlatformContentKind.answers &&
        (askId == null || askId.isEmpty)) {
      throw ArgumentError('An Ask is required.');
    }
    await _repository.setHidden(
      communityId: communityId,
      kind: kind,
      askId: askId,
      itemId: itemId,
      hidden: hidden,
      actorId: role.adminUid!,
    );
  }
}
