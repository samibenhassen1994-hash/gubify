import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityUserProgressRepository {
  CommunityUserProgressRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static final instance = CommunityUserProgressRepository();
  static const queryBatchSize = 30;

  final FirebaseFirestore _firestore;

  /// Watches only the current linked user's progress document.
  ///
  /// A missing document deliberately represents a new user with zero XP.
  Stream<int> watchUserXp(String userId) {
    final id = userId.trim();
    if (id.isEmpty) return Stream<int>.value(0);
    return _firestore
        .collection('communityUserProgress')
        .doc(id)
        .snapshots()
        .map((snapshot) => (snapshot.data()?['xp'] as num?)?.toInt() ?? 0);
  }

  Future<Map<String, int>> loadXp(Set<String> userIds) async {
    final ids = userIds.where((id) => id.trim().isNotEmpty).toList();
    final result = <String, int>{};
    for (var offset = 0; offset < ids.length; offset += queryBatchSize) {
      final end = (offset + queryBatchSize).clamp(0, ids.length);
      final snapshot = await _firestore
          .collection('communityUserProgress')
          .where(FieldPath.documentId, whereIn: ids.sublist(offset, end))
          .get();
      for (final document in snapshot.docs) {
        result[document.id] = (document.data()['xp'] as num?)?.toInt() ?? 0;
      }
    }
    return result;
  }
}
