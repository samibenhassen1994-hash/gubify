import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../repositories/user_repository.dart';
import '../../../services/gub_service.dart';
import '../../../services/app_sound_service.dart';
import '../models/chat_message_model.dart';
import '../repositories/chat_repository.dart';

class ChatService {
  ChatService._();

  static final ChatService instance = ChatService._();

  static const int maxMessageLength = 2000;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<ChatMessageModel>> messagesStream(String gubId) {
    return _withMembershipBoundary(
      gubId,
      (boundary) => ChatRepository.instance.messagesStream(
        gubId: gubId,
        membershipBoundary: boundary,
      ),
    );
  }

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

  Stream<List<ChatMessageModel>> _withMembershipBoundary(
    String gubId,
    Stream<List<ChatMessageModel>> Function(Timestamp boundary) build,
  ) async* {
    final boundary = await _membershipBoundary(gubId);
    if (boundary == null) {
      yield const <ChatMessageModel>[];
      return;
    }
    yield* build(boundary);
  }

  Future<Timestamp?> _membershipBoundary(String gubId) async {
    final boundary = await GubService().currentMembershipHistoryBoundary(gubId);
    return boundary?.membershipStartedAt;
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
