from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text()
    if old not in text:
        raise SystemExit(f"Expected snippet not found in {path}: {old[:80]!r}")
    file.write_text(text.replace(old, new, 1))


account = "lib/modules/profile/repositories/account_deletion_repository.dart"
replace_once(
    account,
    """  static const profileSubcollectionsForDeletion = <String>[
    'gubs',
    'communities',
    'blockedUsers',
  ];
""",
    """  static const profileSubcollectionsForDeletion = <String>[
    'gubs',
    'communities',
    'blockedUsers',
  ];

  @visibleForTesting
  static const externalCollectionGroupsForDeletion = <String>[
    'joinRequests',
  ];
""",
)
replace_once(
    account,
    """  Future<void> deleteProfile(String userId) async {
    final userReference = _firestore.collection('users').doc(userId);
""",
    """  Future<void> deleteProfile(String userId) async {
    await _deleteExternalUserDocuments(userId);
    final userReference = _firestore.collection('users').doc(userId);
""",
)
replace_once(
    account,
    """  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
""",
    """  Future<void> _deleteExternalUserDocuments(String userId) async {
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
""",
)

community = "lib/modules/community/repositories/community_repository.dart"
replace_once(
    community,
    '  static const String _deletionMembersSubcollection = "deletionMembers";\n',
    """  static const String _deletionMembersSubcollection = "deletionMembers";

  @visibleForTesting
  static const List<String> rewardReferenceFieldsForDeletion = [
    'lastRewardCommunityId',
    'lastRewardAskId',
    'lastRewardRole',
  ];
""",
)
replace_once(
    community,
    """          await _deleteUserMembershipCopies(
            communityId: normalizedCommunityId,
            communityReference: communityReference,
          );

          deletionStep = 'delete_ask_answers';
""",
    """          await _deleteUserMembershipCopies(
            communityId: normalizedCommunityId,
            communityReference: communityReference,
          );

          deletionStep = 'delete_reward_references';
          deletionPath = 'communityUserProgress/*';
          await _deleteCommunityRewardReferences(normalizedCommunityId);

          deletionStep = 'delete_ask_answers';
""",
)
replace_once(
    community,
    "  Future<void> _deleteOwnershipAndCommunity({\n",
    """  Future<void> _deleteCommunityRewardReferences(String communityId) async {
    while (true) {
      final page = await _firestore
          .collection('communityUserProgress')
          .where('lastRewardCommunityId', isEqualTo: communityId)
          .limit(_batchSize)
          .get();
      if (page.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final document in page.docs) {
        batch.update(document.reference, {
          for (final field in rewardReferenceFieldsForDeletion)
            field: FieldValue.delete(),
        });
      }
      await batch.commit();
    }
  }

  Future<void> _deleteOwnershipAndCommunity({
""",
)

rules = "firestore.rules"
replace_once(
    rules,
    "    function validCommunityProjectionVersion(uid) {\n",
    """    function validCommunityRewardReferenceCleanup(uid) {
      let id = resource.data.get('lastRewardCommunityId', '');
      let after = request.resource.data;
      return linkedCommunityAccount()
        && id is string && id.size() > 0
        && communityDeletingOwner(id)
        && validCommunityProgressSchema(after)
        && after.diff(resource.data).affectedKeys().hasOnly([
          'lastRewardCommunityId','lastRewardAskId','lastRewardRole'
        ])
        && !after.keys().hasAny([
          'lastRewardCommunityId','lastRewardAskId','lastRewardRole'
        ]);
    }
    function validCommunityProjectionVersion(uid) {
""",
)
replace_once(
    rules,
    "      allow update: if validCommunityProjectionRemoval(uid);\n",
    """      allow update: if validCommunityProjectionRemoval(uid)
        || validCommunityRewardReferenceCleanup(uid);
""",
)
replace_once(
    rules,
    """    match /{path=**}/members/{memberId} {
      allow list: if signedIn() && resource.data.uid == request.auth.uid;
    }

    match /inviteTokens/{canonicalCode} {
""",
    """    match /{path=**}/members/{memberId} {
      allow list: if signedIn() && resource.data.uid == request.auth.uid;
    }

    match /{path=**}/joinRequests/{uid} {
      allow list: if linkedCommunityAccount()
        && resource.data.userId == request.auth.uid;
    }

    match /inviteTokens/{canonicalCode} {
""",
)
replace_once(
    rules,
    """            || (!existsAfter(/databases/$(database)/documents/users/$(uid))
              && resource.data.status in ['approved','rejected'])))
          || communityDeletingOwner(id);
""",
    """            || ((!existsAfter(/databases/$(database)/documents/users/$(uid))
                  || !exists(communityMemberPath(id, uid)))
              && resource.data.status in ['approved','rejected'])))
          || communityDeletingOwner(id);
""",
)
replace_once(
    rules,
    """          allow update, delete: if false;
        }

        match /likes/{uid} {
""",
    """          allow update: if false;
          allow delete: if gubDeletingOwner(id);
        }

        match /likes/{uid} {
""",
)
replace_once(
    rules,
    """          allow delete: if own(uid) && isGubMember(id) && gubActive(id)
            && getAfter(/databases/$(database)/documents/gubs/$(id)/posts/$(postId)).data.likes
              == get(/databases/$(database)/documents/gubs/$(id)/posts/$(postId)).data.likes - 1;
""",
    """          allow delete: if (own(uid) && isGubMember(id) && gubActive(id)
            && getAfter(/databases/$(database)/documents/gubs/$(id)/posts/$(postId)).data.likes
              == get(/databases/$(database)/documents/gubs/$(id)/posts/$(postId)).data.likes - 1)
            || gubDeletingOwner(id);
""",
)
