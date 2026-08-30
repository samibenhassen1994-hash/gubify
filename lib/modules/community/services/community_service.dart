import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../../config/app_limits.dart';
import '../../../repositories/user_repository.dart';
import '../../../services/app_sound_service.dart';
import '../models/community_access_request_model.dart';
import '../models/community_model.dart';
import '../models/community_name_conflict.dart';
import '../images/community_image_models.dart';
import '../images/community_image_service.dart';
import '../repositories/community_name_registry_repository.dart';
import '../repositories/community_repository.dart';
import '../restrictions/services/community_restriction_service.dart';
import '../utils/community_name_key.dart';

class CommunityService {
  CommunityService._();

  static final CommunityService instance = CommunityService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool get isCurrentUserAnonymous => _auth.currentUser?.isAnonymous ?? false;

  Future<CommunityModel> createCommunity({
    required String name,
    String? type,
    String? language,
    String? description,
    required String accessMode,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError("You must be signed in to create a community.");
    }
    requireLinkedCommunityAccount(
      isSignedIn: true,
      isAnonymous: user.isAnonymous,
      action: 'create a community',
    );

    final normalizedName = name.trim();
    final normalizedType = CommunityModel.normalizeType(type);
    final normalizedLanguage = CommunityModel.normalizeLanguage(language);
    final normalizedDescription = (description ?? "").trim();
    final normalizedAccessMode = CommunityModel.normalizeAccessMode(accessMode);
    if (normalizedName.isEmpty) {
      throw ArgumentError("Community name cannot be empty.");
    }
    if (RegExp(r'[\r\n]').hasMatch(normalizedName)) {
      throw ArgumentError("Community name cannot contain line breaks.");
    }
    if (normalizedName.length < AppLimits.gubNameMinLength) {
      throw ArgumentError(
        "Community name must be at least "
        "${AppLimits.gubNameMinLength} characters.",
      );
    }
    if (normalizedName.length > AppLimits.gubNameMaxLength) {
      throw ArgumentError(
        "Community name cannot exceed "
        "${AppLimits.gubNameMaxLength} characters.",
      );
    }
    if (normalizedDescription.length >
        AppLimits.communityDescriptionMaxLength) {
      throw ArgumentError(
        "Community description cannot exceed "
        "${AppLimits.communityDescriptionMaxLength} characters.",
      );
    }

    try {
      final nameKey = CommunityNameKey.fromName(normalizedName);
      final existingCommunityId = await CommunityNameRegistryRepository.instance
          .findExistingCommunityId(nameKey);
      if (existingCommunityId != null) {
        throw CommunityNameAlreadyExistsException(existingCommunityId);
      }

      final userData = await UserRepository.instance.getUser(user.uid);
      final storedDisplayName = userData?["displayName"];
      final displayName =
          storedDisplayName is String && storedDisplayName.trim().isNotEmpty
          ? storedDisplayName.trim()
          : user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : "User";
      final storedPhotoUrl = userData?["photoUrl"] ?? userData?["photoURL"];
      final photoUrl =
          storedPhotoUrl is String && storedPhotoUrl.trim().isNotEmpty
          ? storedPhotoUrl.trim()
          : user.photoURL;

      final community = await CommunityRepository.instance.createCommunity(
        name: normalizedName,
        ownerId: user.uid,
        displayName: displayName,
        photoUrl: photoUrl,
        type: normalizedType,
        language: normalizedLanguage,
        description: normalizedDescription,
        accessMode: normalizedAccessMode,
      );
      if (community == null) {
        throw const CommunityCreationLimitException();
      }
      await AppSoundService.instance.playCreated();
      return community;
    } on CommunityNameAlreadyExistsException {
      rethrow;
    } on FirebaseException catch (error) {
      throw Exception(_firebaseErrorMessage(error));
    }
  }

  Future<CommunityModel?> loadCommunity(String communityId) async {
    if (_auth.currentUser == null) {
      throw StateError("You must be signed in to view a community.");
    }

    final normalizedId = communityId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError("Community ID cannot be empty.");
    }

