import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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
  static const _memberCleanupPageSize = 200;

  static const Map<String, List<String>> nestedCollectionsForDeletion = {
    'proposals': ['votes'],
    'goals': ['members'],
    'posts': ['comments', 'likes'],
  };

  static const List<String> directCollectionsForDeletion = [
    'messages',
    'chatReads',
    'boardReads',
    'tasks',
    'events',
    'organizedEvents',
    'notifications',
    'creationCooldowns',
    'bans',
  ];

  @visibleForTesting
  static Future<void> drainMemberCleanupForTesting({
    required Future<List<String>> Function(int limit) loadPage,
    required Future<void> Function(List<String> uids) deletePage,
    required Future<void> Function() deleteOwnerCopy,
    required Future<void> Function() onDrained,
  }) async {
    while (true) {
      final page = await loadPage(_memberCleanupPageSize);
      if (page.isEmpty) break;
      await deletePage(page);
    }
    await deleteOwnerCopy();
    await onDrained();
  }

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
    await _completePhase(gubReference, ownerId, GubDeletionPhase.preparing);

    final phase = _phaseFrom(data['deletionPhase']);
    if (phase.index <= GubDeletionPhase.nestedCollections.index) {
      onPhase(GubDeletionPhase.nestedCollections);
      for (final entry in nestedCollectionsForDeletion.entries) {
        await _deleteParentsWithChildren(
          parents: gubReference.collection(entry.key),
          childCollections: entry.value,
        );
      }
      await _completePhase(
        gubReference,
        ownerId,
        GubDeletionPhase.nestedCollections,
      );
    }

    if (phase.index <= GubDeletionPhase.directCollections.index) {
      onPhase(GubDeletionPhase.directCollections);
      for (final collection in directCollectionsForDeletion) {
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
      await _deleteMemberCopies(
        gubReference: gubReference,
        gubId: gubId,
        ownerId: ownerId,
      );
    }

    onPhase(GubDeletionPhase.finalizing);
    await _deleteInviteTokens(gubId, ownerId);
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
      final inviteTokenId = data['inviteTokenId'] as String?;
      DocumentSnapshot<Map<String, dynamic>>? inviteToken;
      if (inviteTokenId != null && inviteTokenId.isNotEmpty) {
        inviteToken = await transaction.get(
          _firestore.collection('inviteTokens').doc(inviteTokenId),
        );
      }
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
        if (inviteToken?.exists == true) {
          _validateInviteToken(
            token: inviteToken!,
            gubId: gubReference.id,
            ownerId: ownerId,
            gubName: data['name'] as String? ?? '',
          );
          if (inviteToken.data()?['active'] == true) {
            transaction.update(inviteToken.reference, {'active': false});
          }
        }
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
      final tokenSnapshot = inviteToken;
      if (tokenSnapshot?.exists == true &&
          tokenSnapshot?.data()?['active'] == true) {
        _validateInviteToken(
          token: tokenSnapshot!,
          gubId: gubReference.id,
          ownerId: ownerId,
          gubName: data['name'] as String? ?? '',
        );
        transaction.update(tokenSnapshot.reference, {'active': false});
      }
      return data;
    });
  }

  void _validateInviteToken({
    required DocumentSnapshot<Map<String, dynamic>> token,
    required String gubId,
    required String ownerId,
    required String gubName,
  }) {
    final data = token.data();
    if (data?['gubId'] != gubId ||
        data?['ownerId'] != ownerId ||
        data?['gubName'] != gubName) {
      throw StateError('This Gub invite token is inconsistent.');
    }
  }

  Future<void> _deleteInviteTokens(String gubId, String ownerId) async {
    while (true) {
      final page = await _firestore
          .collection('inviteTokens')
          .where('gubId', isEqualTo: gubId)
          .where('ownerId', isEqualTo: ownerId)
          .limit(_pageSize)
          .get();
      if (page.docs.isEmpty) return;
      await _deleteReferences(page.docs.map((document) => document.reference));
    }
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

  Future<void> _deleteMemberCopies({
    required DocumentReference<Map<String, dynamic>> gubReference,
    required String gubId,
    required String ownerId,
  }) => drainMemberCleanupForTesting(
    loadPage: (limit) async {
      final page = await gubReference
          .collection('members')
          .orderBy(FieldPath.documentId)
          .limit(limit)
          .get();
      return page.docs.map((document) => document.id).toList(growable: false);
    },
    deletePage: (uids) async {
      final batch = _firestore.batch();
      for (final uid in uids) {
        batch
          ..delete(gubReference.collection('members').doc(uid))
          ..delete(
            _firestore
                .collection('users')
                .doc(uid)
                .collection('gubs')
                .doc(gubId),
          );
      }
      await batch.commit();
    },
    deleteOwnerCopy: () => _deleteReferences([
      _firestore.collection('users').doc(ownerId).collection('gubs').doc(gubId),
    ]),
    onDrained: () async {
      await _deleteOrphanUserCopies(gubId, ownerId);
      await _completePhase(gubReference, ownerId, GubDeletionPhase.userCopies);
    },
  );

  Future<void> _deleteOrphanUserCopies(String gubId, String ownerId) async {
    DocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      Query<Map<String, dynamic>> query = _firestore
          .collectionGroup('gubs')
          .where('gubId', isEqualTo: gubId)
          .where('ownerId', isEqualTo: ownerId)
          .orderBy(FieldPath.documentId)
          .limit(_memberCleanupPageSize);
      if (cursor != null) query = query.startAfterDocument(cursor);
      final page = await query.get();
      if (page.docs.isEmpty) return;
      final copies = page.docs.where((document) {
        final segments = document.reference.path.split('/');
        return segments.length == 4 &&
            segments[0] == 'users' &&
            segments[2] == 'gubs' &&
            segments[3] == gubId;
      });
      await _deleteReferences(copies.map((document) => document.reference));
      cursor = page.docs.last;
    }
  }

  Future<void> _deleteParentsWithChildren({
    required CollectionReference<Map<String, dynamic>> parents,
    required List<String> childCollections,
  }) async {
    while (true) {
      final page = await parents
          .orderBy(FieldPath.documentId)
          .limit(_pageSize)
          .get();
      if (page.docs.isEmpty) return;

      for (final parent in page.docs) {
        for (final childCollection in childCollections) {
          await _deleteCollection(parent.reference.collection(childCollection));
        }
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
