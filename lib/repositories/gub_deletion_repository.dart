import 'package:cloud_firestore/cloud_firestore.dart';

class GubDeletionTarget {
  final String name;
  final String ownerId;

  const GubDeletionTarget({required this.name, required this.ownerId});
}

enum GubDeletionPhase {
  preparing,
  nestedCollections,
  directCollections,
  userCopies,
  finalizing,
}

class GubDeletionRepository {
  GubDeletionRepository._();

  static final GubDeletionRepository instance = GubDeletionRepository._();

  static const _pageSize = 300;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _gub(String gubId) =>
      _firestore.collection('gubs').doc(gubId);

  Future<GubDeletionTarget?> getTarget(String gubId) async {
    final snapshot = await _gub(
      gubId,
    ).get(const GetOptions(source: Source.server));
    if (!snapshot.exists) return null;

    final data = snapshot.data()!;
    return GubDeletionTarget(
      name: data['name'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
    );
  }

  Future<void> deleteGubCompletely({
    required String gubId,
    required String ownerId,
    required String? confirmedName,
    required void Function(GubDeletionPhase) onPhase,
  }) async {
    final gubReference = _gub(gubId);
    final data = await _beginOrResume(
      gubReference: gubReference,
      ownerId: ownerId,
      confirmedName: confirmedName,
    );

    onPhase(GubDeletionPhase.preparing);
    final memberIds = await _captureMemberIds(
      gubReference: gubReference,
      ownerId: ownerId,
      existingData: data,
    );
    await _completePhase(gubReference, ownerId, GubDeletionPhase.preparing);

    final phase = _phaseFrom(data['deletionPhase']);
    if (phase.index <= GubDeletionPhase.nestedCollections.index) {
      onPhase(GubDeletionPhase.nestedCollections);
      await _deleteParentsWithChildren(
        parents: gubReference.collection('proposals'),
        childCollection: 'votes',
      );
      await _deleteParentsWithChildren(
        parents: gubReference.collection('goals'),
        childCollection: 'members',
      );
      await _completePhase(
        gubReference,
        ownerId,
        GubDeletionPhase.nestedCollections,
      );
    }

    if (phase.index <= GubDeletionPhase.directCollections.index) {
      onPhase(GubDeletionPhase.directCollections);
      for (final collection in const [
        'messages',
        'chatReads',
        'boardReads',
        'posts',
        'tasks',
        'events',
        'organizedEvents',
        'notifications',
        'creationCooldowns',
        'members',
      ]) {
        await _deleteCollection(gubReference.collection(collection));
      }
      await _completePhase(
        gubReference,
        ownerId,
        GubDeletionPhase.directCollections,
      );
    }

    if (phase.index <= GubDeletionPhase.userCopies.index) {
      onPhase(GubDeletionPhase.userCopies);
      await _deleteUserCopies(gubId: gubId, memberIds: memberIds);
      await _completePhase(gubReference, ownerId, GubDeletionPhase.userCopies);
    }

    onPhase(GubDeletionPhase.finalizing);
    await _completePhase(gubReference, ownerId, GubDeletionPhase.finalizing);
    await gubReference.delete();
  }

  Future<Map<String, dynamic>> _beginOrResume({
    required DocumentReference<Map<String, dynamic>> gubReference,
    required String ownerId,
    required String? confirmedName,
  }) {
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(gubReference);
      if (!snapshot.exists) {
        throw StateError('This Gub is no longer available.');
      }
      final data = snapshot.data()!;
      if (data['ownerId'] != ownerId) {
        throw StateError('Only the Gub owner can delete this Gub.');
      }
      final deleting = data['deletionStatus'] == 'deleting';
      if (!deleting && confirmedName != data['name']) {
        throw StateError(
          'The Gub name has changed. Reopen Manage Gub and try again.',
        );
      }
      if (!deleting) {
        transaction.update(gubReference, {
          'deletionStatus': 'deleting',
          'deletionRequestedBy': ownerId,
          'deletionStartedAt': FieldValue.serverTimestamp(),
          'deletionUpdatedAt': FieldValue.serverTimestamp(),
          'deletionPhase': GubDeletionPhase.preparing.name,
        });
        return {
          ...data,
          'deletionStatus': 'deleting',
          'deletionPhase': GubDeletionPhase.preparing.name,
        };
      }
      if (data['deletionRequestedBy'] != ownerId) {
        throw StateError(
          'Only the owner who started this deletion can resume it.',
        );
      }
      transaction.update(gubReference, {
        'deletionUpdatedAt': FieldValue.serverTimestamp(),
      });
      return data;
    });
  }

  Future<void> _completePhase(
    DocumentReference<Map<String, dynamic>> reference,
    String ownerId,
    GubDeletionPhase phase,
  ) {
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) return;
      final data = snapshot.data()!;
      if (data['ownerId'] != ownerId || data['deletionStatus'] != 'deleting') {
        throw StateError('This Gub deletion can no longer continue.');
      }
      transaction.update(reference, {
        'deletionPhase': phase.name,
        'deletionUpdatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  GubDeletionPhase _phaseFrom(Object? value) => switch (value) {
    'nestedCollections' => GubDeletionPhase.nestedCollections,
    'directCollections' => GubDeletionPhase.directCollections,
    'userCopies' => GubDeletionPhase.userCopies,
    'finalizing' => GubDeletionPhase.finalizing,
    _ => GubDeletionPhase.preparing,
  };

  Future<Set<String>> _captureMemberIds({
    required DocumentReference<Map<String, dynamic>> gubReference,
    required String ownerId,
    required Map<String, dynamic> existingData,
  }) async {
    final memberIds = <String>{
      ownerId,
      ..._storedMemberIds(existingData['deletionMemberIds']),
    };
    DocumentSnapshot<Map<String, dynamic>>? cursor;

    while (true) {
      Query<Map<String, dynamic>> query = gubReference
          .collection('members')
          .orderBy(FieldPath.documentId)
          .limit(_pageSize);
      if (cursor != null) query = query.startAfterDocument(cursor);

      final page = await query.get();
      if (page.docs.isEmpty) break;
      memberIds.addAll(page.docs.map((document) => document.id));
      cursor = page.docs.last;
    }

    final sortedMemberIds = memberIds.toList()..sort();
    await gubReference.update({'deletionMemberIds': sortedMemberIds});
    return memberIds;
  }

  Iterable<String> _storedMemberIds(Object? value) sync* {
    if (value is! Iterable<Object?>) return;
    for (final item in value) {
      if (item is String && item.isNotEmpty) yield item;
    }
  }

  Future<void> _deleteParentsWithChildren({
    required CollectionReference<Map<String, dynamic>> parents,
    required String childCollection,
  }) async {
    while (true) {
      final page = await parents
          .orderBy(FieldPath.documentId)
          .limit(_pageSize)
          .get();
      if (page.docs.isEmpty) return;

      for (final parent in page.docs) {
        await _deleteCollection(parent.reference.collection(childCollection));
      }

      await _deleteReferences(page.docs.map((document) => document.reference));
    }
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final page = await collection
          .orderBy(FieldPath.documentId)
          .limit(_pageSize)
          .get();
      if (page.docs.isEmpty) return;
      await _deleteReferences(page.docs.map((document) => document.reference));
    }
  }

  Future<void> _deleteUserCopies({
    required String gubId,
    required Set<String> memberIds,
  }) async {
    final references = memberIds.map(
      (uid) =>
          _firestore.collection('users').doc(uid).collection('gubs').doc(gubId),
    );
    await _deleteReferences(references);
  }

  Future<void> _deleteReferences(
    Iterable<DocumentReference<Map<String, dynamic>>> references,
  ) async {
    var batch = _firestore.batch();
    var writeCount = 0;

    for (final reference in references) {
      batch.delete(reference);
      writeCount++;
      if (writeCount == _pageSize) {
        await batch.commit();
        batch = _firestore.batch();
        writeCount = 0;
      }
    }

    if (writeCount > 0) await batch.commit();
  }
}
