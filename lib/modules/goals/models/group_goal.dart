class GroupGoal {
  final String id;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final bool active;
  final String createdBy;
  final DateTime createdAt;

  const GroupGoal({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    required this.active,
    required this.createdBy,
    required this.createdAt,
  });

  double get progress {
    if (targetAmount <= 0) return 0;
    return (currentAmount / targetAmount).clamp(0.0, 1.0);
  }

  int get progressPercentage => (progress * 100).round();

  factory GroupGoal.fromMap(String id, Map<String, dynamic> map) {
    return GroupGoal(
      id: id,
      title: map['title'] ?? '',
      targetAmount: (map['targetAmount'] ?? 0).toDouble(),
      currentAmount: (map['currentAmount'] ?? 0).toDouble(),
      active: map['active'] ?? true,
      createdBy: map['createdBy'] ?? '',
      createdAt:
          DateTime.tryParse(map['createdAt'] ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'active': active,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  GroupGoal copyWith({
    String? id,
    String? title,
    double? targetAmount,
    double? currentAmount,
    bool? active,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return GroupGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      active: active ?? this.active,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
