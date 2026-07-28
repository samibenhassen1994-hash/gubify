import 'package:cloud_firestore/cloud_firestore.dart';

class GubEventAssignment {
  final String userId;
  final String userName;
  final String taskText;
  final bool isCompleted;
  final Timestamp? completedAt;

  const GubEventAssignment({
    required this.userId,
    required this.userName,
    required this.taskText,
    required this.isCompleted,
    this.completedAt,
  });

  factory GubEventAssignment.fromFirestore(Map<String, dynamic> json) =>
      GubEventAssignment(
        userId: json['userId'] ?? '',
        userName: json['userName'] ?? 'User',
        taskText: json['taskText'] ?? '',
        isCompleted: json['isCompleted'] ?? false,
        completedAt: json['completedAt'] as Timestamp?,
      );
  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'userName': userName,
    'taskText': taskText,
    'isCompleted': isCompleted,
    'completedAt': completedAt,
  };
}

class GubEventModel {
  final String eventId, gubId, title, createdBy, status;
  final String? description, location, createdByName;
  final Timestamp createdAt;
  final Timestamp? scheduledAt, completedAt;
  final List<GubEventAssignment> assignments;
  const GubEventModel({
    required this.eventId,
    required this.gubId,
    required this.title,
    this.description,
    this.location,
    this.scheduledAt,
    required this.createdBy,
    this.createdByName,
    required this.createdAt,
    required this.status,
    this.completedAt,
    required this.assignments,
  });
  factory GubEventModel.fromFirestore(Map<String, dynamic> json) =>
      GubEventModel(
        eventId: json['eventId'] ?? '',
        gubId: json['gubId'] ?? '',
        title: json['title'] ?? '',
        description: json['description'],
        location: json['location'],
        scheduledAt: json['scheduledAt'] as Timestamp?,
        createdBy: json['createdBy'] ?? '',
        createdByName: json['createdByName'],
        createdAt: json['createdAt'] as Timestamp? ?? Timestamp(0, 0),
        status: json['status'] ?? 'active',
        completedAt: json['completedAt'] as Timestamp?,
        assignments: ((json['assignments'] as List?) ?? const [])
            .map(
              (value) => GubEventAssignment.fromFirestore(
                Map<String, dynamic>.from(value as Map),
              ),
            )
            .toList(),
      );
  Map<String, dynamic> toFirestore() => {
    'eventId': eventId,
    'gubId': gubId,
    'title': title,
    'description': description,
    'location': location,
    'scheduledAt': scheduledAt,
    'createdBy': createdBy,
    'createdByName': createdByName,
    'createdAt': createdAt,
    'status': status,
    'completedAt': completedAt,
    'assignments': assignments.map((item) => item.toFirestore()).toList(),
  };
  int get completedCount =>
      assignments.where((item) => item.isCompleted).length;
}
