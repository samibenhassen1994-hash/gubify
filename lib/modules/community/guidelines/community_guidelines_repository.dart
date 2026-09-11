import 'package:cloud_firestore/cloud_firestore.dart';

typedef CommunityGuidelinesAcceptanceLoader =
    Future<Map<String, dynamic>?> Function({required String userId});
typedef CommunityGuidelinesAcceptanceWriter =
    Future<void> Function({
      required String userId,
      required Map<String, Object?> data,
    });

class CommunityGuidelinesRepository {
  CommunityGuidelinesRepository._([
    this._firestore,
    this._loadAcceptance,
    this._writeAcceptance,
  ]);

  factory CommunityGuidelinesRepository.forTesting({
    required CommunityGuidelinesAcceptanceLoader loadAcceptance,
    required CommunityGuidelinesAcceptanceWriter writeAcceptance,
  }) => CommunityGuidelinesRepository._(null, loadAcceptance, writeAcceptance);

  static final CommunityGuidelinesRepository instance =
      CommunityGuidelinesRepository._(FirebaseFirestore.instance);

  /// Version 1 corresponds to Community Guidelines 2026-09-09.2.
  static const int currentVersion = 1;

  final FirebaseFirestore? _firestore;
  final CommunityGuidelinesAcceptanceLoader? _loadAcceptance;
  final CommunityGuidelinesAcceptanceWriter? _writeAcceptance;

  DocumentReference<Map<String, dynamic>> _acceptanceReference(String userId) =>
      _firestore!.collection('communityGuidelinesAcceptances').doc(userId);

  Future<bool> hasAccepted({required String userId}) async {
    final loader = _loadAcceptance;
    final data = loader != null
        ? await loader(userId: userId)
        : (await _acceptanceReference(userId).get()).data();
    return data?['accepted'] == true && data?['version'] == currentVersion;
  }

  Future<void> accept({required String userId}) async {
    final data = <String, Object?>{
      'accepted': true,
      'acceptedAt': FieldValue.serverTimestamp(),
      'version': currentVersion,
    };
    final writer = _writeAcceptance;
    if (writer != null) {
      await writer(userId: userId, data: data);
      return;
    }
    await _acceptanceReference(userId).set(data);
  }
}
