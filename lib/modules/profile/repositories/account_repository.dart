import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../repositories/user_repository.dart';
import '../models/account_details_model.dart';

abstract interface class AccountProfileRepository {
  Future<AccountDetailsModel?> load(String userId);

  Future<void> changeDisplayName({
    required String userId,
    required String displayName,
  });
}

class AccountRepository implements AccountProfileRepository {
  AccountRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<AccountDetailsModel?> load(String userId) async {
    final snapshot = await _firestore.collection('users').doc(userId).get();
    final data = snapshot.data();
    return data == null ? null : AccountDetailsModel.fromFirestore(data);
  }

  @override
  Future<void> changeDisplayName({
    required String userId,
    required String displayName,
  }) async {
    await _firestore.collection('users').doc(userId).update({
      'displayName': displayName,
      'displayNameChangedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    UserRepository.instance.removeUser(userId);
  }
}
