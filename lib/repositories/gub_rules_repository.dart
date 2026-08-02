import 'package:cloud_firestore/cloud_firestore.dart';
import 'gub_repository.dart';

class GubRulesRepository {
  GubRulesRepository._();

  static final GubRulesRepository instance = GubRulesRepository._();

  static const int currentVersion = 1;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _memberReference({
    required String gubId,
    required String userId,
  }) {
    return _firestore
        .collection('gubs')
        .doc(gubId)
        .collection('members')
        .doc(userId);
  }

  Future<bool> hasAccepted({
    required String gubId,
    required String userId,
  }) async {
    final member = await _memberReference(gubId: gubId, userId: userId).get();
    if (!member.exists) {
      throw StateError('You are no longer a member of this Gub.');
    }

    final data = member.data();
    return data?['antiSpamRulesAccepted'] == true &&
        data?['antiSpamRulesVersion'] == currentVersion;
  }

  Future<void> accept({required String gubId, required String userId}) async {
    await GubRepository.instance.ensureActive(gubId);
    final memberReference = _memberReference(gubId: gubId, userId: userId);
    await _firestore.runTransaction((transaction) async {
      final member = await transaction.get(memberReference);
      if (!member.exists) {
        throw StateError('You are no longer a member of this Gub.');
      }
      transaction.update(memberReference, {
        'antiSpamRulesAccepted': true,
        'antiSpamRulesAcceptedAt': FieldValue.serverTimestamp(),
        'antiSpamRulesVersion': currentVersion,
      });
    });
  }
}
