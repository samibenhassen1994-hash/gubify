import 'package:cloud_firestore/cloud_firestore.dart';

class AccountDetailsModel {
  const AccountDetailsModel({
    required this.displayName,
    this.createdAt,
    this.displayNameChangedAt,
  });

  final String displayName;
  final Timestamp? createdAt;
  final Timestamp? displayNameChangedAt;

  factory AccountDetailsModel.fromFirestore(Map<String, dynamic> data) {
    return AccountDetailsModel(
      displayName: (data['displayName'] as String?)?.trim() ?? 'User',
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : null,
      displayNameChangedAt: data['displayNameChangedAt'] is Timestamp
          ? data['displayNameChangedAt'] as Timestamp
          : null,
    );
  }
}
