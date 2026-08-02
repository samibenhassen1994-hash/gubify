import 'package:firebase_auth/firebase_auth.dart';

import '../repositories/gub_rules_repository.dart';

class GubRulesService {
  GubRulesService._();

  static final GubRulesService instance = GubRulesService._();

  final Set<String> _acceptancesInProgress = {};

  Future<bool> hasCurrentUserAccepted(String gubId) {
    final userId = _requireUserId();
    return GubRulesRepository.instance.hasAccepted(
      gubId: gubId,
      userId: userId,
    );
  }

  Future<void> acceptForCurrentUser(String gubId) async {
    final userId = _requireUserId();
    final key = '$gubId/$userId';
    if (!_acceptancesInProgress.add(key)) {
      throw StateError('The acceptance is already being saved.');
    }
    try {
      await GubRulesRepository.instance.accept(gubId: gubId, userId: userId);
    } finally {
      _acceptancesInProgress.remove(key);
    }
  }

  String _requireUserId() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      throw StateError('You must be signed in to access this Gub.');
    }
    return userId;
  }
}
