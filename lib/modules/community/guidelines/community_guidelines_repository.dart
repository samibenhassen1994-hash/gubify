import 'package:cloud_firestore/cloud_firestore.dart';

typedef CommunityGuidelinesMemberLoader =
    Future<Map<String, dynamic>?> Function({
      required String communityId,
      required String userId,
    });
typedef CommunityGuidelinesAcceptanceWriter =
    Future<void> Function({
      required String communityId,
      required String userId,
      required Map<String, Object?> data,
    });

class CommunityGuidelinesRepository {
  CommunityGuidelinesRepository._([
    this._firestore,
    this._loadMember,
    this._writeAcceptance,
  ]);

  factory CommunityGuidelinesRepository.forTesting({
    required CommunityGuidelinesMemberLoader loadMember,
    required CommunityGuidelinesAcceptanceWriter writeAcceptance,
  }) => CommunityGuidelinesRepository._(null, loadMember, writeAcceptance);

  static final CommunityGuidelinesRepository instance =
      CommunityGuidelinesRepository._(FirebaseFirestore.instance);

  /// Version 1 corresponds to Community Guidelines 2026-09-09.2.
  static const int currentVersion = 1;

  final FirebaseFirestore? _firestore;
  final CommunityGuidelinesMemberLoader? _loadMember;
  final CommunityGuidelinesAcceptanceWriter? _writeAcceptance;

  DocumentReference<Map<String, dynamic>> _memberReference({
    required String communityId,
    required String userId,
  }) => _firestore!
      .collection('communities')
      .doc(communityId)
      .collection('members')
      .doc(userId);

  Future<Map<String, dynamic>?> _loadMemberData({
    required String communityId,
    required String userId,
  }) async {
    final loadMember = _loadMember;
    if (loadMember != null) {
      return loadMember(communityId: communityId, userId: userId);
    }
    final snapshot = await _memberReference(
      communityId: communityId,
      userId: userId,
    ).get();
    return snapshot.data();
  }

  Future<bool> hasAccepted({
    required String communityId,
    required String userId,
  }) async {
    final data = await _loadMemberData(
      communityId: communityId,
      userId: userId,
    );
    return data?['antiSpamRulesAccepted'] == true &&
        data?['antiSpamRulesVersion'] == currentVersion;
  }

  Future<void> accept({
    required String communityId,
    required String userId,
  }) async {
    final data = <String, Object?>{
      'antiSpamRulesAccepted': true,
      'antiSpamRulesAcceptedAt': FieldValue.serverTimestamp(),
      'antiSpamRulesVersion': currentVersion,
    };
    final writeAcceptance = _writeAcceptance;
    if (writeAcceptance != null) {
      final member = await _loadMemberData(
        communityId: communityId,
        userId: userId,
      );
      if (member == null) {
        throw StateError('Community member not found.');
      }
      await writeAcceptance(
        communityId: communityId,
        userId: userId,
        data: data,
      );
      return;
    }

    final memberReference = _memberReference(
      communityId: communityId,
      userId: userId,
    );
    await _firestore!.runTransaction((transaction) async {
      final member = await transaction.get(memberReference);
      if (!member.exists) {
        throw StateError('Community member not found.');
      }
      transaction.update(memberReference, data);
    });
  }
}
