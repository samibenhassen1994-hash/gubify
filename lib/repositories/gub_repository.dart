import 'package:cloud_firestore/cloud_firestore.dart';

class GubRepository {
  GubRepository._();

  static final GubRepository instance = GubRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Cache in memoria degli Hub
  final Map<String, Map<String, dynamic>> _hubCache = {};

  /// Restituisce i dati dell'Hub.
  /// Se sono già in memoria, non interroga Firestore.
  Future<Map<String, dynamic>?> getHub(String gubId) async {
    // Cache
    if (_hubCache.containsKey(gubId)) {
      return _hubCache[gubId];
    }

    final doc = await _firestore.collection("gubs").doc(gubId).get();

    if (!doc.exists) return null;

    final data = doc.data();

    if (data != null) {
      _hubCache[gubId] = data;
    }

    return data;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> hubStream(String gubId) {
    return _firestore.collection("gubs").doc(gubId).snapshots();
  }

  Stream<List<Map<String, dynamic>>> userGubsStream(String userId) {
    return _firestore
        .collection("users")
        .doc(userId)
        .collection("gubs")
        .snapshots()
        .asyncMap((userGubsSnapshot) async {
          if (userGubsSnapshot.docs.isEmpty) {
            return const <Map<String, dynamic>>[];
          }

          final userGubById = <String, Map<String, dynamic>>{};
          for (final document in userGubsSnapshot.docs) {
            final data = document.data();
            final storedId = data["gubId"];
            final gubId = storedId is String && storedId.trim().isNotEmpty
                ? storedId.trim()
                : document.id;
            if (gubId.isNotEmpty) userGubById[gubId] = data;
          }

          final gubIds = userGubById.keys.toList(growable: false);
          if (gubIds.isEmpty) return const <Map<String, dynamic>>[];

          final existingGubs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          for (var start = 0; start < gubIds.length; start += 30) {
            final end = (start + 30).clamp(0, gubIds.length);
            final snapshot = await _firestore
                .collection("gubs")
                .where(
                  FieldPath.documentId,
                  whereIn: gubIds.sublist(start, end),
                )
                .get();
            existingGubs.addAll(snapshot.docs);
          }

          final memberDetails = await Future.wait(
            existingGubs.map((gubDocument) async {
              final userGub = userGubById[gubDocument.id]!;
              final gub = gubDocument.data();
              final isFounder = gub["ownerId"] == userId;
              final storedRole = userGub["role"];
              final hasStoredRole =
                  storedRole is String && storedRole.trim().isNotEmpty;
              final needsMemberDocument =
                  !isFounder &&
                  (!hasStoredRole || userGub["joinedAt"] is! Timestamp);
              if (!needsMemberDocument) {
                return MapEntry(gubDocument.id, const <String, dynamic>{});
              }
              final member = await gubDocument.reference
                  .collection("members")
                  .doc(userId)
                  .get();
              return MapEntry(
                gubDocument.id,
                member.data() ?? const <String, dynamic>{},
              );
            }),
          );
          final memberDetailsById = Map.fromEntries(memberDetails);

          final results = <Map<String, dynamic>>[];
          for (final gubDocument in existingGubs) {
            final userGub = userGubById[gubDocument.id]!;
            final gub = gubDocument.data();
            final member = memberDetailsById[gubDocument.id]!;
            final isFounder = gub["ownerId"] == userId;
            final storedRole = userGub["role"];
            final role = storedRole is String && storedRole.trim().isNotEmpty
                ? storedRole.trim()
                : isFounder
                ? "owner"
                : member["role"] is String &&
                      (member["role"] as String).trim().isNotEmpty
                ? (member["role"] as String).trim()
                : "member";
            final joinedAt =
                _timestampValue(userGub["joinedAt"]) ??
                _timestampValue(member["joinedAt"]) ??
                (isFounder ? _timestampValue(gub["createdAt"]) : null);

            results.add({
              ...userGub,
              ...gub,
              "gubId": gubDocument.id,
              "role": role,
              "joinedAt": joinedAt,
              "joinedAtDate": joinedAt?.toDate(),
              "isFounder": isFounder,
            });
          }
          results.sort((first, second) {
            final firstJoinedAt = first["joinedAt"];
            final secondJoinedAt = second["joinedAt"];
            final firstMillis = firstJoinedAt is Timestamp
                ? firstJoinedAt.millisecondsSinceEpoch
                : 0;
            final secondMillis = secondJoinedAt is Timestamp
                ? secondJoinedAt.millisecondsSinceEpoch
                : 0;
            return secondMillis.compareTo(firstMillis);
          });
          return results;
        });
  }

  Future<bool> isMember({required String gubId, required String userId}) async {
    final member = await _firestore
        .collection("gubs")
        .doc(gubId)
        .collection("members")
        .doc(userId)
        .get();
    return member.exists;
  }

  Future<void> removeUserGubReference({
    required String gubId,
    required String userId,
  }) {
    return _firestore
        .collection("users")
        .doc(userId)
        .collection("gubs")
        .doc(gubId)
        .delete();
  }

  /// Aggiorna la cache dopo una modifica
  void updateHub(String gubId, Map<String, dynamic> data) {
    _hubCache[gubId] = data;
  }

  /// Elimina un Hub dalla cache
  void removeHub(String gubId) {
    _hubCache.remove(gubId);
  }

  /// Svuota completamente la cache
  void clearCache() {
    _hubCache.clear();
  }

  Timestamp? _timestampValue(Object? value) {
    return value is Timestamp ? value : null;
  }
}
