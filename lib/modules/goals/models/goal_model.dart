import 'package:cloud_firestore/cloud_firestore.dart';

class GoalModel {
  final String goalId;
  final String title;
  final String description;

  final double targetAmount;

  /// Total confirmed contributions.
  final double currentAmount;

  final String ownerId;

  final int completedMembers;
  final int totalMembers;

  final String status;
  final bool archived;

  final Timestamp createdAt;
  final Timestamp? deadline;

  const GoalModel({
    required this.goalId,
    required this.title,
    required this.description,
    required this.targetAmount,
    required this.currentAmount,
    required this.ownerId,
    required this.completedMembers,
    required this.totalMembers,
    required this.status,
    required this.archived,
    required this.createdAt,
    this.deadline,
  });

  factory GoalModel.fromFirestore(Map<String, dynamic> json) {
    return GoalModel(
      goalId: json["goalId"] ?? "",
      title: json["title"] ?? "",
      description: json["description"] ?? "",
      targetAmount: (json["targetAmount"] ?? 0).toDouble(),
      currentAmount: (json["currentAmount"] ?? 0).toDouble(),
      ownerId: json["ownerId"] ?? "",
      completedMembers: json["completedMembers"] ?? 0,
      totalMembers: json["totalMembers"] ?? 0,
      status: json["status"] ?? "active",
      archived: json["archived"] ?? false,
      createdAt: json["createdAt"] ?? Timestamp.now(),
      deadline: json["deadline"],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      "goalId": goalId,
      "title": title,
      "description": description,
      "targetAmount": targetAmount,
      "currentAmount": currentAmount,
      "ownerId": ownerId,
      "completedMembers": completedMembers,
      "totalMembers": totalMembers,
      "status": status,
      "archived": archived,
      "createdAt": createdAt,
      "deadline": deadline,
    };
  }

  GoalModel copyWith({
    String? goalId,
    String? title,
    String? description,
    double? targetAmount,
    double? currentAmount,
    String? ownerId,
    int? completedMembers,
    int? totalMembers,
    String? status,
    bool? archived,
    Timestamp? createdAt,
    Timestamp? deadline,
  }) {
    return GoalModel(
      goalId: goalId ?? this.goalId,
      title: title ?? this.title,
      description: description ?? this.description,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      ownerId: ownerId ?? this.ownerId,
      completedMembers: completedMembers ?? this.completedMembers,
      totalMembers: totalMembers ?? this.totalMembers,
      status: status ?? this.status,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
      deadline: deadline ?? this.deadline,
    );
  }
}
