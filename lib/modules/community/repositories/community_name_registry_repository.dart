import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityNameRegistryRepository {
  CommunityNameRegistryRepository._();

  static final CommunityNameRegistryRepository instance =
      CommunityNameRegistryRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> findExistingCommunityId(String nameKey) async {
    final normalizedKey = nameKey.trim();
    if (normalizedKey.isEmpty) return null;

    final snapshot = await _firestore
        .collection('communityNames')
        .doc(normalizedKey)
        .get();
    if (!snapshot.exists) return null;

    final communityId = snapshot.data()?['communityId'];
    if (communityId is String && communityId.trim().isNotEmpty) {
      return communityId.trim();
    }

    // A malformed existing registry still reserves the name. Returning an
    // empty id blocks duplicate creation while disabling "View Community".
    return '';
  }
}
