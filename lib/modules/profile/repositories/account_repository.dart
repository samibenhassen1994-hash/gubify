import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../repositories/user_repository.dart';
import '../models/account_details_model.dart';

abstract interface class AccountProfileRepository {
  Future<AccountDetailsModel?> load(String userId);

  Future<void> synchronizeCurrentDisplayName({
    required String userId,
    required String displayName,
  });

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
    final memberships = await _staleMembershipReferences(userId, displayName);
    const batchLimit = 450;
    final firstBatch = _firestore.batch();
    firstBatch.update(_firestore.collection('users').doc(userId), {
      'displayName': displayName,
      'displayNameChangedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (final reference in memberships.take(batchLimit - 1)) {
      firstBatch.update(reference, {'displayName': displayName});
    }
    await firstBatch.commit();
    UserRepository.instance.invalidateUser(userId);

    await _updateMemberships(
      memberships.skip(batchLimit - 1).toList(growable: false),
      displayName,
    );
  }

  @override
  Future<void> synchronizeCurrentDisplayName({
    required String userId,
    required String displayName,
  }) async {
    final memberships = await _staleMembershipReferences(userId, displayName);
    await _updateMemberships(memberships, displayName);
  }

  Future<List<DocumentReference<Map<String, dynamic>>>>
  _staleMembershipReferences(String userId, String displayName) async {
    final user = _firestore.collection('users').doc(userId);
    final copies = await Future.wait([
      user.collection('gubs').get(const GetOptions(source: Source.server)),
      user
          .collection('communities')
          .get(const GetOptions(source: Source.server)),
    ]);
    final candidates = <DocumentReference<Map<String, dynamic>>>[
      for (final copy in copies[0].docs)
        _firestore
            .collection('gubs')
            .doc(copy.id)
            .collection('members')
            .doc(userId),
      for (final copy in copies[1].docs)
        _firestore
            .collection('communities')
            .doc(copy.id)
            .collection('members')
            .doc(userId),
    ];
    final snapshots = await Future.wait(
      candidates.map(
        (reference) => reference.get(const GetOptions(source: Source.server)),
      ),
    );
    return [
      for (var index = 0; index < candidates.length; index++)
        if (snapshots[index].exists &&
            snapshots[index].data()?['displayName'] != displayName)
          candidates[index],
    ];
  }

  Future<void> _updateMemberships(
    List<DocumentReference<Map<String, dynamic>>> memberships,
    String displayName,
  ) async {
    const batchLimit = 450;
    for (var offset = 0; offset < memberships.length; offset += batchLimit) {
      final batch = _firestore.batch();
      final end = (offset + batchLimit).clamp(0, memberships.length);
      for (final reference in memberships.sublist(offset, end)) {
        batch.update(reference, {'displayName': displayName});
      }
      await batch.commit();
    }
  }
}
