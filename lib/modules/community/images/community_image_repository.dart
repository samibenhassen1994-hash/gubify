import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'community_image_models.dart';

class CommunityImageRepository {
  static final CommunityImageRepository instance = CommunityImageRepository();

  static const String cloudName = 's3yauoza';
  static const String workerBaseUrl =
      'https://gubify-media-api.samibenhassen1994.workers.dev';

  final http.Client _client;

  CommunityImageRepository({http.Client? client})
    : _client = client ?? http.Client();

  Future<CommunityImageUploadMetadata> upload({
    required String communityId,
    required String idToken,
    required Uint8List jpegBytes,
  }) async {
    final expectedPublicId = 'community_$communityId';
    late final http.Response authorizationResponse;
    try {
      authorizationResponse = await _client.post(
        Uri.parse('$workerBaseUrl/sign-upload'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'communityId': communityId}),
      );
    } on http.ClientException {
      throw const CommunityImageUploadException(
        'Unable to reach the Community image service.',
      );
    }
    if (authorizationResponse.statusCode < 200 ||
        authorizationResponse.statusCode >= 300) {
      throw const CommunityImageUploadException(
        'Unable to authorize this Community image upload.',
      );
    }

    final authorization = _jsonObject(authorizationResponse.body);
    final publicId = _requiredString(authorization, 'publicId');
    final uploadPreset = _requiredString(authorization, 'uploadPreset');
    final timestamp = authorization['timestamp'];
    final overwrite = authorization['overwrite'];
    final invalidate = authorization['invalidate'];
    final uploadUrl = Uri.tryParse(_requiredString(authorization, 'uploadUrl'));
    if (authorization['cloudName'] != cloudName ||
        publicId != expectedPublicId ||
        uploadPreset != 'gubify_community_images' ||
        timestamp is! int ||
        timestamp <= 0 ||
        overwrite is! bool ||
        invalidate is! bool ||
        uploadUrl == null ||
        uploadUrl.scheme != 'https' ||
        uploadUrl.host != 'api.cloudinary.com' ||
        uploadUrl.path != '/v1_1/$cloudName/image/upload') {
      throw const CommunityImageUploadException(
        'The image upload authorization was invalid.',
      );
    }

    final request = http.MultipartRequest('POST', uploadUrl)
      ..fields.addAll({
        'api_key': _requiredString(authorization, 'apiKey'),
        'timestamp': '$timestamp',
        'signature': _requiredString(authorization, 'signature'),
        'public_id': publicId,
        'upload_preset': uploadPreset,
        'overwrite': '$overwrite',
        'invalidate': '$invalidate',
      })
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          jpegBytes,
          filename: '$publicId.jpg',
        ),
      );
    late final http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await _client.send(request);
    } on http.ClientException {
      throw const CommunityImageUploadException(
        'Unable to upload the Community image.',
      );
    }
    final uploadResponse = await http.Response.fromStream(streamedResponse);
    if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
      throw const CommunityImageUploadException(
        'Unable to upload the Community image.',
      );
    }

    final uploaded = _jsonObject(uploadResponse.body);
    final uploadedPublicId = _requiredString(uploaded, 'public_id');
    final secureUrl = _requiredString(uploaded, 'secure_url');
    final versionValue = uploaded['version'];
    final version = versionValue is int
        ? versionValue
        : versionValue is num
        ? versionValue.toInt()
        : 0;
    if (uploadedPublicId != expectedPublicId ||
        version <= 0 ||
        !_isExpectedSecureUrl(secureUrl, communityId)) {
      throw const CommunityImageUploadException(
        'Cloudinary returned unexpected image metadata.',
      );
    }
    return CommunityImageUploadMetadata(
      imageUrl: secureUrl,
      publicId: uploadedPublicId,
      version: version,
    );
  }

  static bool _isExpectedSecureUrl(String value, String communityId) {
    final escapedId = RegExp.escape(communityId);
    return RegExp(
      '^https://res\\.cloudinary\\.com/$cloudName/image/upload/'
      'v[1-9][0-9]*/community_$escapedId\\.[A-Za-z0-9]+\$',
    ).hasMatch(value);
  }

  static Map<String, dynamic> _jsonObject(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Converted to the same controlled error below.
    }
    throw const CommunityImageUploadException(
      'The image service returned an invalid response.',
    );
  }

  static String _requiredString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    throw const CommunityImageUploadException(
      'The image service returned an invalid response.',
    );
  }
}
