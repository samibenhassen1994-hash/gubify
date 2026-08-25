import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_model.dart';

void main() {
  test('reads Community image fields from stored data', () {
    final updatedAt = Timestamp.fromMillisecondsSinceEpoch(5000);
    final community = CommunityModel.fromData(
      documentId: 'abc123',
      data: {
        'communityId': 'abc123',
        'name': 'Photos',
        'ownerId': 'owner',
        'memberCount': 1,
        'imageUrl':
            'https://res.cloudinary.com/s3yauoza/image/upload/v9/community_abc123.jpg',
        'imagePublicId': 'community_abc123',
        'imageVersion': 9,
        'imageUpdatedAt': updatedAt,
      },
    );

    expect(community.imagePublicId, 'community_abc123');
    expect(community.imageVersion, 9);
    expect(community.imageUpdatedAt, updatedAt);
  });

  test('copyWith applies current Community image metadata', () {
    final updatedAt = Timestamp.fromMillisecondsSinceEpoch(1234);
    const community = CommunityModel(
      communityId: 'community123',
      name: 'Photography',
      ownerId: 'owner',
      memberCount: 1,
      visibility: CommunityModel.publicVisibility,
      createdAt: null,
      type: 'Art & Creativity',
      language: 'English',
      description: 'Photos',
      accessMode: CommunityModel.openAccessMode,
    );

    final updated = community.copyWith(
      imageUrl:
          'https://res.cloudinary.com/s3yauoza/image/upload/v42/community_community123.jpg',
      imagePublicId: 'community_community123',
      imageVersion: 42,
      imageUpdatedAt: updatedAt,
    );

    expect(updated.imagePublicId, 'community_community123');
    expect(updated.imageVersion, 42);
    expect(updated.imageUpdatedAt, updatedAt);
    expect(updated.toFirestore()['imageUrl'], contains('/v42/'));
  });

  test('legacy Community has no image metadata', () {
    const community = CommunityModel(
      communityId: 'legacy',
      name: 'Legacy',
      ownerId: 'owner',
      memberCount: 1,
      visibility: CommunityModel.publicVisibility,
      createdAt: null,
      type: 'General',
      language: 'English',
      description: '',
      accessMode: CommunityModel.openAccessMode,
    );

    expect(community.imageUrl, isNull);
    expect(community.imagePublicId, isNull);
    expect(community.imageVersion, isNull);
    expect(community.imageUpdatedAt, isNull);
  });
}
