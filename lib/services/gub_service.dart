import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/app_limits.dart';
import '../core/invites/invite_code.dart';
import '../core/models/member_option.dart';
import '../repositories/gub_invite_repository.dart';
import '../repositories/member_repository.dart';
import '../repositories/user_repository.dart';
import 'app_sound_service.dart';

class GubService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GubInviteRepository _inviteRepository = GubInviteRepository();
  final InviteCodeGenerator _inviteCodeGenerator = InviteCodeGenerator.secure();

  Future<String> createHub({required String name}) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not authenticated.");
    }

    final ownedHubs = await _firestore
        .collection("gubs")
        .where("ownerId", isEqualTo: user.uid)
        .count()
        .get();

    if ((ownedHubs.count ?? 0) >= AppLimits.freeMaxHubs) {
      throw Exception(
        "You have reached the maximum number of Hubs (${AppLimits.freeMaxHubs}).",
      );
    }

    final userData = await UserRepository.instance.getUser(user.uid);

    final displayName = userData?["displayName"] ?? "User";

    final gubId = _inviteRepository.newGubId();
    final createdGubId = await reserveUniqueInviteCode<String>(
      generator: _inviteCodeGenerator,
      tryReserve: (candidate) async {
        final created = await _inviteRepository.tryCreateGubWithToken(
          gubId: gubId,
          name: name.trim(),
          ownerId: user.uid,
          displayName: displayName,
          photoUrl: user.photoURL,
          canonicalCode: candidate,
        );
        return created ? gubId : null;
      },
    );

    await AppSoundService.instance.playCreated();
    return createdGubId;
  }

  Future<String> joinHub({required String inviteCode}) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("User not authenticated.");
    }

    final userData = await UserRepository.instance.getUser(user.uid);

    final displayName = userData?["displayName"] ?? "User";

    late final String canonicalCode;
    try {
      canonicalCode = InviteCode.normalize(inviteCode);
    } on InvalidInviteCodeException {
      throw const InvalidInviteCodeException();
    }

    InviteTokenData? token;

    try {
      token = await _inviteRepository.getToken(canonicalCode);
    } on FirebaseException catch (e) {
      switch (e.code) {
        case "unavailable":
          throw Exception(
            "No internet connection. Please check your connection and try again.",
          );

        case "permission-denied":
          throw const InvalidInviteCodeException();

        case "deadline-exceeded":
          throw Exception("The connection timed out. Please try again.");

        default:
          throw Exception(e.message ?? "Unexpected connection error.");
      }
    }

    if (token == null || !token.isUsable) {
      throw const InvalidInviteCodeException();
    }

    if (await _inviteRepository.isUserBanned(
      gubId: token.gubId,
      userId: user.uid,
    )) {
      throw Exception('You were banned from this Gub by an administrator.');
    }

    final existingMembership = await _inviteRepository.getOwnMembership(
      gubId: token.gubId,
      userId: user.uid,
    );
    if (existingMembership != null) {
      return _existingMembershipResult(
        token: token,
        userId: user.uid,
        membership: existingMembership,
      );
    }

    try {
      await _inviteRepository.joinWithToken(
        token: token,
        userId: user.uid,
        displayName: displayName,
        photoUrl: user.photoURL,
      );
      await AppSoundService.instance.playJoined();
      return token.gubId;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        final racedMembership = await _inviteRepository.getOwnMembership(
          gubId: token.gubId,
          userId: user.uid,
        );
        if (racedMembership != null) {
          return _existingMembershipResult(
            token: token,
            userId: user.uid,
            membership: racedMembership,
          );
        }
        throw const InvalidInviteCodeException();
      }
      rethrow;
    }
  }

  Future<String> regenerateInvite({required String gubId}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated.');
    final normalizedId = gubId.trim();
    if (normalizedId.isEmpty) throw ArgumentError('Gub ID cannot be empty.');
    final cooldown = await _inviteRepository.inviteRegenerationCooldown(
      normalizedId,
    );
    if (cooldown != null) {
      throw InviteRegenerationCooldownException(cooldown.inSeconds + 1);
    }
    try {
      return reserveUniqueInviteCode<String>(
        generator: _inviteCodeGenerator,
        tryReserve: (candidate) async {
          final regenerated = await _inviteRepository.tryRegenerateInvite(
            gubId: normalizedId,
            ownerId: user.uid,
            canonicalCode: candidate,
          );
          return regenerated ? candidate : null;
        },
      );
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        final remaining = await _inviteRepository.inviteRegenerationCooldown(
          normalizedId,
        );
        if (remaining != null) {
          throw InviteRegenerationCooldownException(remaining.inSeconds + 1);
        }
      }
      rethrow;
    }
  }

  Future<String> _existingMembershipResult({
    required InviteTokenData token,
    required String userId,
    required Map<String, dynamic> membership,
  }) async {
    final role = membership['role'];
    if (membership['uid'] != userId || (role != 'owner' && role != 'member')) {
      throw StateError(
        'Your Gub membership is invalid. Please contact support.',
      );
    }
    final copy = await _inviteRepository.getOwnCopy(
      gubId: token.gubId,
      userId: userId,
    );
    if (copy == null || copy['gubId'] != token.gubId || copy['role'] != role) {
      throw StateError(
        'Your Gub membership needs recovery. Please contact support.',
      );
    }
    return token.gubId;
  }

  Stream<List<MemberOption>> membersStream(String gubId) {
    return _firestore
        .collection("gubs")
        .doc(gubId)
        .collection("members")
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();

            return MemberOption(
              userId: data["uid"] ?? "",
              userName: data["displayName"] ?? "User",
            );
          }).toList(),
        );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> rawMembersStream(String gubId) =>
      MemberRepository.instance.membersStream(gubId);

  Future<List<MemberOption>> getMembers(String gubId) async {
    final snapshot = await _firestore
        .collection("gubs")
        .doc(gubId)
        .collection("members")
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      return MemberOption(
        userId: data["uid"] ?? "",
        userName: data["displayName"] ?? "User",
      );
    }).toList();
  }
}

class InviteRegenerationCooldownException implements Exception {
  final int remainingSeconds;
  InviteRegenerationCooldownException(int seconds)
    : remainingSeconds = seconds < 1 ? 1 : seconds;

  @override
  String toString() =>
      'You can regenerate the invite again in $remainingSeconds seconds.';
}
