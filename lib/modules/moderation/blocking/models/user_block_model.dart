import 'package:cloud_firestore/cloud_firestore.dart';

class UserBlockModel {
  const UserBlockModel({required this.blockedUserId, required this.blockedAt});

  final String blockedUserId;
  final Timestamp? blockedAt;

  factory UserBlockModel.fromFirestore(Map<String, dynamic> data) {
    final blockedUserId = data['blockedUserId'];
    if (blockedUserId is! String || blockedUserId.trim().isEmpty) {
      throw const FormatException('Invalid blocked user ID.');
    }
    return UserBlockModel(
      blockedUserId: blockedUserId.trim(),
      blockedAt: data['blockedAt'] is Timestamp
          ? data['blockedAt'] as Timestamp
          : null,
    );
  }
}
