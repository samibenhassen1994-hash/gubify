import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../repositories/user_repository.dart';
import '../../../services/app_sound_service.dart';
import '../models/chat_message_model.dart';
import '../repositories/chat_repository.dart';

class ChatService {
  ChatService._();

  static final ChatService instance = ChatService._();

  static const int maxMessageLength = 2000;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<ChatMessageModel>> messagesStream(String gubId) =>
      Stream.fromFuture(_membershipBoundary(gubId)).asyncExpand((boundary) {
        if (boundary == null) return Stream.value(const <ChatMessageModel>[]);
        return ChatRepository.instance.messagesStream(
          gubId: gubId,
          membershipBoundary: boundary,
        );
      });

  Future<ChatMessageModel?> getMessage({
    required String gubId,
    required String messageId,
  }) async {
    final boundary = await _membershipBoundary(gubId);
    if (boundary == null) return null;
    return ChatRepository.instance.getMessage(
      gubId: gubId,
      messageId: messageId,
      membershipBoundary: boundary,
    );
  }

  Future<Timestamp?> _membershipBoundary(String gubId) async {
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
