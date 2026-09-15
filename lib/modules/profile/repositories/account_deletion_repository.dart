import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/account_deletion_model.dart';

abstract interface class AccountDeletionRepositoryContract {
  Future<AccountDeletionPreflight> loadPreflight(String userId);
  Future<AccountDeletionMemberships> loadMemberships(String userId);
  Future<void> beginDeletionState(String userId);
  Future<void> anonymizeSharedContent({
    required String userId,
    required List<String> privateGubIds,
    required List<String> communityIds,
  });
  Future<void> deleteUserRoot(String userId);
  Future<void> deleteDetachedIdentityDocuments(String userId);
  Future<void> deletePrivateReadState(String gubId, String userId);
  Future<void> deleteCommunityJoinRequest(String communityId, String userId);
  Future<void> deleteCommunityActiveAskSlots(String userId);
  Future<void> deletePrivateCopy(String gubId, String userId);
  Future<void> deleteCommunityCopy(String communityId, String userId);
  Future<void> deleteProfile(String userId);
}

class AccountDeletionRepository implements AccountDeletionRepositoryContract {
  AccountDeletionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const deletedUserId = '__deleted_user__';
  static const deletedUserName = 'Deleted user';
  static const _deletePageSize = 300;

  @visibleForTesting
  static const profileDocumentCollections = <String>[
    'communityGuidelinesAcceptances',
    'communityUserProgress',
    'users',
  ];

  @visibleForTesting
  static const profileSubcollectionsForDeletion = <String>[
    'gubs',
    'communities',
    'blockedUsers',
  ];

  @visibleForTesting
  static const externalCollectionGroupsForDeletion = <String>['joinRequests'];

  @visibleForTesting
  static AccountDeletionMemberships mergeMembershipIds({
    required String userId,
    required Iterable<String> privateCopyIds,
    required Iterable<String> communityCopyIds,
    required Iterable<String> canonicalMembershipPaths,
  }) {
    final privateIds = privateCopyIds.toSet();
    final communityIds = communityCopyIds.toSet();
    for (final path in canonicalMembershipPaths) {
      final segments = path.split('/');
      if (segments.length != 4 ||
          segments[2] != 'members' ||
          segments[3] != userId) {
        continue;
      }
      if (segments[0] == 'gubs') {
        privateIds.add(segments[1]);
      } else if (segments[0] == 'communities') {
        communityIds.add(segments[1]);
      }
    }
    final sortedPrivateIds = privateIds.toList()..sort();
    final sortedCommunityIds = communityIds.toList()..sort();
    return AccountDeletionMemberships(
      privateGubIds: sortedPrivateIds,
      communityIds: sortedCommunityIds,
    );
  }

  @visibleForTesting
  static List<Object?> anonymizeOrganizedEventAssignmentsData(
    List<Object?> assignments,
    String userId,
  ) => assignments
      .map<Object?>((assignment) {
        if (assignment is! Map || assignment['userId'] != userId) {
          return assignment;
        }
        final updated = Map<String, Object?>.from(assignment);
        updated['userId'] = deletedUserId;
        updated['userName'] = deletedUserName;
        return updated;
      })
      .toList(growable: false);

  @visibleForTesting
  static List<String> organizedEventAssignmentUserIds(
    List<Object?> assignments,
  ) => assignments
      .whereType<Map>()
      .map((assignment) => assignment['userId'])
      .whereType<String>()
      .toList(growable: false);

  @visibleForTesting
  static bool shouldAnonymizeScopedContent({
    required Object? membershipJoinedAt,
  }) => true;

  @visibleForTesting
  static Map<String, Object?> notificationDataUpdate(
    Map<String, dynamic> data,
    String userId,
  ) {
    final nested = data['data'];
    if (nested is! Map || nested['memberId'] != userId) return const {};
    return {
      'data': Map<String, Object?>.from(nested)..['memberId'] = deletedUserId,
    };
  }

