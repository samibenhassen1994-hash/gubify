import 'package:firebase_auth/firebase_auth.dart';

import 'community_guidelines_repository.dart';

typedef CommunityGuidelinesCurrentUserId = String? Function();
typedef CommunityGuidelinesAcceptanceCheck =
    Future<bool> Function({required String userId});
typedef CommunityGuidelinesAcceptanceWrite =
    Future<void> Function({required String userId});

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

  Future<bool> hasCurrentUserAccepted() async =>
      _hasAccepted(userId: _requireCurrentUserId());

  Future<void> acceptForCurrentUser() async {
    final userId = _requireCurrentUserId();
    if (!_pendingAcceptances.add(userId)) {
      throw StateError('Community Guidelines acceptance is already pending.');
    }
    try {
      await _accept(userId: userId);
    } finally {
      _pendingAcceptances.remove(userId);
    }
  }
}
