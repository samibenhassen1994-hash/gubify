import 'package:cloud_firestore/cloud_firestore.dart';

import 'community_model.dart';

class CommunityAccessRequestModel {
  static const String pendingStatus = "pending";
  static const String approvedStatus = "approved";
  static const String rejectedStatus = "rejected";

  final String userId;
  final String displayName;
  final String status;
  final Timestamp? createdAt;
  final Timestamp? requestedAt;

  const CommunityAccessRequestModel({
    required this.userId,
    required this.displayName,
    required this.status,
    required this.createdAt,
    this.requestedAt,
  });

  factory CommunityAccessRequestModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) => CommunityAccessRequestModel.fromMap(document.id, document.data());

  /// Parse Firestore fields without implementing the sealed snapshot class in tests.
  factory CommunityAccessRequestModel.fromMap(
    String documentId,
    Map<String, dynamic>? data,
  ) {
    final fields = data ?? const <String, dynamic>{};
    return CommunityAccessRequestModel(
      userId: fields["userId"] as String? ?? documentId,
      displayName: fields["displayName"] as String? ?? "User",
      status: fields["status"] as String? ?? pendingStatus,
      createdAt: fields["createdAt"] as Timestamp?,
      requestedAt: fields["requestedAt"] as Timestamp?,
    );
  }
}

class CommunityPublicAccessState {
  final CommunityModel community;
  final bool isMember;
  final bool isOwner;
  final CommunityAccessRequestModel? request;

  const CommunityPublicAccessState({
    required this.community,
    required this.isMember,
    required this.isOwner,
    required this.request,
  });
}
