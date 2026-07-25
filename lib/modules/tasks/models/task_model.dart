import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String gubId;
  final String taskId;

  final String title;
  final String description;

  final String creatorId;
  final String creatorName;

  final String? assignedUserId;
  final String? assignedUserName;

  /// manual
  /// proposal
  /// chat
  /// board
  /// shopping
  /// budget
  /// goal
  final String sourceType;

  final String? sourceId;
  final String? sourcePreview;
  final String? originUserId;
  final String? sourceAuthorName;
  final String? additionalDetails;

  /// active
  /// completed
  final String status;

  /// low
  /// normal
  /// high
  final String priority;

  final Timestamp createdAt;
  final Timestamp? dueDate;

  final Timestamp? completedAt;
  final String? completedBy;

  final bool notificationsEnabled;
  final bool archived;

  const TaskModel({
    required this.gubId,
    required this.taskId,

    required this.title,
    required this.description,

    required this.creatorId,
    required this.creatorName,

    this.assignedUserId,
    this.assignedUserName,

    required this.sourceType,
    this.sourceId,
    this.sourcePreview,
    this.originUserId,
    this.sourceAuthorName,
    this.additionalDetails,

    required this.status,
    required this.priority,

    required this.createdAt,
    this.dueDate,

    this.completedAt,
    this.completedBy,

    required this.notificationsEnabled,
    required this.archived,
  });

  factory TaskModel.fromFirestore(Map<String, dynamic> json) {
    final createdAt = json["createdAt"];

    return TaskModel(
      gubId: json["gubId"] ?? "",
      taskId: json["taskId"] ?? "",

      title: json["title"] ?? "",
      description: json["description"] ?? "",

      creatorId: json["creatorId"] ?? "",
      creatorName: json["creatorName"] ?? "",

      assignedUserId: json["assignedUserId"],
      assignedUserName: json["assignedUserName"],

      sourceType: json["sourceType"] ?? "manual",
      sourceId: json["sourceId"],
      sourcePreview: json["sourcePreview"],
      originUserId: json["originUserId"],
      sourceAuthorName: json["sourceAuthorName"],
      additionalDetails: json["additionalDetails"],

      status: json["status"] ?? "active",
      priority: json["priority"] ?? "normal",

      createdAt: createdAt is Timestamp ? createdAt : Timestamp(0, 0),
      dueDate: json["dueDate"] as Timestamp?,

      completedAt: json["completedAt"] as Timestamp?,
      completedBy: json["completedBy"],

      notificationsEnabled: json["notificationsEnabled"] ?? true,

      archived: json["archived"] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      "gubId": gubId,
      "taskId": taskId,

      "title": title,
      "description": description,

      "creatorId": creatorId,
      "creatorName": creatorName,

      "assignedUserId": assignedUserId,
      "assignedUserName": assignedUserName,

      "sourceType": sourceType,
      "sourceId": sourceId,
      "sourcePreview": sourcePreview,
      "originUserId": originUserId,
      "sourceAuthorName": sourceAuthorName,
      "additionalDetails": additionalDetails,

      "status": status,
      "priority": priority,

      "createdAt": createdAt,
      "dueDate": dueDate,

      "completedAt": completedAt,
      "completedBy": completedBy,

      "notificationsEnabled": notificationsEnabled,

      "archived": archived,
    };
  }

  TaskModel copyWith({
    String? gubId,
    String? title,
    String? description,

    String? assignedUserId,
    String? assignedUserName,

    String? status,
    String? priority,

    Timestamp? dueDate,

    Timestamp? completedAt,
    String? completedBy,

    bool? notificationsEnabled,
    bool? archived,
  }) {
    return TaskModel(
      gubId: gubId ?? this.gubId,
      taskId: taskId,

      title: title ?? this.title,
      description: description ?? this.description,

      creatorId: creatorId,
      creatorName: creatorName,

      assignedUserId: assignedUserId ?? this.assignedUserId,

      assignedUserName: assignedUserName ?? this.assignedUserName,

      sourceType: sourceType,
      sourceId: sourceId,
      sourcePreview: sourcePreview,
      originUserId: originUserId,
      sourceAuthorName: sourceAuthorName,
      additionalDetails: additionalDetails,

      status: status ?? this.status,
      priority: priority ?? this.priority,

      createdAt: createdAt,
      dueDate: dueDate ?? this.dueDate,

      completedAt: completedAt ?? this.completedAt,

      completedBy: completedBy ?? this.completedBy,

      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,

      archived: archived ?? this.archived,
    );
  }
}
