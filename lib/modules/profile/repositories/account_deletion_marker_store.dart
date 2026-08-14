import 'package:shared_preferences/shared_preferences.dart';

abstract interface class AccountDeletionMarkerStore {
  Future<String?> readUserId();
  Future<void> writeUserId(String userId);
  Future<void> clear();
}

class SharedPreferencesAccountDeletionMarkerStore
    implements AccountDeletionMarkerStore {
  static const _key = 'accountDeletionInProgressUid';

  @override
  Future<String?> readUserId() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_key);
  }

  @override
  Future<void> writeUserId(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    final stored = await preferences.setString(_key, userId);
    if (!stored) throw StateError('Unable to persist account deletion state.');
  }

  @override
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key);
  }
}
