import 'package:cloud_firestore/cloud_firestore.dart';

class UserRepository {
  UserRepository._();

  static final UserRepository instance = UserRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, Map<String, dynamic>> _userCache = {};

  Future<Map<String, dynamic>?> getUser(String uid) async {
    if (_userCache.containsKey(uid)) {
      print("📦 User preso dalla cache");
      return _userCache[uid];
    }

    print("☁️ User scaricato da Firestore");

    final doc = await _firestore.collection("users").doc(uid).get();

    if (!doc.exists) return null;

    final data = doc.data();

    if (data != null) {
      _userCache[uid] = data;
    }

    return data;
  }

  void updateUser(String uid, Map<String, dynamic> data) {
    _userCache[uid] = data;
  }

  void removeUser(String uid) {
    _userCache.remove(uid);
  }

  void clearCache() {
    _userCache.clear();
  }
}
