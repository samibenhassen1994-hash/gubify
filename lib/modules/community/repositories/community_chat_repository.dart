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
    final communityReference = _firestore
        .collection("communities")
        .doc(communityId);
    final messageReference = communityReference.collection("messages").doc();
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

    final canSend = await _firestore.runTransaction<bool>((transaction) async {
      final community = await transaction.get(communityReference);
      if (!community.exists ||
          community.data()?["deletionStatus"] == "deleting") {
        return false;
      }
      transaction.set(messageReference, data);
      return true;
    });
    if (!canSend) throw StateError("This Community is being deleted.");
  }

  Stream<List<CommunityChatMessageModel>> messagesStream({
    required String communityId,
    required Timestamp membershipBoundary,
  }) {
    return messagesCollection(communityId)
        .where('createdAt', isGreaterThanOrEqualTo: membershipBoundary)
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
