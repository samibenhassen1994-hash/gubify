import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityChatMessageModel {
  final String messageId;
  final String communityId;
  final String senderId;
  final String senderName;
  final String text;
  final Timestamp createdAt;

  const CommunityChatMessageModel({
    required this.messageId,
    required this.communityId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
  });

  factory CommunityChatMessageModel.fromFirestore(Map<String, dynamic> json) {
    final createdAt = json["createdAt"];

    return CommunityChatMessageModel(
      messageId: json["messageId"] as String? ?? "",
      communityId: json["communityId"] as String? ?? "",
      senderId: json["senderId"] as String? ?? "",
      senderName: json["senderName"] as String? ?? "User",
      text: json["text"] as String? ?? "",
      createdAt: createdAt is Timestamp ? createdAt : Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      "messageId": messageId,
      "communityId": communityId,
      "senderId": senderId,
      "senderName": senderName,
      "text": text,
      "createdAt": createdAt,
    };
  }
}
