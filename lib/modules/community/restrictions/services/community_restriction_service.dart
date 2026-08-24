import 'package:firebase_auth/firebase_auth.dart';

import '../../models/community_model.dart';
import '../models/community_restriction_model.dart';
import '../repositories/community_restriction_repository.dart';

class CommunityRestrictionService {
  CommunityRestrictionService._();

  static final CommunityRestrictionService instance =
      CommunityRestrictionService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<PlatformRestriction> currentUserPlatformRestrictionStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      return Stream.value(PlatformRestriction.unrestricted);
    }
    return CommunityRestrictionRepository.instance.platformRestrictionStream(
      userId,
    );
  }

  Future<bool> initializePlatformRestriction(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return Future.value(false);
    return CommunityRestrictionRepository.instance
        .initializePlatformRestriction(normalizedUserId);
  }

  Stream<CommunityRestriction> communityRestrictionStream(String communityId) {
    final normalizedId = communityId.trim();
    if (normalizedId.isEmpty) {
      return Stream.value(CommunityRestriction.unrestricted);
    }
    return CommunityRestrictionRepository.instance.communityRestrictionStream(
      normalizedId,
    );
  }

  Future<bool> initializeCommunityRestriction({
    required String communityId,
    required String ownerId,
  }) {
    final normalizedCommunityId = communityId.trim();
    final normalizedOwnerId = ownerId.trim();
    if (normalizedCommunityId.isEmpty || normalizedOwnerId.isEmpty) {
      return Future.value(false);
    }
    return CommunityRestrictionRepository.instance
        .initializeCommunityRestriction(
          communityId: normalizedCommunityId,
          ownerId: normalizedOwnerId,
        );
  }

  Future<List<CommunityModel>> filterDiscoverableCommunities(
    Iterable<CommunityModel> communities,
  ) async {
    final items = communities.toList(growable: false);
    if (items.isEmpty) return items;

    final hiddenIds = await CommunityRestrictionRepository.instance
        .hiddenCommunityIds(items.map((community) => community.communityId));
    return items
        .where((community) => !hiddenIds.contains(community.communityId))
        .toList(growable: false);
  }
}
