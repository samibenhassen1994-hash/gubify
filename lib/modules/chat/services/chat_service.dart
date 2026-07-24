import 'package:firebase_auth/firebase_auth.dart';

import '../../../repositories/user_repository.dart';
import '../models/chat_message_model.dart';
import '../repositories/chat_repository.dart';

class ChatService {
  ChatService._();

  static final ChatService instance = ChatService._();

  static const int maxMessageLength = 2000;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<ChatMessageModel>> messagesStream(String gubId) {
    return ChatRepository.instance.messagesStream(gubId);
  }

  Future<ChatMessageModel?> getMessage({
    required String gubId,
    required String messageId,
  }) {
    return ChatRepository.instance.getMessage(
      gubId: gubId,
      messageId: messageId,
    );
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
  }
}
