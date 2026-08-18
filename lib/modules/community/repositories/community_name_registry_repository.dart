import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityNameRegistryRepository {
  CommunityNameRegistryRepository._();

  static final CommunityNameRegistryRepository instance =
      CommunityNameRegistryRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> findExistingCommunityId(String nameKey) async {
    return findExistingCommunityIdForKeys([nameKey]);
  }

  Future<String?> findExistingCommunityIdForKeys(Iterable<String> nameKeys) async {
    final seen = <String>{};
    for (final key in nameKeys) {
      final normalizedKey = key.trim();
      if (normalizedKey.isEmpty || !seen.add(normalizedKey)) continue;

      final snapshot = await _firestore
          .collection('communityNames')
          .doc(normalizedKey)
          .get();
      if (!snapshot.exists) continue;

      final communityId = snapshot.data()?['communityId'];
      if (communityId is String && communityId.trim().isNotEmpty) {
        return communityId.trim();
      }

      // A malformed existing registry still reserves the name. Returning an
      // empty id blocks duplicate creation while disabling "View Community".
      return '';
    }
    return null;
  }
}
