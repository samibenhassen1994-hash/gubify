import 'package:cloud_firestore/cloud_firestore.dart';

class SharedBudgetModel {
  /// Legacy Firestore field name kept for backward-compatible documents.
  static const String legacyFirestoreIdField = "goalId";

  final String sharedBudgetId;
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
  final Timestamp? completedAt;

  final String? sourceType;
  final String? sourceId;
  final String? sourcePreview;
  final String? originUserId;
  final String? sourceAuthorName;

  const SharedBudgetModel({
    required this.sharedBudgetId,
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
    this.completedAt,
    this.sourceType,
    this.sourceId,
    this.sourcePreview,
    this.originUserId,
    this.sourceAuthorName,
  });

  factory SharedBudgetModel.fromFirestore(Map<String, dynamic> json) {
    final createdAt = json["createdAt"];
    final deadline = json["deadline"];
    final completedAt = json["completedAt"];

    return SharedBudgetModel(
      sharedBudgetId: json[legacyFirestoreIdField] ?? "",
      title: json["title"] ?? "",
      description: json["description"] ?? "",
      targetAmount: (json["targetAmount"] ?? 0).toDouble(),
      currentAmount: (json["currentAmount"] ?? 0).toDouble(),
      ownerId: json["ownerId"] ?? "",
      completedMembers: json["completedMembers"] ?? 0,
      totalMembers: json["totalMembers"] ?? 0,
      status: json["status"] ?? "active",
      archived: json["archived"] ?? false,
      createdAt: createdAt is Timestamp
          ? createdAt
          : Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(0)),
      deadline: deadline is Timestamp ? deadline : null,
      completedAt: completedAt is Timestamp ? completedAt : null,
      sourceType: json["sourceType"],
      sourceId: json["sourceId"],
      sourcePreview: json["sourcePreview"],
      originUserId: json["originUserId"],
      sourceAuthorName: json["sourceAuthorName"],
    );
  }

  bool get isCompleted {
    if (status == "completed") return true;

    return targetAmount > 0 && currentAmount >= targetAmount;
  }

  Map<String, dynamic> toFirestore() {
    return {
      legacyFirestoreIdField: sharedBudgetId,
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
      "completedAt": completedAt,
      "sourceType": sourceType,
      "sourceId": sourceId,
      "sourcePreview": sourcePreview,
      "originUserId": originUserId,
      "sourceAuthorName": sourceAuthorName,
    };
  }

  SharedBudgetModel copyWith({
    String? sharedBudgetId,
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
    Timestamp? completedAt,
    String? sourceType,
    String? sourceId,
    String? sourcePreview,
    String? originUserId,
    String? sourceAuthorName,
  }) {
    return SharedBudgetModel(
      sharedBudgetId: sharedBudgetId ?? this.sharedBudgetId,
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
      completedAt: completedAt ?? this.completedAt,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      sourcePreview: sourcePreview ?? this.sourcePreview,
      originUserId: originUserId ?? this.originUserId,
      sourceAuthorName: sourceAuthorName ?? this.sourceAuthorName,
    );
  }
}
