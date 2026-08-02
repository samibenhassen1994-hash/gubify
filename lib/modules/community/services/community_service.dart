import 'package:firebase_auth/firebase_auth.dart';

import '../../../config/app_limits.dart';
import '../../../repositories/user_repository.dart';
import '../models/community_model.dart';
import '../repositories/community_repository.dart';

class CommunityService {
  CommunityService._();

  static final CommunityService instance = CommunityService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<CommunityModel> createCommunity({
    required String name,
    String? type,
    String? language,
    String? description,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError("You must be signed in to create a community.");
    }

    final normalizedName = name.trim();
    final normalizedType = CommunityModel.normalizeType(type);
    final normalizedLanguage = CommunityModel.normalizeLanguage(language);
    final normalizedDescription = (description ?? "").trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError("Community name cannot be empty.");
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

    try {
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
      );
      if (community == null) {
        throw const CommunityCreationLimitException();
      }
      return community;
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

  Stream<List<CommunityModel>> publicCommunitiesStream() {
    return CommunityRepository.instance.publicCommunitiesStream();
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

  Future<void> deleteCommunity({
    required String communityId,
    required String confirmationName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const CommunityDeletionException("Please sign in again.");
    }
    await CommunityRepository.instance.deleteCommunityClientSide(
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
    if (!_deletionsInProgress.add(communityId)) {
      throw const CommunityDeletionException(
        'This Community deletion is already in progress.',
      );
    }
    try {
      await CommunityRepository.instance.deleteCommunityClientSide(
        communityId: communityId,
        confirmationName: null,
      );
    } finally {
      _deletionsInProgress.remove(communityId);
    }
  }

  Future<CommunityModel> joinCommunity({required String communityId}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError("You must be signed in to join a community.");
    }

    final normalizedCommunityId = communityId.trim();
    if (normalizedCommunityId.isEmpty) {
      throw ArgumentError("Community ID cannot be empty.");
    }

    try {
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

      return await CommunityRepository.instance.joinCommunity(
        communityId: normalizedCommunityId,
        userId: user.uid,
        displayName: displayName,
        photoUrl: photoUrl,
      );
    } on FirebaseException catch (error) {
      throw Exception(_firebaseErrorMessage(error));
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

class CommunityCreationLimitException implements Exception {
  const CommunityCreationLimitException();

  @override
  String toString() => "You can create only one Community.";
}
