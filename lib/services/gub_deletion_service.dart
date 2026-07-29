import 'package:firebase_auth/firebase_auth.dart';

import '../repositories/gub_repository.dart';

/// Deliberately does not delete client-side: Firestore clients cannot discover
/// and recursively remove all nested data and each member's user copy safely.
class GubDeletionService {
  GubDeletionService._();

  static final GubDeletionService instance = GubDeletionService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<bool> isCurrentUserOwner(String gubId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final gub = await GubRepository.instance.getHub(gubId);
    return gub?["ownerId"] == user.uid;
  }

  Future<void> deleteGub(String gubId) async {
    if (!await isCurrentUserOwner(gubId)) {
      throw StateError("Only the owner can delete this Gub.");
    }

    throw UnsupportedError(
      "Secure deletion is not available yet. It requires server-side cleanup.",
    );
  }
}
