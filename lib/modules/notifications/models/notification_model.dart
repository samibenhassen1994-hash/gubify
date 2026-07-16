import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String notificationId;

  final String title;
  final String body;

  final String type;

  final String senderId;
  final String senderName;

  final Timestamp createdAt;

  final List<String> readBy;

  final Map<String, dynamic> data;

  const NotificationModel({
    required this.notificationId,
    required this.title,
    required this.body,
    required this.type,
    required this.senderId,
    required this.senderName,
    required this.createdAt,
    required this.readBy,
    required this.data,
  });

  factory NotificationModel.fromFirestore(Map<String, dynamic> json) {
    return NotificationModel(
      notificationId: json["notificationId"] ?? "",
      title: json["title"] ?? "",
      body: json["body"] ?? "",
      type: json["type"] ?? "",
      senderId: json["senderId"] ?? "",
      senderName: json["senderName"] ?? "",
      createdAt: json["createdAt"] ?? Timestamp.now(),
      readBy: List<String>.from(json["readBy"] ?? []),
      data: Map<String, dynamic>.from(json["data"] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      "notificationId": notificationId,
      "title": title,
      "body": body,
      "type": type,
      "senderId": senderId,
      "senderName": senderName,
      "createdAt": createdAt,
      "readBy": readBy,
      "data": data,
    };
  }
}
