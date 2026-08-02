import 'package:firebase_auth/firebase_auth.dart';

import '../repositories/gub_deletion_repository.dart';
import '../repositories/gub_repository.dart';

class GubDeletionAccess {
  final bool isOwner;
  final String gubName;

  const GubDeletionAccess({required this.isOwner, required this.gubName});
}

class GubDeletionException implements Exception {
  final String message;

  const GubDeletionException(this.message);

  @override
  String toString() => 'GubDeletionException: $message';
}

class GubDeletionService {
  GubDeletionService._();

  static final GubDeletionService instance = GubDeletionService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Set<String> _deletionsInProgress = {};

  Future<GubDeletionAccess> access(String gubId) async {
    final user = _auth.currentUser;
    if (user == null) {
      return const GubDeletionAccess(isOwner: false, gubName: '');
    }
    final target = await GubDeletionRepository.instance.getTarget(gubId);
    return GubDeletionAccess(
      isOwner: target?.ownerId == user.uid,
      gubName: target?.name ?? '',
    );
  }

  Future<bool> isCurrentUserOwner(String gubId) async =>
      (await access(gubId)).isOwner;

  Future<void> deleteGubCompletely({
    required String gubId,
    required String confirmedName,
    required void Function(String) onProgress,
  }) => _runDeletion(
    gubId: gubId,
    confirmedName: confirmedName,
    onProgress: onProgress,
  );

  Future<void> resumeDeletion({
    required String gubId,
    required void Function(String) onProgress,
  }) => _runDeletion(gubId: gubId, confirmedName: null, onProgress: onProgress);

  Future<void> _runDeletion({
    required String gubId,
    required String? confirmedName,
    required void Function(String) onProgress,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const GubDeletionException(
        'You must be signed in to delete this Gub.',
      );
    }
    if (!_deletionsInProgress.add(gubId)) {
      throw const GubDeletionException(
        'This Gub deletion is already in progress.',
      );
    }
    try {
      if (confirmedName != null) {
        final target = await GubDeletionRepository.instance.getTarget(gubId);
        if (target == null) {
          throw const GubDeletionException('This Gub is no longer available.');
        }
        if (target.ownerId != user.uid) {
          throw const GubDeletionException(
            'Only the Gub owner can delete this Gub.',
          );
        }
        if (confirmedName != target.name) {
          throw const GubDeletionException(
            'The Gub name has changed. Reopen Manage Gub and try again.',
          );
        }
      }
      await GubDeletionRepository.instance.deleteGubCompletely(
        gubId: gubId,
        ownerId: user.uid,
        confirmedName: confirmedName,
        onPhase: (phase) => onProgress(_progressMessage(phase)),
      );
      GubRepository.instance.removeHub(gubId);
    } on GubDeletionException {
      rethrow;
    } on FirebaseException catch (error) {
      throw GubDeletionException(_firebaseErrorMessage(error));
    } on StateError catch (error) {
      throw GubDeletionException(error.message);
    } finally {
      _deletionsInProgress.remove(gubId);
    }
  }

  String _progressMessage(GubDeletionPhase phase) => switch (phase) {
    GubDeletionPhase.preparing => 'Preparing deletion...',
    GubDeletionPhase.nestedCollections => 'Deleting nested data...',
    GubDeletionPhase.directCollections => 'Deleting Gub data...',
    GubDeletionPhase.userCopies => 'Removing member data...',
    GubDeletionPhase.finalizing => 'Finishing deletion...',
  };

  String _firebaseErrorMessage(FirebaseException error) => switch (error.code) {
    'permission-denied' =>
      'Deletion is not permitted by the current Firestore rules.',
    'unavailable' =>
      'The network is unavailable. Reconnect and retry the deletion.',
    'unauthenticated' => 'You must be signed in to delete this Gub.',
    _ => 'The Gub was not completely deleted. Please retry.',
  };
}