  @override
  Future<void> beginDeletionState(String userId) async {
    final reference = _firestore
        .collection('accountDeletionStates')
        .doc(userId);
    final existing = await reference.get(
      const GetOptions(source: Source.server),
    );
    if (existing.exists) return;
    await reference.set({
      'userId': userId,
      'status': 'deleting',
      'startedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<AccountDeletionPreflight> loadPreflight(String userId) async {
    final results = await Future.wait([
      _firestore
          .collection('gubs')
          .where('ownerId', isEqualTo: userId)
          .get(const GetOptions(source: Source.server)),
      _firestore
          .collection('communities')
          .where('ownerId', isEqualTo: userId)
          .get(const GetOptions(source: Source.server)),
    ]);
    return AccountDeletionPreflight(
      privateGubs: results[0].docs
          .map(
            (document) => OwnedAccountResource(
              id: document.id,
              name: _name(document.data(), 'Private Gub'),
            ),
          )
          .toList(growable: false),
      communities: results[1].docs
          .map(
            (document) => OwnedAccountResource(
              id: document.id,
              name: _name(document.data(), 'Community'),
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<AccountDeletionMemberships> loadMemberships(String userId) async {
    final user = _firestore.collection('users').doc(userId);
    final results = await Future.wait([
      user.collection('gubs').get(const GetOptions(source: Source.server)),
      user
          .collection('communities')
          .get(const GetOptions(source: Source.server)),
      _firestore
          .collectionGroup('members')
          .where('uid', isEqualTo: userId)
          .get(const GetOptions(source: Source.server)),
    ]);
    return mergeMembershipIds(
      userId: userId,
      privateCopyIds: results[0].docs.map((document) => document.id),
      communityCopyIds: results[1].docs.map((document) => document.id),
      canonicalMembershipPaths: results[2].docs
          .where(
            (document) =>
                document.id == userId && document.data()['uid'] == userId,
          )
          .map((document) => document.reference.path),
    );
  }

  @override
  Future<void> anonymizeSharedContent({
    required String userId,
    required List<String> privateGubIds,
    required List<String> communityIds,
  }) async {
    for (final gubId in privateGubIds) {
      final gub = _firestore.collection('gubs').doc(gubId);
      final joinedAt = await _membershipJoinedAtOrNull(
        rootCollection: 'gubs',
        rootId: gubId,
        userId: userId,
      );
      Query<Map<String, dynamic>> messages = gub
          .collection('messages')
          .where('senderId', isEqualTo: userId);
      if (joinedAt != null) {
        messages = messages.where(
          'createdAt',
          isGreaterThanOrEqualTo: joinedAt,
        );
      }
      await _anonymizeQuery(
        messages,
        (_) => const {'senderId': deletedUserId, 'senderName': deletedUserName},
      );
      await _anonymizeQuery(
        gub.collection('posts').where('authorId', isEqualTo: userId),
        (_) => const {
          'authorId': deletedUserId,
          'authorName': deletedUserName,
          'authorPhoto': null,
        },
      );
      await _anonymizeQuery(
        gub.collection('posts').where('lastCommentAuthorId', isEqualTo: userId),
        (_) => const {'lastCommentAuthorId': deletedUserId},
      );
      await _anonymizeIdentityPairs(gub.collection('tasks'), userId, const [
        ('creatorId', 'creatorName'),
        ('assignedUserId', 'assignedUserName'),
        ('originUserId', 'sourceAuthorName'),
        ('completedBy', null),
      ]);
      await _anonymizeIdentityPairs(gub.collection('events'), userId, const [
        ('creatorId', 'creatorName'),
      ]);
      await _anonymizeIdentityPairs(
        gub.collection('organizedEvents'),
        userId,
        const [
          ('createdBy', 'createdByName'),
          ('originUserId', 'sourceAuthorName'),
        ],
      );
      await _anonymizeOrganizedEventAssignments(
        gub.collection('organizedEvents'),
        userId,
        includeLegacyDocuments: joinedAt != null,
      );
      await _anonymizeIdentityPairs(gub.collection('proposals'), userId, const [
        ('creatorId', 'creatorName'),
        ('originUserId', 'sourceAuthorName'),
        ('deletedBy', null),
      ]);
      await _anonymizeIdentityPairs(gub.collection('goals'), userId, const [
        ('originUserId', 'sourceAuthorName'),
      ]);
      Query<Map<String, dynamic>> sentNotifications = gub
          .collection('notifications')
          .where('senderId', isEqualTo: userId);
      Query<Map<String, dynamic>> readNotifications = gub
          .collection('notifications')
          .where('readBy', arrayContains: userId);
      if (joinedAt != null) {
        sentNotifications = sentNotifications.where(
          'createdAt',
          isGreaterThanOrEqualTo: joinedAt,
        );
        readNotifications = readNotifications.where(
          'createdAt',
          isGreaterThanOrEqualTo: joinedAt,
        );
      }
      await _anonymizeQuery(
        sentNotifications,
        (data) => _notificationUpdate(data, userId, anonymizeSender: true),
      );
      await _anonymizeQuery(
        readNotifications,
        (data) => _notificationUpdate(data, userId, anonymizeSender: false),
      );
      await _anonymizeQuery(
        gub
            .collection('notifications')
            .where('data.memberId', isEqualTo: userId),
        (data) => notificationDataUpdate(data, userId),
      );
      await _anonymizeIdentityPairs(
        gub.collection('creationCooldowns'),
        userId,
        const [('creatorId', null), ('deletedBy', null)],
      );
    }
    for (final communityId in communityIds) {
      final community = _firestore.collection('communities').doc(communityId);
      final joinedAt = await _membershipJoinedAtOrNull(
        rootCollection: 'communities',
        rootId: communityId,
        userId: userId,
      );
      Query<Map<String, dynamic>> messages = community
          .collection('messages')
          .where('senderId', isEqualTo: userId);
      if (joinedAt != null) {
        messages = messages.where(
          'createdAt',
          isGreaterThanOrEqualTo: joinedAt,
        );
      }
      await _anonymizeQuery(
        messages,
        (_) => const {'senderId': deletedUserId, 'senderName': deletedUserName},
      );
    }
    await _anonymizeQuery(
      _firestore
          .collectionGroup('messages')
          .where('senderId', isEqualTo: userId),
      (_) => const {'senderId': deletedUserId, 'senderName': deletedUserName},
    );
    await _anonymizeQuery(
      _firestore
          .collectionGroup('comments')
          .where('authorId', isEqualTo: userId),
      (_) => const {'authorId': deletedUserId, 'authorName': deletedUserName},
    );
    await _anonymizeQuery(
      _firestore.collectionGroup('asks').where('authorId', isEqualTo: userId),
      (_) => const {
        'authorId': deletedUserId,
        'authorDisplayName': deletedUserName,
      },
    );
    await _anonymizeCommunityAnswers(userId);
  }

  @override
  Future<void> deleteUserRoot(String userId) =>
      _firestore.collection('users').doc(userId).delete();

  @override
  Future<void> deleteDetachedIdentityDocuments(String userId) async {
    for (final (group, field) in const [
      ('likes', 'userId'),
      ('votes', 'uid'),
      ('members', 'uid'),
    ]) {
      DocumentSnapshot<Map<String, dynamic>>? cursor;
      while (true) {
        Query<Map<String, dynamic>> query = _firestore
            .collectionGroup(group)
            .where(field, isEqualTo: userId)
            .orderBy(FieldPath.documentId)
            .limit(_deletePageSize);
        if (group == 'members' && cursor != null) {
          query = query.startAfterDocument(cursor);
        }
        final page = await query.get(const GetOptions(source: Source.server));
        if (page.docs.isEmpty) break;
        final references = page.docs
            .where(
              (document) =>
                  group != 'members' || _isGoalMember(document.reference.path),
            )
            .map((document) => document.reference)
            .toList(growable: false);
        if (references.isNotEmpty) {
          final batch = _firestore.batch();
          for (final reference in references) {
            batch.delete(reference);
          }
          await batch.commit();
        }
        if (group == 'members') cursor = page.docs.last;
      }
    }
  }

  bool _isGoalMember(String path) {
    final segments = path.split('/');
    return segments.length == 6 &&
        segments[0] == 'gubs' &&
        segments[2] == 'goals' &&
        segments[4] == 'members';
  }

  Future<void> _anonymizeIdentityPairs(
    CollectionReference<Map<String, dynamic>> collection,
    String userId,
    List<(String, String?)> pairs, {
    Timestamp? createdAtBoundary,
  }) async {
    for (final (idField, nameField) in pairs) {
      Query<Map<String, dynamic>> query = collection.where(
        idField,
        isEqualTo: userId,
      );
      if (createdAtBoundary != null) {
        query = query.where(
          'createdAt',
          isGreaterThanOrEqualTo: createdAtBoundary,
        );
      }
      await _anonymizeQuery(query, (_) => _identityUpdate(idField, nameField));
    }
  }

  Future<void> _anonymizeOrganizedEventAssignments(
    CollectionReference<Map<String, dynamic>> collection,
    String userId, {
    required bool includeLegacyDocuments,
  }) async {
    final snapshot = includeLegacyDocuments
        ? await collection.get(const GetOptions(source: Source.server))
        : await collection
              .where('assignmentUserIds', arrayContains: userId)
              .get(const GetOptions(source: Source.server));
    for (final document in snapshot.docs) {
      final assignments = document.data()['assignments'];
      if (assignments is! List) continue;

      final changed = assignments.any(
        (assignment) => assignment is Map && assignment['userId'] == userId,
      );
      final updatedAssignments = anonymizeOrganizedEventAssignmentsData(
        assignments.cast<Object?>(),
        userId,
      );
      if (changed) {
        await document.reference.update({
          'assignments': updatedAssignments,
          'assignmentUserIds': organizedEventAssignmentUserIds(
            updatedAssignments,
          ),
        });
      }
    }
  }

  Future<Timestamp?> _membershipJoinedAtOrNull({
    required String rootCollection,
    required String rootId,
    required String userId,
  }) async {
    final snapshot = await _firestore
        .collection(rootCollection)
        .doc(rootId)
        .collection('members')
        .doc(userId)
        .get(const GetOptions(source: Source.server));
    final joinedAt = snapshot.data()?['joinedAt'];
    return joinedAt is Timestamp ? joinedAt : null;
  }

  Future<void> _anonymizeCommunityAnswers(String userId) async {
    final bestAnswerAsks = await _firestore
        .collectionGroup('asks')
        .where('bestAnswerAuthorId', isEqualTo: userId)
        .get(const GetOptions(source: Source.server));
    final bestAnswerAskPaths = bestAnswerAsks.docs
        .map((document) => document.reference.path)
        .toSet();
    final snapshot = await _firestore
        .collectionGroup('answers')
        .where('authorId', isEqualTo: userId)
        .get(const GetOptions(source: Source.server));
    for (final answer in snapshot.docs) {
      final ask = answer.reference.parent.parent;
      if (ask == null || answer.id != userId) continue;
      var sourceData = answer.data();
      var replacementId = sourceData['deletionReplacementAnswerId'];
      if (replacementId is! String || replacementId.isEmpty) {
        replacementId = answer.reference.parent.doc().id;
        await answer.reference.update({
          'deletionReplacementAnswerId': replacementId,
        });
        sourceData = {
          ...sourceData,
          'deletionReplacementAnswerId': replacementId,
        };
      }
      final replacement = answer.reference.parent.doc(replacementId);
      final data = Map<String, Object?>.from(sourceData)
        ..['answerId'] = replacement.id
        ..['authorId'] = deletedUserId
        ..['authorDisplayName'] = deletedUserName
        ..remove('deletionReplacementAnswerId');
      final batch = _firestore.batch();
      batch.set(replacement, data);
      if (bestAnswerAskPaths.contains(ask.path)) {
        batch.update(ask, {
          'bestAnswerId': replacement.id,
          'bestAnswerAuthorId': deletedUserId,
        });
      }
      batch.delete(answer.reference);
      await batch.commit();
    }
  }

  Map<String, Object?> _identityUpdate(String idField, String? nameField) {
    final update = <String, Object?>{idField: deletedUserId};
    if (nameField case final field?) update[field] = deletedUserName;
    return update;
  }

  Map<String, Object?> _notificationUpdate(
    Map<String, dynamic> data,
    String userId, {
    required bool anonymizeSender,
  }) {
    final update = <String, Object?>{};
    final readBy = data['readBy'];
    if (readBy is List && readBy.contains(userId)) {
      update['readBy'] = readBy
          .where((value) => value != userId)
          .toList(growable: false);
    }
    if (!anonymizeSender || data['senderId'] != userId) return update;

    update['senderId'] = deletedUserId;
    update['senderName'] = deletedUserName;
    final senderName = data['senderName'];
    final body = data['body'];
    final type = data['type'];
    if (type == 'goal_confirmation') {
      update['body'] = '$deletedUserName confirmed a contribution.';
      return update;
    }
    if (senderName is String &&
        senderName.isNotEmpty &&
        body is String &&
        _notificationTypesWithSenderPrefix.contains(type) &&
        body.startsWith('$senderName ')) {
      update['body'] =
          '$deletedUserName ${body.substring(senderName.length + 1)}';
    }
    return update;
  }

  static const _notificationTypesWithSenderPrefix = <String>{
    'task_created',
    'proposal_created',
    'organized_event_created',
    'goal_created',
    'board_post',
  };

  Future<void> _anonymizeQuery(
    Query<Map<String, dynamic>> query,
    Map<String, Object?> Function(Map<String, dynamic>) updateFor,
  ) async {
    final snapshot = await query.get(const GetOptions(source: Source.server));
    for (final document in snapshot.docs) {
      await document.reference.update(updateFor(document.data()));
    }
  }

  @override
  Future<void> deletePrivateReadState(String gubId, String userId) async {
    final gub = _firestore.collection('gubs').doc(gubId);
    final batch = _firestore.batch();
    batch.delete(gub.collection('chatReads').doc(userId));
    batch.delete(gub.collection('boardReads').doc(userId));
    await batch.commit();
  }

  @override
  Future<void> deleteCommunityJoinRequest(
    String communityId,
    String userId,
  ) async {
    final reference = _firestore
        .collection('communities')
        .doc(communityId)
        .collection('joinRequests')
        .doc(userId);
    final snapshot = await reference.get(
      const GetOptions(source: Source.server),
    );
    if (snapshot.exists) {
      await reference.delete();
    }
  }

  @override
  Future<void> deleteCommunityActiveAskSlots(String userId) async {
    while (true) {
      final snapshot = await _firestore
          .collectionGroup('activeAskSlots')
          .where('authorId', isEqualTo: userId)
          .limit(_deletePageSize)
          .get(const GetOptions(source: Source.server));
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }
  }

  @override
  Future<void> deletePrivateCopy(String gubId, String userId) => _firestore
      .collection('users')
      .doc(userId)
      .collection('gubs')
      .doc(gubId)
      .delete();

  @override
  Future<void> deleteCommunityCopy(String communityId, String userId) =>
      _firestore
          .collection('users')
          .doc(userId)
          .collection('communities')
          .doc(communityId)
          .delete();

  @override
  Future<void> deleteProfile(String userId) async {
    final userReference = _firestore.collection('users').doc(userId);
    for (final collection in profileSubcollectionsForDeletion) {
      await _deleteCollection(userReference.collection(collection));
    }

    final batch = _firestore.batch();
    for (final collection in profileDocumentCollections) {
      if (collection != 'users') {
        batch.delete(_firestore.collection(collection).doc(userId));
      }
    }
    await batch.commit();
    await _deleteExternalUserDocuments(userId);
  }

  Future<void> _deleteExternalUserDocuments(String userId) async {
    for (final collectionGroup in externalCollectionGroupsForDeletion) {
      while (true) {
        final page = await _firestore
            .collectionGroup(collectionGroup)
            .where('userId', isEqualTo: userId)
            .limit(_deletePageSize)
            .get(const GetOptions(source: Source.server));
        if (page.docs.isEmpty) break;
        final batch = _firestore.batch();
        for (final document in page.docs) {
          batch.delete(document.reference);
        }
        await batch.commit();
      }
    }
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final page = await collection
          .orderBy(FieldPath.documentId)
          .limit(_deletePageSize)
          .get(const GetOptions(source: Source.server));
      if (page.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final document in page.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }
  }

  String _name(Map<String, dynamic> data, String fallback) {
    final value = data['name'];
    return value is String && value.trim().isNotEmpty ? value.trim() : fallback;
  }
}
