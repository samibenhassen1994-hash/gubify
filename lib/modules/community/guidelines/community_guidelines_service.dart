import 'package:firebase_auth/firebase_auth.dart';

import 'community_guidelines_repository.dart';

typedef CommunityGuidelinesCurrentUserId = String? Function();
typedef CommunityGuidelinesAcceptanceCheck =
    Future<bool> Function({
      required String communityId,
      required String userId,
    });
typedef CommunityGuidelinesAcceptanceWrite =
    Future<void> Function({
      required String communityId,
      required String userId,
    });

class CommunityGuidelinesService {
  CommunityGuidelinesService._(
    this._currentUserId,
    this._hasAccepted,
    this._accept,
  );

  factory CommunityGuidelinesService.forTesting({
    required CommunityGuidelinesCurrentUserId currentUserId,
    required CommunityGuidelinesAcceptanceCheck hasAccepted,
    required CommunityGuidelinesAcceptanceWrite accept,
  }) => CommunityGuidelinesService._(currentUserId, hasAccepted, accept);

  static final CommunityGuidelinesService instance =
      CommunityGuidelinesService._(
        () => FirebaseAuth.instance.currentUser?.uid,
        CommunityGuidelinesRepository.instance.hasAccepted,
        CommunityGuidelinesRepository.instance.accept,
      );

  final CommunityGuidelinesCurrentUserId _currentUserId;
  final CommunityGuidelinesAcceptanceCheck _hasAccepted;
  final CommunityGuidelinesAcceptanceWrite _accept;
  final Set<String> _pendingAcceptances = <String>{};

  String _requireCurrentUserId() {
    final userId = _currentUserId();
    if (userId == null || userId.isEmpty) {
      throw StateError('A signed-in user is required.');
    }
    return userId;
  }

  Future<bool> hasCurrentUserAccepted(String communityId) async {
    return _hasAccepted(
      communityId: communityId,
      userId: _requireCurrentUserId(),
    );
  }

  Future<void> acceptForCurrentUser(String communityId) async {
    final userId = _requireCurrentUserId();
    final key = '$communityId/$userId';
    if (!_pendingAcceptances.add(key)) {
      throw StateError('Community Guidelines acceptance is already pending.');
    }
    try {
      await _accept(communityId: communityId, userId: userId);
    } finally {
      _pendingAcceptances.remove(key);
    }
  }
}
