import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_block_model.dart';
import '../repositories/user_block_repository.dart';

class UserBlockService {
  UserBlockService._({
    String? Function()? currentUserId,
    UserBlockRepository? repository,
  }) : _currentUserId =
           currentUserId ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _repository = repository ?? FirestoreUserBlockRepository();

  static final UserBlockService instance = UserBlockService._();

  factory UserBlockService.forTesting({
    required String? Function() currentUserId,
    required UserBlockRepository repository,
  }) =>
      UserBlockService._(currentUserId: currentUserId, repository: repository);

  final String? Function() _currentUserId;
  final UserBlockRepository _repository;

  Future<void> blockUser(String targetUserId) async {
    final currentUserId = _requireCurrentUserId();
    await _repository.blockUser(
      blockerUserId: currentUserId,
      blockedUserId: _validateTarget(
        targetUserId,
        currentUserId: currentUserId,
      ),
    );
  }

  Future<void> unblockUser(String targetUserId) async {
    final currentUserId = _requireCurrentUserId();
    await _repository.unblockUser(
      blockerUserId: currentUserId,
      blockedUserId: _validateTarget(
        targetUserId,
        currentUserId: currentUserId,
      ),
    );
  }

  Stream<bool> isUserBlockedStream(String targetUserId) {
    final currentUserId = _requireCurrentUserId();
    final targetId = _validateTarget(
      targetUserId,
      currentUserId: currentUserId,
    );
    return _repository
        .blockStream(blockerUserId: currentUserId, blockedUserId: targetId)
        .map((block) => block != null)
        .distinct();
  }

  Stream<List<UserBlockModel>> blockedUsersStream() =>
      _repository.blockedUsersStream(blockerUserId: _requireCurrentUserId());

  String _requireCurrentUserId() {
    final userId = _currentUserId()?.trim();
    if (userId == null || userId.isEmpty) {
      throw StateError('You must be signed in to manage blocked users.');
    }
    return userId;
  }

  String _validateTarget(String targetUserId, {String? currentUserId}) {
    final targetId = targetUserId.trim();
    if (targetId.isEmpty) {
      throw ArgumentError.value(targetUserId, 'targetUserId');
    }
    final userId = currentUserId ?? _requireCurrentUserId();
    if (targetId == userId) {
      throw ArgumentError.value(
        targetUserId,
        'targetUserId',
        'Cannot block yourself.',
      );
    }
    return targetId;
  }
}
