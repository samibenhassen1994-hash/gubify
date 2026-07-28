import 'package:firebase_auth/firebase_auth.dart';

import '../../../repositories/user_repository.dart';
import '../models/community_chat_message_model.dart';
import '../repositories/community_chat_repository.dart';

class CommunityChatService {
  CommunityChatService._();

  static final CommunityChatService instance = CommunityChatService._();

  static const int maxMessageLength = 2000;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<CommunityChatMessageModel>> messagesStream(String communityId) {
    return CommunityChatRepository.instance.messagesStream(communityId);
  }

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
  }
}
