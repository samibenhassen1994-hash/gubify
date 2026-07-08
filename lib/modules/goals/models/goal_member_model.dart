import 'package:cloud_firestore/cloud_firestore.dart';

class GoalMemberModel {
  final String uid;
  final String displayName;
  final bool paid;
  final Timestamp? paidAt;

  const GoalMemberModel({
    required this.uid,
    required this.displayName,
    required this.paid,
    this.paidAt,
  });

  factory GoalMemberModel.fromFirestore(
    Map<String, dynamic> json,
  ) {
    return GoalMemberModel(
      uid: json["uid"] ?? "",
      displayName: json["displayName"] ?? "",
      paid: json["paid"] ?? false,
      paidAt: json["paidAt"],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      "uid": uid,
      "displayName": displayName,
      "paid": paid,
      "paidAt": paidAt,
    };
  }
}