import 'package:cloud_firestore/cloud_firestore.dart';

class GlobalPushNotification {
  const GlobalPushNotification({
    required this.id,
    required this.eventKey,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
    required this.data,
    this.actorId,
  });

  final String id;
  final String eventKey;
  final String type;
  final String title;
  final String body;
  final Timestamp? createdAt;
  final bool read;
  final String? actorId;
  final Map<String, String> data;

  factory GlobalPushNotification.fromFirestore(
    String id,
    Map<String, dynamic> value,
  ) => GlobalPushNotification(
    id: id,
    eventKey: value['eventKey'] as String? ?? '',
    type: value['type'] as String? ?? '',
    title: value['title'] as String? ?? '',
    body: value['body'] as String? ?? '',
    createdAt: value['createdAt'] as Timestamp?,
    read: value['read'] == true,
    actorId: value['actorId'] as String?,
    data: (value['data'] as Map<String, dynamic>? ?? const {}).map(
      (key, entry) => MapEntry(key, entry.toString()),
    ),
  );
}
