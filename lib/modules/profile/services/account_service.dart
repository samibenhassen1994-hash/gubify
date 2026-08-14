import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../services/auth_service.dart';
import '../models/account_details_model.dart';
import '../repositories/account_repository.dart';

enum NameChangeStatus {
  success,
  noCurrentUser,
  invalidName,
  unchanged,
  cooldown,
  permissionDenied,
  unknownFailure,
}

class NameChangeResult {
  const NameChangeResult(this.status, {this.eligibleAt});

  final NameChangeStatus status;
  final DateTime? eligibleAt;

  bool get isSuccess => status == NameChangeStatus.success;
}

class AccountService {
  AccountService({
    required this.authService,
    AccountProfileRepository? repository,
    DateTime Function()? now,
  }) : _repository = repository ?? AccountRepository(),
       _now = now ?? DateTime.now;

  static const nameChangeCooldown = Duration(days: 30);

  final AuthService authService;
  final AccountProfileRepository _repository;
  final DateTime Function() _now;

  Future<AccountDetailsModel?> load() async {
    final userId = authService.currentUserId;
    return userId == null ? null : _repository.load(userId);
  }

  DateTime? nextNameChangeAt(AccountDetailsModel details) {
    return details.displayNameChangedAt?.toDate().add(nameChangeCooldown);
  }

  bool canChangeName(AccountDetailsModel details) {
    final eligibleAt = nextNameChangeAt(details);
    return eligibleAt == null || !_now().isBefore(eligibleAt);
  }

  Future<NameChangeResult> changeDisplayName({
    required AccountDetailsModel current,
    required String displayName,
  }) async {
    final userId = authService.currentUserId;
    if (userId == null) {
      return const NameChangeResult(NameChangeStatus.noCurrentUser);
    }
    final trimmed = displayName.trim();
    if (trimmed.isEmpty || trimmed.length > 22) {
      return const NameChangeResult(NameChangeStatus.invalidName);
    }
    if (trimmed == current.displayName.trim()) {
      return const NameChangeResult(NameChangeStatus.unchanged);
    }
    final eligibleAt = nextNameChangeAt(current);
    if (eligibleAt != null && _now().isBefore(eligibleAt)) {
      return NameChangeResult(
        NameChangeStatus.cooldown,
        eligibleAt: eligibleAt,
      );
    }

    try {
      await _repository.changeDisplayName(userId: userId, displayName: trimmed);
      return const NameChangeResult(NameChangeStatus.success);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        return NameChangeResult(
          NameChangeStatus.permissionDenied,
          eligibleAt: eligibleAt,
        );
      }
      return const NameChangeResult(NameChangeStatus.unknownFailure);
    } catch (_) {
      return const NameChangeResult(NameChangeStatus.unknownFailure);
    }
  }
}
