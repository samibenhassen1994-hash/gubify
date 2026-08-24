import 'package:cloud_firestore/cloud_firestore.dart';

import '../modules/community/restrictions/services/community_restriction_service.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createUser({
    required String userId,
    required String displayName,
  }) async {
    await _firestore.collection('users').doc(userId).set({
      'displayName': displayName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'activeHub': null,
      'avatar': null,
    });

    try {
      await CommunityRestrictionService.instance.initializePlatformRestriction(
        userId,
      );
    } on Object {
      // Restriction initialization is best-effort and must not block profile
      // creation for an otherwise valid authenticated account.
    }
  }

  Future<bool> userExists(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();

    return doc.exists;
  }

  Future<String> getDisplayName(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();

    if (!doc.exists) {
      return "User";
    }

    final data = doc.data();

    return data?["displayName"] ?? "User";
  }
}
