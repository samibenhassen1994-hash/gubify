import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String _userIdKey = 'userId';
  static const String _displayNameKey = 'displayName';

  Future<void> saveUser({
    required String userId,
    required String displayName,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_displayNameKey, displayName);
      print("Saved userId: ${prefs.getString(_userIdKey)}");
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  Future<String?> getDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_displayNameKey);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_displayNameKey);
  }
  
}
