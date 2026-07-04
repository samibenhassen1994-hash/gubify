import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createUser({
    required String userId,
    required String displayName,
  }) async {
    await _firestore.collection('users').doc(userId).set({
      'displayName': displayName,
      'createdAt': FieldValue.serverTimestamp(),
      'activeHub': null,
      'avatar': null,
    });
  }

  Future<bool> userExists(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();

    return doc.exists;
  }
}