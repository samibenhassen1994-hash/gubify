import 'package:cloud_firestore/cloud_firestore.dart';

class UserRepository {
  UserRepository._();

  static final UserRepository instance = UserRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, Map<String, dynamic>> _userCache = {};
  final Set<String> _missingUsers = {};
  final UserExistenceStreamCache _existenceStreamCache =
      UserExistenceStreamCache();
  final UserIdentityStreamCache _identityStreamCache =
      UserIdentityStreamCache();

  Future<Map<String, dynamic>?> getUser(String uid) async {
    if (_userCache.containsKey(uid)) {
      return _userCache[uid];
    }
    if (_missingUsers.contains(uid)) return null;

    final doc = await _firestore.collection("users").doc(uid).get();

    if (!doc.exists) {
      _missingUsers.add(uid);
      return null;
    }

    final data = doc.data();

    if (data != null) {
      _userCache[uid] = data;
    }

    return data;
  }

  Stream<bool> userExistsStream(String uid) {
    return _existenceStreamCache.forUser(
      uid,
      () => _firestore
          .collection('users')
          .doc(uid)
          .snapshots()
          .map((snapshot) {
            final data = snapshot.data();
            if (data == null) {
              _userCache.remove(uid);
              _markUserMissing(uid);
              return false;
            }
            _missingUsers.remove(uid);
            _userCache[uid] = data;
            return true;
          })
          .distinct()
          .asBroadcastStream(),
    );
  }

  Stream<UserIdentity> userIdentityStream(String uid) {
    return _identityStreamCache.forUser(
      uid,
      () => _firestore
          .collection('users')
          .doc(uid)
          .snapshots()
          .map((snapshot) {
            final data = snapshot.data();
            if (data == null) {
              _userCache.remove(uid);
              _markUserMissing(uid);
              return const UserIdentity.missing();
            }

            _missingUsers.remove(uid);
            _userCache[uid] = data;
            return UserIdentity.existing(_nonEmptyString(data['displayName']));
          })
          .distinct()
          .asBroadcastStream(),
    );
  }

  void updateUser(String uid, Map<String, dynamic> data) {
    _missingUsers.remove(uid);
    _userCache[uid] = data;
  }

  void invalidateUser(String uid) {
    _userCache.remove(uid);
    _missingUsers.remove(uid);
  }

  void _markUserMissing(String uid) {
    _userCache.remove(uid);
    _missingUsers.add(uid);
  }

  void clearCache() {
    _userCache.clear();
    _missingUsers.clear();
    _existenceStreamCache.clear();
    _identityStreamCache.clear();
  }

  String? _nonEmptyString(Object? value) {
    if (value is! String) return null;
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}

class UserIdentity {
  final bool exists;
  final String? displayName;

  const UserIdentity._({required this.exists, this.displayName});

  const UserIdentity.missing() : this._(exists: false);

  const UserIdentity.existing(String? displayName)
    : this._(exists: true, displayName: displayName);

  @override
  bool operator ==(Object other) =>
      other is UserIdentity &&
      exists == other.exists &&
      displayName == other.displayName;

  @override
  int get hashCode => Object.hash(exists, displayName);
}

class UserExistenceStreamCache {
  final Map<String, Stream<bool>> _streams = {};

  Stream<bool> forUser(String userId, Stream<bool> Function() create) {
    return _streams.putIfAbsent(userId, create);
  }

  void clear() => _streams.clear();
}

class UserIdentityStreamCache {
  final Map<String, Stream<UserIdentity>> _streams = {};

  Stream<UserIdentity> forUser(
    String userId,
    Stream<UserIdentity> Function() create,
  ) {
    return _streams.putIfAbsent(userId, create);
  }

  void clear() => _streams.clear();
}
