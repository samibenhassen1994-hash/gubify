import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/images/community_image_models.dart';
import 'package:gubify/modules/community/images/community_image_service.dart';
import 'package:gubify/modules/community/models/community_model.dart';

const _community = CommunityModel(
  communityId: 'abc123',
  name: 'Photos',
  ownerId: 'owner',
  memberCount: 1,
  visibility: CommunityModel.publicVisibility,
  createdAt: null,
  type: 'Art & Creativity',
  language: 'English',
  description: '',
  accessMode: CommunityModel.openAccessMode,
);

void main() {
  test('rejects an original above 20 MiB before reading it', () async {
    var readCalls = 0;
    final service = CommunityImageService(
      pickImage: () async => CommunityImageSelection(
        length: communityImageMaxOriginalBytes + 1,
        readBytes: () async {
          readCalls++;
          return Uint8List(1);
        },
      ),
      getIdToken: () async => 'token',
    );

    await expectLater(
      service.pickAndUpload(_community),
      throwsA(
        isA<CommunityImageUploadException>().having(
          (error) => error.message,
          'message',
          'Choose an image smaller than 20 MiB.',
        ),
      ),
    );
    expect(readCalls, 0);
  });

  test('publishes Cloudinary metadata and returns updated Community', () async {
    CommunityImageUploadMetadata? persisted;
    final service = CommunityImageService(
      pickImage: () async => CommunityImageSelection(
        length: 3,
        readBytes: () async => Uint8List.fromList([1, 2, 3]),
      ),
      getIdToken: () async => 'token',
      processImage: (bytes) async => Uint8List.fromList([8, 2]),
      uploadImage:
          ({required communityId, required idToken, required jpegBytes}) async {
            expect(communityId, 'abc123');
            expect(idToken, 'token');
            expect(jpegBytes, [8, 2]);
            return const CommunityImageUploadMetadata(
              imageUrl:
                  'https://res.cloudinary.com/s3yauoza/image/upload/v7/community_abc123.jpg',
              publicId: 'community_abc123',
              version: 7,
            );
          },
      persistImage: ({required communityId, required metadata}) async {
        persisted = metadata;
      },
    );

    final updated = await service.pickAndUpload(_community);

    expect(persisted?.version, 7);
    expect(updated?.imageUrl, contains('/v7/'));
  });

  test('picker cancellation returns null without requesting a token', () async {
    var tokenCalls = 0;
    final service = CommunityImageService(
      pickImage: () async => null,
      getIdToken: () async {
        tokenCalls++;
        return 'token';
      },
    );

    expect(await service.pickAndUpload(_community), isNull);
    expect(tokenCalls, 0);
  });

  test('removes Cloudinary asset before clearing Firestore metadata', () async {
    final calls = <String>[];
    final service = CommunityImageService(
      getIdToken: () async => 'token',
      deleteImage: ({required communityId, required idToken}) async {
        calls.add('worker:$communityId:$idToken');
      },
      removePersistedImage: ({required communityId}) async {
        calls.add('firestore:$communityId');
      },
    );
    final withImage = _community.copyWith(
      imageUrl:
          'https://res.cloudinary.com/s3yauoza/image/upload/v7/community_abc123.jpg',
      imagePublicId: 'community_abc123',
      imageVersion: 7,
    );

    final updated = await service.removeImage(withImage);

    expect(calls, ['worker:abc123:token', 'firestore:abc123']);
    expect(updated.imageUrl, isNull);
    expect(updated.imagePublicId, isNull);
    expect(updated.imageVersion, isNull);
  });

  test(
    'does not clear Firestore metadata when Worker deletion fails',
    () async {
      var firestoreCalls = 0;
      final service = CommunityImageService(
        getIdToken: () async => 'token',
        deleteImage: ({required communityId, required idToken}) async {
          throw const CommunityImageDeleteException('retry');
        },
        removePersistedImage: ({required communityId}) async {
          firestoreCalls++;
        },
      );

      await expectLater(
        service.removeImage(_community),
        throwsA(isA<CommunityImageDeleteException>()),
      );
      expect(firestoreCalls, 0);
    },
  );
}
