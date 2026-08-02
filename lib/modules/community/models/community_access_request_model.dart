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

  const CommunityAccessRequestModel({
    required this.userId,
    required this.displayName,
    required this.status,
    required this.createdAt,
  });

  factory CommunityAccessRequestModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return CommunityAccessRequestModel(
      userId: data["userId"] as String? ?? document.id,
      displayName: data["displayName"] as String? ?? "User",
      status: data["status"] as String? ?? pendingStatus,
      createdAt: data["createdAt"] as Timestamp?,
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
