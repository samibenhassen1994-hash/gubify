import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../repositories/user_repository.dart';
import '../../../services/app_sound_service.dart';
import '../../moderation/blocking/models/user_block_model.dart';
import '../../moderation/blocking/services/user_block_service.dart';
import '../../moderation/blocking/utils/user_block_message_visibility.dart';
import '../models/chat_message_model.dart';
import '../repositories/chat_repository.dart';

class ChatService {
  ChatService._({
    Future<Timestamp?> Function(String gubId)? membershipBoundary,
    Stream<List<ChatMessageModel>> Function(String gubId, Timestamp boundary)?
    messages,
    Future<ChatMessageModel?> Function(
      String gubId,
      String messageId,
      Timestamp boundary,
    )?
    getMessage,
    Stream<List<UserBlockModel>> Function()? blockedUsers,
  }) : _membershipBoundaryOverride = membershipBoundary,
       _messagesOverride = messages,
       _getMessageOverride = getMessage,
       _blockedUsersOverride = blockedUsers;

  static final ChatService instance = ChatService._();

  static const int maxMessageLength = 2000;

  factory ChatService.forTesting({
    required Future<Timestamp?> Function(String gubId) membershipBoundary,
    required Stream<List<ChatMessageModel>> Function(
      String gubId,
      Timestamp boundary,
    )
    messages,
    required Future<ChatMessageModel?> Function(
      String gubId,
      String messageId,
      Timestamp boundary,
    )
    getMessage,
    required Stream<List<UserBlockModel>> Function() blockedUsers,
  }) => ChatService._(
    membershipBoundary: membershipBoundary,
    messages: messages,
    getMessage: getMessage,
    blockedUsers: blockedUsers,
  );

  final Future<Timestamp?> Function(String gubId)? _membershipBoundaryOverride;
  final Stream<List<ChatMessageModel>> Function(
    String gubId,
    Timestamp boundary,
  )?
  _messagesOverride;
  final Future<ChatMessageModel?> Function(
    String gubId,
    String messageId,
    Timestamp boundary,
  )?
  _getMessageOverride;
  final Stream<List<UserBlockModel>> Function()? _blockedUsersOverride;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Stream<List<ChatMessageModel>> messagesStream(String gubId) =>
      Stream.fromFuture(_membershipBoundary(gubId)).asyncExpand((boundary) {
        if (boundary == null) return Stream.value(const <ChatMessageModel>[]);
        return filterUserBlockedMessages(
          messagesStream: _messages(gubId, boundary),
          blocksStream: _blockedUsers(),
          senderId: (message) => message.senderId,
          createdAt: (message) => message.createdAt,
        );
      });

  Future<ChatMessageModel?> getMessage({
    required String gubId,
    required String messageId,
  }) async {
    final boundary = await _membershipBoundary(gubId);
    if (boundary == null) return null;
    final message = await _getMessage(gubId, messageId, boundary);
    if (message == null) return null;
    final blocks = await _blockedUsers().first;
    return isUserBlockMessageVisible(
          senderId: message.senderId,
          createdAt: message.createdAt,
          blockedAtByUser: blockedAtByUser(blocks),
        )
        ? message
        : null;
  }

  Future<Timestamp?> _membershipBoundary(String gubId) async {
    final override = _membershipBoundaryOverride;
    if (override != null) return override(gubId);
    final user = _auth.currentUser;
    if (user == null) return null;
    final membership = await _firestore
        .collection('gubs')
        .doc(gubId)
        .collection('members')
        .doc(user.uid)
        .get(const GetOptions(source: Source.server));
    final joinedAt = membership.data()?['joinedAt'];
    return membership.exists && joinedAt is Timestamp ? joinedAt : null;
  }

  Stream<List<ChatMessageModel>> _messages(String gubId, Timestamp boundary) =>
      _messagesOverride?.call(gubId, boundary) ??
      ChatRepository.instance.messagesStream(
        gubId: gubId,
        membershipBoundary: boundary,
      );

  Future<ChatMessageModel?> _getMessage(
    String gubId,
    String messageId,
    Timestamp boundary,
  ) =>
      _getMessageOverride?.call(gubId, messageId, boundary) ??
      ChatRepository.instance.getMessage(
        gubId: gubId,
        messageId: messageId,
        membershipBoundary: boundary,
      );

  Stream<List<UserBlockModel>> _blockedUsers() =>
      _blockedUsersOverride?.call() ??
      UserBlockService.instance.blockedUsersStream();

  Future<void> sendMessage({
    required String gubId,
    required String text,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError("You must be signed in to send a message.");
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
    final senderName = userData?["displayName"] ?? user.displayName ?? "User";

    await ChatRepository.instance.sendMessage(
      gubId: gubId,
      senderId: user.uid,
      senderName: senderName,
      text: normalizedText,
    );
    await AppSoundService.instance.playMessageSent();
  }
}
