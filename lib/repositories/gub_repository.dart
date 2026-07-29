import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

class GubRepository {
  GubRepository._();

  static final GubRepository instance = GubRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Cache in memoria degli Hub
  final Map<String, Map<String, dynamic>> _hubCache = {};
  final Set<String> _roleBackfillAttempts = {};

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
    final userGubs = _firestore
        .collection("users")
        .doc(userId)
        .collection("gubs");
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subscription;
    late final StreamController<List<Map<String, dynamic>>> controller;
    var generation = 0;
    var cancelled = false;

    controller = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        subscription = userGubs.snapshots().listen(
          (snapshot) {
            if (cancelled || controller.isClosed) return;
            final snapshotGeneration = ++generation;
            final copies = _userGubCopies(snapshot);
            controller.add(_immediateUserGubs(copies, userId));
            if (copies.isEmpty) return;

            unawaited(
              _enrichUserGubs(copies, userId)
                  .then((enrichment) {
                    if (cancelled ||
                        controller.isClosed ||
                        snapshotGeneration != generation) {
                      return;
                    }
                    controller.add(enrichment.items);
                    for (final entry in enrichment.roleBackfills.entries) {
                      unawaited(
                        _backfillUserGubRole(
                          userId: userId,
                          gubId: entry.key,
                          role: entry.value,
                        ),
                      );
                    }
                  })
                  .catchError((Object _) {
                    // Secondary enrichment must not replace already visible data.
                  }),
            );
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!cancelled && !controller.isClosed) {
              controller.addError(error, stackTrace);
            }
          },
          onDone: () {
            if (!controller.isClosed) {
              unawaited(controller.close());
            }
          },
        );
      },
      onCancel: () async {
        cancelled = true;
        generation++;
        await subscription?.cancel();
        if (!controller.isClosed) {
          unawaited(controller.close());
        }
      },
    );

    return controller.stream;
  }

  Map<String, Map<String, dynamic>> _userGubCopies(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final copies = <String, Map<String, dynamic>>{};
    for (final document in snapshot.docs) {
      final data = document.data();
      final storedId = _nonEmptyString(data["gubId"]);
      final gubId = storedId ?? document.id;
      if (gubId.isNotEmpty) copies[gubId] = data;
    }
    return copies;
  }

  List<Map<String, dynamic>> _immediateUserGubs(
    Map<String, Map<String, dynamic>> copies,
    String userId,
  ) {
    final items = [
      for (final entry in copies.entries)
        _userGubItem(
          gubId: entry.key,
          userGub: entry.value,
          gub: const <String, dynamic>{},
          member: const <String, dynamic>{},
          userId: userId,
        ),
    ];
    _sortUserGubs(items);
    return items;
  }

  Future<
    ({List<Map<String, dynamic>> items, Map<String, String> roleBackfills})
  >
  _enrichUserGubs(
    Map<String, Map<String, dynamic>> copies,
    String userId,
  ) async {
    final ids = copies.keys.toList(growable: false);
    final queryFutures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];
    for (var start = 0; start < ids.length; start += 30) {
      final end = (start + 30).clamp(0, ids.length);
      queryFutures.add(
        _firestore
            .collection("gubs")
            .where(FieldPath.documentId, whereIn: ids.sublist(start, end))
            .get(),
      );
    }
    final querySnapshots = await Future.wait(queryFutures);
    final documents = [for (final snapshot in querySnapshots) ...snapshot.docs];

    final memberEntries = await Future.wait(
      documents.map((document) async {
        final userGub = copies[document.id]!;
        final isFounder = document.data()["ownerId"] == userId;
        if (isFounder || _nonEmptyString(userGub["role"]) != null) {
          return MapEntry(document.id, const <String, dynamic>{});
        }
        final member = await document.reference
            .collection("members")
            .doc(userId)
            .get();
        return MapEntry(
          document.id,
          member.data() ?? const <String, dynamic>{},
        );
      }),
    );
    final membersById = Map.fromEntries(memberEntries);
    final roleBackfills = <String, String>{};
    final items = <Map<String, dynamic>>[];

    for (final document in documents) {
      final userGub = copies[document.id]!;
      final gub = document.data();
      final member = membersById[document.id]!;
      final item = _userGubItem(
        gubId: document.id,
        userGub: userGub,
        gub: gub,
        member: member,
        userId: userId,
      );
      items.add(item);
      if (_nonEmptyString(userGub["role"]) == null) {
        final authoritativeRole = gub["ownerId"] == userId
            ? "owner"
            : _nonEmptyString(member["role"]);
        if (authoritativeRole != null) {
          roleBackfills[document.id] = authoritativeRole;
        }
      }
    }
    _sortUserGubs(items);
    return (items: items, roleBackfills: roleBackfills);
  }

  Map<String, dynamic> _userGubItem({
    required String gubId,
    required Map<String, dynamic> userGub,
    required Map<String, dynamic> gub,
    required Map<String, dynamic> member,
    required String userId,
  }) {
    final ownerId =
        _nonEmptyString(gub["ownerId"]) ?? _nonEmptyString(userGub["ownerId"]);
    final isFounder = ownerId == userId;
    final role =
        _nonEmptyString(userGub["role"]) ??
        (isFounder ? "owner" : _nonEmptyString(member["role"]) ?? "member");
    final joinedAt =
        _timestampValue(userGub["joinedAt"]) ??
        _timestampValue(member["joinedAt"]) ??
        (isFounder ? _timestampValue(gub["createdAt"]) : null);

    return {
      ...userGub,
      ...gub,
      "gubId": gubId,
      "role": role,
      "joinedAt": joinedAt,
      "joinedAtDate": joinedAt?.toDate(),
      "isFounder": isFounder,
    };
  }

  void _sortUserGubs(List<Map<String, dynamic>> items) {
    items.sort((first, second) {
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
  }

  Future<void> _backfillUserGubRole({
    required String userId,
    required String gubId,
    required String role,
  }) async {
    final attemptKey = "$userId/$gubId";
    if (!_roleBackfillAttempts.add(attemptKey)) return;
    try {
      await _firestore
          .collection("users")
          .doc(userId)
          .collection("gubs")
          .doc(gubId)
          .set({"role": role}, SetOptions(merge: true));
    } catch (_) {
      // The authoritative membership remains the fallback if writes are denied.
    }
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

  String? _nonEmptyString(Object? value) {
    if (value is! String) return null;
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
