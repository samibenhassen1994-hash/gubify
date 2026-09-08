import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../config/app_limits.dart';
import '../../../repositories/user_repository.dart';
import '../../../services/app_sound_service.dart';
import '../../moderation/blocking/models/user_block_model.dart';
import '../../moderation/blocking/services/user_block_service.dart';
import '../../moderation/blocking/utils/user_block_message_visibility.dart';
import '../models/community_chat_message_model.dart';
import '../repositories/community_chat_repository.dart';

class CommunityChatService {
  CommunityChatService._({
    Future<Timestamp?> Function(String communityId)? membershipBoundary,
    Stream<List<CommunityChatMessageModel>> Function(
      String communityId,
      Timestamp boundary,
    )?
    messages,
    Stream<List<UserBlockModel>> Function()? blockedUsers,
  }) : _membershipBoundaryOverride = membershipBoundary,
       _messagesOverride = messages,
       _blockedUsersOverride = blockedUsers;

  static final CommunityChatService instance = CommunityChatService._();

  static const int maxMessageLength = AppLimits.communityMessageMaxLength;

  factory CommunityChatService.forTesting({
    required Future<Timestamp?> Function(String communityId) membershipBoundary,
    required Stream<List<CommunityChatMessageModel>> Function(
      String communityId,
      Timestamp boundary,
    )
    messages,
    required Stream<List<UserBlockModel>> Function() blockedUsers,
  }) => CommunityChatService._(
    membershipBoundary: membershipBoundary,
    messages: messages,
    blockedUsers: blockedUsers,
  );

  final Future<Timestamp?> Function(String communityId)?
  _membershipBoundaryOverride;
  final Stream<List<CommunityChatMessageModel>> Function(
    String communityId,
    Timestamp boundary,
  )?
  _messagesOverride;
  final Stream<List<UserBlockModel>> Function()? _blockedUsersOverride;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Stream<List<CommunityChatMessageModel>> messagesStream(String communityId) =>
      Stream.fromFuture(_membershipBoundary(communityId)).asyncExpand((
        boundary,
      ) {
        if (boundary == null) {
          return Stream.value(const <CommunityChatMessageModel>[]);
        }
        return filterUserBlockedMessages(
          messagesStream: _messages(communityId, boundary),
          blocksStream: _blockedUsers(),
          senderId: (message) => message.senderId,
          createdAt: (message) => message.createdAt,
        );
      });

  Future<Timestamp?> _membershipBoundary(String communityId) async {
    final override = _membershipBoundaryOverride;
    if (override != null) return override(communityId);
    final user = _auth.currentUser;
    if (user == null) return null;

    final membership = await _firestore
        .collection('communities')
        .doc(communityId)
        .collection('members')
        .doc(user.uid)
        .get(const GetOptions(source: Source.server));
    final joinedAt = membership.data()?['joinedAt'];
    return membership.exists && joinedAt is Timestamp ? joinedAt : null;
  }

  Stream<List<CommunityChatMessageModel>> _messages(
    String communityId,
    Timestamp boundary,
  ) =>
      _messagesOverride?.call(communityId, boundary) ??
      CommunityChatRepository.instance.messagesStream(
        communityId: communityId,
        membershipBoundary: boundary,
      );

  Stream<List<UserBlockModel>> _blockedUsers() =>
      _blockedUsersOverride?.call() ??
      UserBlockService.instance.blockedUsersStream();

  Future<void> sendMessage({
    required String communityId,
    required String text,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError("You must be signed in to send a message.");
    }

    final normalizedCommunityId = communityId.trim();
    if (normalizedCommunityId.isEmpty) {
      throw ArgumentError("Community ID cannot be empty.");
    }

    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      throw ArgumentError("Message cannot be empty.");
    }
    if (normalizedText.length > maxMessageLength) {
      throw ArgumentError(
        "Message cannot exceed $maxMessageLength characters.",
      );
    }

    final userData = await UserRepository.instance.getUser(user.uid);
    final storedDisplayName = userData?["displayName"];
    final senderName =
        storedDisplayName is String && storedDisplayName.trim().isNotEmpty
        ? storedDisplayName.trim()
        : user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : "User";

    await CommunityChatRepository.instance.sendMessage(
      communityId: normalizedCommunityId,
      senderId: user.uid,
      senderName: senderName,
      text: normalizedText,
    );
    await AppSoundService.instance.playMessageSent();
  }
}