    try {
      return await CommunityRepository.instance.getCommunity(normalizedId);
    } on FirebaseException catch (error) {
      throw Exception(_firebaseErrorMessage(error));
    }
  }

  Future<CommunityModel?> loadCurrentMemberCommunity(String communityId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError("You must be signed in to view a community.");
    }

    final normalizedId = communityId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError("Community ID cannot be empty.");
    }

    try {
      final community = await CommunityRepository.instance
          .getCommunityForMember(communityId: normalizedId, userId: user.uid);
      _initializeCommunityRestrictionForOwner(community, user.uid);
      return community;
    } on FirebaseException catch (error) {
      throw Exception(_firebaseErrorMessage(error));
    }
  }

  Stream<CommunityModel?> currentMemberCommunityStream(String communityId) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.error(
        StateError("You must be signed in to view communities."),
      );
    }
    final normalizedId = communityId.trim();
    if (normalizedId.isEmpty) return const Stream.empty();
    return CommunityRepository.instance
        .communityForMemberStream(communityId: normalizedId, userId: user.uid)
        .map((community) {
          _initializeCommunityRestrictionForOwner(community, user.uid);
          return community;
        });
  }

  void _initializeCommunityRestrictionForOwner(
    CommunityModel? community,
    String currentUserId,
  ) {
    if (community == null || community.ownerId != currentUserId) return;
    unawaited(
      _initializeCommunityRestriction(community.communityId, currentUserId),
    );
  }

  Future<void> _initializeCommunityRestriction(
    String communityId,
    String ownerId,
  ) async {
    try {
      await CommunityRestrictionService.instance.initializeCommunityRestriction(
        communityId: communityId,
        ownerId: ownerId,
      );
    } on Object {
      // Existing Communities remain available when the one-time default cannot
      // be initialized, and missing documents are safely unrestricted.
    }
  }

  Future<CommunityExplorerPage> loadPublicCommunitiesPage({
    CommunityExplorerCursor? after,
  }) {
    if (_auth.currentUser == null) {
      throw StateError("You must be signed in to explore communities.");
    }
    return CommunityRepository.instance.loadPublicCommunitiesPage(after: after);
  }

  Future<CommunityPublicAccessState?> loadPublicAccessState(
    String communityId,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError("You must be signed in to view a community.");
    }
    final normalizedId = communityId.trim();
    if (normalizedId.isEmpty) return null;
    try {
      return await CommunityRepository.instance.getPublicAccessState(
        communityId: normalizedId,
        userId: user.uid,
      );
    } on FirebaseException catch (error) {
      throw Exception(_firebaseErrorMessage(error));
    }
  }

  Stream<CommunityPublicAccessState?> publicAccessStateStream(
    String communityId,
  ) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.error(
        StateError("You must be signed in to view a community."),
      );
    }
    final normalizedId = communityId.trim();
    if (normalizedId.isEmpty) return const Stream.empty();
    return CommunityRepository.instance.publicAccessStateStream(
      communityId: normalizedId,
      userId: user.uid,
    );
  }

  Stream<Set<String>> joinedCommunityIdsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.error(
        StateError("You must be signed in to view communities."),
      );
    }

    return CommunityRepository.instance.userCommunityIdsStream(user.uid);
  }

  Stream<List<CommunityModel>> myCommunitiesStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.error(
        StateError("You must be signed in to view your communities."),
      );
    }

    return CommunityRepository.instance.userCommunitiesStream(user.uid);
  }

  Stream<List<CommunityMembershipModel>> myCommunityMembershipsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.error(
        StateError("You must be signed in to view your communities."),
      );
    }
    return CommunityRepository.instance.userCommunityMembershipsStream(
      user.uid,
    );
  }

  Future<bool> currentUserOwnsCommunity() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError("You must be signed in to create a community.");
    }
    try {
      return await CommunityRepository.instance.ownsCommunity(user.uid);
    } on FirebaseException catch (error) {
      throw Exception(_firebaseErrorMessage(error));
    }
  }

  bool isCurrentUserOwner(CommunityModel community) {
    return _auth.currentUser?.uid == community.ownerId;
  }

  Future<String> currentUserRole(String communityId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError("You must be signed in to view Community settings.");
    }
    return CommunityRepository.instance.getMemberRole(
      communityId: communityId,
      userId: user.uid,
    );
  }

  Stream<List<CommunityMemberModel>> communityMembersStream(
    String communityId,
  ) {
    _requireUser('view Community members');
    final normalizedId = communityId.trim();
    if (normalizedId.isEmpty) return const Stream.empty();
    return CommunityRepository.instance.communityMembersStream(normalizedId);
  }

  Future<CommunityMemberModel?> loadCommunityMember({
    required String communityId,
    required String userId,
  }) async {
    _requireUser('view Community member profiles');
    return CommunityRepository.instance.getCommunityMember(
      communityId: communityId.trim(),
      userId: userId,
    );
  }

  Future<void> leaveCommunity(String communityId) async {
    final user = _requireUser('leave a community');
    final normalizedId = communityId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError('Community ID cannot be empty.');
    }
    await CommunityRepository.instance.leaveCommunity(
      communityId: normalizedId,
      userId: user.uid,
    );
  }

  Future<void> removeCommunityMember({
    required String communityId,
    required String userId,
  }) async {
    final owner = _requireUser('remove community members');
    await CommunityRepository.instance.removeCommunityMember(
      communityId: communityId.trim(),
      userId: userId,
      actorId: owner.uid,
    );
  }

  Future<void> banCommunityMember({
    required String communityId,
    required String userId,
  }) async {
    final owner = _requireUser('ban community members');
    await CommunityRepository.instance.banCommunityMember(
      communityId: communityId.trim(),
      userId: userId,
      ownerId: owner.uid,
    );
  }

  Future<void> deleteCommunity({
    required String communityId,
    required String confirmationName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const CommunityDeletionException("Please sign in again.");
    }
    await _runDeletion(
      communityId: communityId,
      confirmationName: confirmationName,
    );
  }

  final Set<String> _deletionsInProgress = {};

  Future<void> resumeDeletion({required String communityId}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const CommunityDeletionException('Please sign in again.');
    }
    await _runDeletion(communityId: communityId, confirmationName: null);
  }

  Future<void> _runDeletion({
    required String communityId,
    required String? confirmationName,
  }) async {
    final normalizedCommunityId = communityId.trim();
    if (!_deletionsInProgress.add(normalizedCommunityId)) {
      throw const CommunityDeletionException(
        'This Community deletion is already in progress.',
      );
    }
    try {
      await CommunityRepository.instance.deleteCommunityClientSide(
        communityId: normalizedCommunityId,
        confirmationName: confirmationName,
        deleteImageAsset: CommunityImageService.instance.deleteCloudinaryAsset,
      );
    } on CommunityImageDeleteException catch (error) {
      throw CommunityDeletionException(error.message);
    } finally {
      _deletionsInProgress.remove(normalizedCommunityId);
    }
  }

  Future<CommunityModel> joinCommunity({required String communityId}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError("You must be signed in to join a community.");
    }
    requireLinkedCommunityAccount(
      isSignedIn: true,
      isAnonymous: user.isAnonymous,
      action: 'join a community',
    );

    final normalizedCommunityId = communityId.trim();
    if (normalizedCommunityId.isEmpty) {
      throw ArgumentError("Community ID cannot be empty.");
    }

    try {
      if (await CommunityRepository.instance.isUserBanned(
        communityId: normalizedCommunityId,
        userId: user.uid,
      )) {
        throw Exception(
          'You were banned from this Community by an administrator.',
        );
      }
      final identity = await _currentIdentity(user);

      final community = await CommunityRepository.instance.joinCommunity(
        communityId: normalizedCommunityId,
        userId: user.uid,
        displayName: identity.displayName,
        photoUrl: identity.photoUrl,
      );
      await AppSoundService.instance.playJoined();
      return community;
    } on FirebaseException catch (error) {
      throw Exception(_firebaseErrorMessage(error));
    }
  }

  final Set<String> _accessOperationsInProgress = {};

  Future<void> requestToJoin(String communityId) async {
    final user = _requireUser("request access to a community");
    requireLinkedCommunityAccount(
      isSignedIn: true,
      isAnonymous: user.isAnonymous,
      action: 'request access to a community',
    );
    final normalizedId = communityId.trim();
    await _guardAccessOperation("request/$normalizedId/${user.uid}", () async {
      if (await CommunityRepository.instance.isUserBanned(
        communityId: normalizedId,
        userId: user.uid,
      )) {
        throw Exception(
          'You were banned from this Community by an administrator.',
        );
      }
      final identity = await _currentIdentity(user);
      await CommunityRepository.instance.createJoinRequest(
        communityId: normalizedId,
        userId: user.uid,
        displayName: identity.displayName,
      );
    });
  }

  Future<void> cancelJoinRequest(String communityId) async {
    final user = _requireUser("cancel a community request");
    final normalizedId = communityId.trim();
    await _guardAccessOperation("cancel/$normalizedId/${user.uid}", () {
      return CommunityRepository.instance.cancelJoinRequest(
        communityId: normalizedId,
        userId: user.uid,
      );
    });
  }

  Future<List<CommunityAccessRequestModel>> pendingJoinRequests(
    String communityId,
  ) async {
    final user = _requireUser("manage community requests");
    final normalizedId = communityId.trim();
    final community = await CommunityRepository.instance.getCommunity(
      normalizedId,
    );
    if (community?.ownerId != user.uid) {
      throw StateError("Only the Community owner can manage requests.");
    }
    return CommunityRepository.instance.pendingJoinRequests(
      communityId: normalizedId,
    );
  }

  Stream<int> pendingJoinRequestCountStream(String communityId) {
    _requireUser("manage community requests");
    final normalizedId = communityId.trim();
    if (normalizedId.isEmpty) return Stream.value(0);
    return CommunityRepository.instance.pendingJoinRequestCountStream(
      normalizedId,
    );
  }

  Stream<List<Map<String, dynamic>>> bannedUsersStream(String communityId) {
    _requireUser('view banned users');
    return CommunityRepository.instance.bannedUsersStream(communityId.trim());
  }

  Future<void> unbanMember({required String communityId, required String uid}) {
    _requireUser('unban a user');
    return CommunityRepository.instance.unbanMember(
      communityId: communityId.trim(),
      uid: uid,
    );
  }

  Future<void> approveJoinRequest({
    required String communityId,
    required String userId,
  }) async {
    final owner = _requireUser("approve community requests");
    await _guardAccessOperation("approve/$communityId/$userId", () {
      return CommunityRepository.instance.approveJoinRequest(
        communityId: communityId,
        ownerId: owner.uid,
        userId: userId,
      );
    });
  }

  Future<void> rejectJoinRequest({
    required String communityId,
    required String userId,
  }) async {
    final owner = _requireUser("reject community requests");
    await _guardAccessOperation("reject/$communityId/$userId", () {
      return CommunityRepository.instance.rejectJoinRequest(
        communityId: communityId,
        ownerId: owner.uid,
        userId: userId,
      );
    });
  }

  Future<String> currentDisplayName() async {
    final user = _requireUser('resolve your display name');
    return (await _currentIdentity(user)).displayName;
  }

  User _requireUser(String action) {
    final user = _auth.currentUser;
    if (user == null) throw StateError("You must be signed in to $action.");
    return user;
  }

  Future<({String displayName, String? photoUrl})> _currentIdentity(
    User user,
  ) async {
    final userData = await UserRepository.instance.getUser(user.uid);
    final storedDisplayName = userData?["displayName"];
    final displayName =
        storedDisplayName is String && storedDisplayName.trim().isNotEmpty
        ? storedDisplayName.trim()
        : user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : "User";
    final storedPhotoUrl = userData?["photoUrl"] ?? userData?["photoURL"];
    final photoUrl =
        storedPhotoUrl is String && storedPhotoUrl.trim().isNotEmpty
        ? storedPhotoUrl.trim()
        : user.photoURL;
    return (displayName: displayName, photoUrl: photoUrl);
  }

  Future<void> _guardAccessOperation(
    String key,
    Future<void> Function() operation,
  ) async {
    if (!_accessOperationsInProgress.add(key)) {
      throw StateError("This Community operation is already in progress.");
    }
    try {
      await operation();
    } on FirebaseException catch (error) {
      throw Exception(_firebaseErrorMessage(error));
    } finally {
      _accessOperationsInProgress.remove(key);
    }
  }

  String _firebaseErrorMessage(FirebaseException error) {
    return switch (error.code) {
      "unavailable" =>
        "No internet connection. Please check your connection and try again.",
      "permission-denied" =>
        "You don't have permission to access this community.",
      "deadline-exceeded" => "The connection timed out. Please try again.",
      _ => error.message ?? "Unable to complete the community request.",
    };
  }
}

class CommunityLinkedAccountRequiredException implements Exception {
  const CommunityLinkedAccountRequiredException(this.message);

  final String message;

  @override
  String toString() => message;
}

void requireLinkedCommunityAccount({
  required bool isSignedIn,
  required bool isAnonymous,
  required String action,
}) {
  if (!isSignedIn) {
    throw StateError('You must be signed in to $action.');
  }
  if (isAnonymous) {
    throw CommunityLinkedAccountRequiredException(
      'Secure your account before you $action.',
    );
  }
}

class CommunityCreationLimitException implements Exception {
  const CommunityCreationLimitException();

  @override
  String toString() => "You can create only one Community.";
}
