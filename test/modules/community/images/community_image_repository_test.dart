import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/images/community_image_models.dart';
import 'package:gubify/modules/community/images/community_image_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const communityId = 'abc123';
  const publicId = 'community_abc123';

  test('uses signed Worker fields and accepts the deterministic asset', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      if (calls == 1) {
        expect(request.url.path, '/sign-upload');
        expect(request.headers['authorization'], 'Bearer firebase-token');
        expect(jsonDecode(request.body), {'communityId': communityId});
        return http.Response(jsonEncode(_signingJson), 200);
      }
      expect(request.method, 'POST');
      expect(request.body, contains('community_abc123'));
      return http.Response(
        jsonEncode({
          'secure_url':
              'https://res.cloudinary.com/s3yauoza/image/upload/v42/$publicId.jpg',
          'public_id': publicId,
          'version': 42,
        }),
        200,
      );
    });

    final result = await CommunityImageRepository(client: client).upload(
      communityId: communityId,
      idToken: 'firebase-token',
      jpegBytes: Uint8List.fromList([1, 2, 3]),
    );

    expect(result.publicId, publicId);
    expect(result.version, 42);
    expect(calls, 2);
  });

  test('rejects an unexpected Cloudinary public id', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      if (calls == 1) {
        return http.Response(jsonEncode(_signingJson), 200);
      }
      return http.Response(
        jsonEncode({
          'secure_url':
              'https://res.cloudinary.com/s3yauoza/image/upload/v42/other.jpg',
          'public_id': 'other',
          'version': 42,
        }),
        200,
      );
    });

    expect(
      () => CommunityImageRepository(client: client).upload(
        communityId: communityId,
        idToken: 'firebase-token',
        jpegBytes: Uint8List(1),
      ),
      throwsA(isA<CommunityImageUploadException>()),
    );
  });

  test('maps a Worker rejection to a controlled upload error', () async {
    final client = MockClient(
      (_) async => http.Response(jsonEncode({'error': 'Forbidden'}), 403),
    );

    expect(
      () => CommunityImageRepository(client: client).upload(
        communityId: communityId,
        idToken: 'firebase-token',
        jpegBytes: Uint8List(1),
      ),
      throwsA(
        isA<CommunityImageUploadException>().having(
          (error) => error.message,
          'message',
          'Unable to authorize this Community image upload.',
        ),
      ),
    );
  });

  test(
    'deletes the deterministic asset through the authenticated Worker',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/delete-image');
        expect(request.headers['authorization'], 'Bearer firebase-token');
        expect(jsonDecode(request.body), {'communityId': communityId});
        return http.Response(jsonEncode({'ok': true, 'result': 'ok'}), 200);
      });

      await CommunityImageRepository(
        client: client,
      ).delete(communityId: communityId, idToken: 'firebase-token');
    },
  );

  test('treats an already missing Cloudinary asset as successful', () async {
    final client = MockClient(
      (_) async =>
          http.Response(jsonEncode({'ok': true, 'result': 'not found'}), 200),
    );

    await CommunityImageRepository(
      client: client,
    ).delete(communityId: communityId, idToken: 'firebase-token');
  });

  test('maps Worker delete failures to a controlled retryable error', () async {
    final client = MockClient(
      (_) async => http.Response(jsonEncode({'error': 'Unavailable'}), 503),
    );

    await expectLater(
      CommunityImageRepository(
        client: client,
      ).delete(communityId: communityId, idToken: 'firebase-token'),
      throwsA(
        isA<CommunityImageDeleteException>().having(
          (error) => error.message,
          'message',
          'Unable to remove the Community image. Please try again.',
        ),
      ),
    );
  });
}

const _signingJson = {
  'cloudName': 's3yauoza',
  'apiKey': 'api-key',
  'uploadPreset': 'gubify_community_images',
  'publicId': 'community_abc123',
  'timestamp': 123,
  'overwrite': true,
  'invalidate': true,
  'signature': 'signed',
  'uploadUrl': 'https://api.cloudinary.com/v1_1/s3yauoza/image/upload',
};
