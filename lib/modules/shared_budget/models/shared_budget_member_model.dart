import 'package:cloud_firestore/cloud_firestore.dart';

class SharedBudgetMemberModel {
  final String uid;
  final String displayName;
  final String? photoUrl;

  /// Amount entered by the member.
  final double amount;

  /// Confirmed by the Hub owner.
  final bool confirmed;

  final Timestamp updatedAt;
  final Timestamp? confirmedAt;

  const SharedBudgetMemberModel({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    required this.amount,
    required this.confirmed,
    required this.updatedAt,
    this.confirmedAt,
  });

  factory SharedBudgetMemberModel.fromFirestore(Map<String, dynamic> json) {
    return SharedBudgetMemberModel(
      uid: json["uid"] ?? "",
      displayName: json["displayName"] ?? "",
      photoUrl: json["photoUrl"],
      amount: (json["amount"] ?? 0).toDouble(),
      confirmed: json["confirmed"] ?? false,
      updatedAt: json["updatedAt"] ?? Timestamp.now(),
      confirmedAt: json["confirmedAt"],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      "uid": uid,
      "displayName": displayName,
      "photoUrl": photoUrl,
      "amount": amount,
      "confirmed": confirmed,
      "updatedAt": updatedAt,
      "confirmedAt": confirmedAt,
    };
  }

  SharedBudgetMemberModel copyWith({
    String? uid,
    String? displayName,
    String? photoUrl,
    double? amount,
    bool? confirmed,
    Timestamp? updatedAt,
    Timestamp? confirmedAt,
  }) {
    return SharedBudgetMemberModel(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      amount: amount ?? this.amount,
      confirmed: confirmed ?? this.confirmed,
      updatedAt: updatedAt ?? this.updatedAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
    );
  }
}
