import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String hubId;
  final String eventId;

  /// Proposal da cui nasce l'evento
  final String proposalId;

  final String title;
  final String description;

  /// meeting
  /// trip
  /// purchase
  /// party
  /// cleaning
  /// custom
  final String type;

  final String creatorId;
  final String creatorName;

  final Timestamp eventDate;
  final Timestamp createdAt;

  /// future:
  /// completed / cancelled
  final String status;

  const EventModel({
    required this.hubId,
    required this.eventId,
    required this.proposalId,
    required this.title,
    required this.description,
    required this.type,
    required this.creatorId,
    required this.creatorName,
    required this.eventDate,
    required this.createdAt,
    required this.status,
  });

  factory EventModel.fromFirestore(Map<String, dynamic> json) {
    return EventModel(
      hubId: json["hubId"] ?? "",
      eventId: json["eventId"] ?? "",
      proposalId: json["proposalId"] ?? "",
      title: json["title"] ?? "",
      description: json["description"] ?? "",
      type: json["type"] ?? "custom",
      creatorId: json["creatorId"] ?? "",
      creatorName: json["creatorName"] ?? "",
      eventDate: json["eventDate"] as Timestamp,
      createdAt: json["createdAt"] as Timestamp,
      status: json["status"] ?? "scheduled",
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      "hubId": hubId,
      "eventId": eventId,
      "proposalId": proposalId,
      "title": title,
      "description": description,
      "type": type,
      "creatorId": creatorId,
      "creatorName": creatorName,
      "eventDate": eventDate,
      "createdAt": createdAt,
      "status": status,
    };
  }

  EventModel copyWith({String? status, Timestamp? eventDate}) {
    return EventModel(
      hubId: hubId,
      eventId: eventId,
      proposalId: proposalId,
      title: title,
      description: description,
      type: type,
      creatorId: creatorId,
      creatorName: creatorName,
      eventDate: eventDate ?? this.eventDate,
      createdAt: createdAt,
      status: status ?? this.status,
    );
  }
}
