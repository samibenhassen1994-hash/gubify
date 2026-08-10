import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../repositories/gub_repository.dart';
import '../models/chat_message_model.dart';

class ChatRepository {
  ChatRepository._();

  static final ChatRepository instance = ChatRepository._();

  static const int _messageLimit = 50;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> messagesCollection(String gubId) {
    return _firestore.collection("gubs").doc(gubId).collection("messages");
  }

  Future<void> sendMessage({
    required String gubId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    await GubRepository.instance.ensureActive(gubId);
    final messageReference = messagesCollection(gubId).doc();
    final message = ChatMessageModel(
      messageId: messageReference.id,
      gubId: gubId,
      senderId: senderId,
      senderName: senderName,
      text: text,
      createdAt: Timestamp.now(),
    );
    final data = message.toFirestore()
      ..["createdAt"] = FieldValue.serverTimestamp();

    await messageReference.set(data);
  }

  Stream<List<ChatMessageModel>> messagesStream({
    required String gubId,
    required Timestamp membershipBoundary,
  }) {
    return messagesCollection(gubId)
        .where("createdAt", isGreaterThanOrEqualTo: membershipBoundary)
        .orderBy("createdAt", descending: true)
        .limit(_messageLimit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((document) {
                final data = Map<String, dynamic>.from(document.data());
                data["messageId"] = document.id;

                return ChatMessageModel.fromFirestore(data);
              })
              .toList(growable: false)
              .reversed
              .toList(growable: false),
        );
  }

  Future<ChatMessageModel?> getMessage({
    required String gubId,
    required String messageId,
    required Timestamp membershipBoundary,
  }) async {
    final document = await messagesCollection(gubId).doc(messageId).get();
    if (!document.exists) return null;

    final data = Map<String, dynamic>.from(document.data()!);
    data["messageId"] = document.id;
    final message = ChatMessageModel.fromFirestore(data);
    return _isOnOrAfter(message.createdAt, membershipBoundary) ? message : null;
  }

  bool _isOnOrAfter(Timestamp value, Timestamp boundary) =>
      value.seconds > boundary.seconds ||
      (value.seconds == boundary.seconds &&
          value.nanoseconds >= boundary.nanoseconds);
}
