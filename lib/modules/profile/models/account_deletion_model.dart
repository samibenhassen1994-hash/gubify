class OwnedAccountResource {
  const OwnedAccountResource({required this.id, required this.name});

  final String id;
  final String name;
}

class AccountDeletionPreflight {
  const AccountDeletionPreflight({
    this.privateGubs = const [],
    this.communities = const [],
  });

  final List<OwnedAccountResource> privateGubs;
  final List<OwnedAccountResource> communities;

  bool get isBlocked => privateGubs.isNotEmpty || communities.isNotEmpty;
}

class AccountDeletionMemberships {
  const AccountDeletionMemberships({
    this.privateGubIds = const [],
    this.communityIds = const [],
  });

  final List<String> privateGubIds;
  final List<String> communityIds;
}

enum AccountDeletionReauthentication { none, password, google }

enum AccountDeletionStatus {
  success,
  noCurrentUser,
  ownershipBlocked,
  wrongPassword,
  wrongGoogleAccount,
  reauthenticationCancelled,
  reauthenticationFailed,
  cleanupFailed,
  authDeletionFailed,
}

class AccountDeletionResult {
  const AccountDeletionResult(this.status, {this.preflight});

  final AccountDeletionStatus status;
  final AccountDeletionPreflight? preflight;

  bool get isSuccess => status == AccountDeletionStatus.success;
}
