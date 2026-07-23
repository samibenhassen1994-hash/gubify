import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageModel {
  final String messageId;
  final String gubId;
  final String senderId;
  final String senderName;
  final String text;
  final Timestamp createdAt;

  const ChatMessageModel({
    required this.messageId,
    required this.gubId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessageModel.fromFirestore(Map<String, dynamic> json) {
    final createdAt = json["createdAt"];

    return ChatMessageModel(
      messageId: json["messageId"] ?? "",
      gubId: json["gubId"] ?? "",
      senderId: json["senderId"] ?? "",
      senderName: json["senderName"] ?? "User",
      text: json["text"] ?? "",
      createdAt: createdAt is Timestamp ? createdAt : Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      "messageId": messageId,
      "gubId": gubId,
      "senderId": senderId,
      "senderName": senderName,
      "text": text,
      "createdAt": createdAt,
    };
  }
}
