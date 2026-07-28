import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/community_chat_message_model.dart';

class CommunityChatRepository {
  CommunityChatRepository._();

  static final CommunityChatRepository instance = CommunityChatRepository._();

  static const int _messageLimit = 50;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> messagesCollection(
    String communityId,
  ) {
    return _firestore
        .collection("communities")
        .doc(communityId)
        .collection("messages");
  }

  Future<void> sendMessage({
    required String communityId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    final messageReference = messagesCollection(communityId).doc();
    final message = CommunityChatMessageModel(
      messageId: messageReference.id,
      communityId: communityId,
      senderId: senderId,
      senderName: senderName,
      text: text,
      createdAt: Timestamp.now(),
    );
    final data = message.toFirestore()
      ..["createdAt"] = FieldValue.serverTimestamp();

    await messageReference.set(data);
  }

  Stream<List<CommunityChatMessageModel>> messagesStream(String communityId) {
    return messagesCollection(communityId)
        .orderBy("createdAt", descending: true)
        .limit(_messageLimit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((document) {
                final data = Map<String, dynamic>.from(document.data());
                data["messageId"] = document.id;

                return CommunityChatMessageModel.fromFirestore(data);
              })
              .toList(growable: false)
              .reversed
              .toList(growable: false),
        );
  }
}
