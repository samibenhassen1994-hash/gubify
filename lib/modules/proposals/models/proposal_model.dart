import 'package:cloud_firestore/cloud_firestore.dart';

class ProposalModel {
  final String hubId;
  final String proposalId;

  final String title;
  final String description;

  final String creatorId;
  final String creatorName;

  /// voting
  /// approved
  /// rejected
  /// completed
  final String status;

  final Timestamp createdAt;
  final Timestamp expiresAt;

  /// Data dell'evento che verrà creato se approvata
  final Timestamp? eventDate;

  /// meeting
  /// trip
  /// purchase
  /// party
  /// cleaning
  /// custom
  final String type;

  final int yesVotes;
  final int noVotes;
  final int memberCount;

  /// Evita di processare due volte il risultato
  final bool resultProcessed;

  /// Flag futuri
  final bool eventCreated;
  final bool tasksCreated;

  const ProposalModel({
    required this.hubId,
    required this.proposalId,

    required this.title,
    required this.description,

    required this.creatorId,
    required this.creatorName,

    required this.status,

    required this.createdAt,
    required this.expiresAt,

    this.eventDate,

    required this.type,

    required this.yesVotes,
    required this.noVotes,
    required this.memberCount,

    required this.resultProcessed,

    required this.eventCreated,
    required this.tasksCreated,
  });

  factory ProposalModel.fromFirestore(
    Map<String, dynamic> json,
  ) {
    return ProposalModel(
      hubId: json["hubId"] ?? "",
      proposalId: json["proposalId"] ?? "",

      title: json["title"] ?? "",
      description: json["description"] ?? "",

      creatorId: json["creatorId"] ?? "",
      creatorName: json["creatorName"] ?? "",

      status: json["status"] ?? "voting",

      createdAt: json["createdAt"] as Timestamp,
      expiresAt: json["expiresAt"] as Timestamp,

      eventDate: json["eventDate"] as Timestamp?,

      type: json["type"] ?? "custom",

      yesVotes: json["yesVotes"] ?? 0,
      noVotes: json["noVotes"] ?? 0,
      memberCount: json["memberCount"] ?? 0,

      resultProcessed:
          json["resultProcessed"] ?? false,

      eventCreated:
          json["eventCreated"] ?? false,

      tasksCreated:
          json["tasksCreated"] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      "hubId": hubId,
      "proposalId": proposalId,

      "title": title,
      "description": description,

      "creatorId": creatorId,
      "creatorName": creatorName,

      "status": status,

      "createdAt": createdAt,
      "expiresAt": expiresAt,

      "eventDate": eventDate,

      "type": type,

      "yesVotes": yesVotes,
      "noVotes": noVotes,
      "memberCount": memberCount,

      "resultProcessed": resultProcessed,

      "eventCreated": eventCreated,
      "tasksCreated": tasksCreated,
    };
  }

  ProposalModel copyWith({
    String? hubId,
    String? status,
    int? yesVotes,
    int? noVotes,
    bool? resultProcessed,
    bool? eventCreated,
    bool? tasksCreated,
  }) {
    return ProposalModel(
      hubId: hubId ?? this.hubId,
      proposalId: proposalId,

      title: title,
      description: description,

      creatorId: creatorId,
      creatorName: creatorName,

      status: status ?? this.status,

      createdAt: createdAt,
      expiresAt: expiresAt,

      eventDate: eventDate,

      type: type,

      yesVotes: yesVotes ?? this.yesVotes,
      noVotes: noVotes ?? this.noVotes,
      memberCount: memberCount,

      resultProcessed:
          resultProcessed ?? this.resultProcessed,

      eventCreated:
          eventCreated ?? this.eventCreated,

      tasksCreated:
          tasksCreated ?? this.tasksCreated,
    );
  }
}