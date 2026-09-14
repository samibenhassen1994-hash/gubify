import '../models/community_model.dart';
import 'platform_admin_service.dart';
import 'platform_moderation_model.dart';
import 'platform_moderation_repository.dart';

class PlatformModerationService {
  PlatformModerationService({
    required this.role,
    PlatformModerationRepository? repository,
  }) : _repository = repository ?? PlatformModerationRepository();
  final PlatformAdminService role;
  final PlatformModerationRepository _repository;
  Stream<List<CommunityModel>> communities(int limit) {
    role.requireAdmin();
    return _repository.communities(limit);
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
