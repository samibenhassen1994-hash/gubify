import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/community_model.dart';
import '../repositories/community_repository.dart';
import 'community_image_models.dart';
import 'community_image_processor.dart';
import 'community_image_repository.dart';

const int communityImageMaxOriginalBytes = 20 * 1024 * 1024;

class CommunityImageSelection {
  final int length;
  final Future<Uint8List> Function() readBytes;

  const CommunityImageSelection({
    required this.length,
    required this.readBytes,
  });
}

typedef CommunityImagePicker = Future<CommunityImageSelection?> Function();
typedef CommunityImageTokenProvider = Future<String?> Function();
typedef CommunityImageProcessor = Future<Uint8List> Function(Uint8List bytes);
typedef CommunityImageUploader =
    Future<CommunityImageUploadMetadata> Function({
      required String communityId,
      required String idToken,
      required Uint8List jpegBytes,
    });
typedef CommunityImagePublisher =
    Future<void> Function({
      required String communityId,
      required CommunityImageUploadMetadata metadata,
    });
typedef CommunityImageDeleteAction =
    Future<void> Function({
      required String communityId,
      required String idToken,
    });
typedef CommunityImageMetadataRemover =
    Future<void> Function({required String communityId});

class CommunityImageService {
  static final CommunityImageService instance = CommunityImageService();

  final CommunityImagePicker _pickImage;
  final CommunityImageTokenProvider _getIdToken;
  final CommunityImageProcessor _processImage;
  final CommunityImageUploader _uploadImage;
  final CommunityImagePublisher _persistImage;
  final CommunityImageDeleteAction _deleteImage;
  final CommunityImageMetadataRemover _removePersistedImage;

  CommunityImageService({
    CommunityImagePicker? pickImage,
    CommunityImageTokenProvider? getIdToken,
    CommunityImageProcessor? processImage,
    CommunityImageUploader? uploadImage,
    CommunityImagePublisher? persistImage,
    CommunityImageDeleteAction? deleteImage,
    CommunityImageMetadataRemover? removePersistedImage,
  }) : _pickImage = pickImage ?? _defaultPickImage,
       _getIdToken = getIdToken ?? _defaultGetIdToken,
       _processImage = processImage ?? _defaultProcessImage,
       _uploadImage = uploadImage ?? CommunityImageRepository.instance.upload,
       _persistImage = persistImage ?? _defaultPersistImage,
       _deleteImage = deleteImage ?? CommunityImageRepository.instance.delete,
       _removePersistedImage =
           removePersistedImage ?? _defaultRemovePersistedImage;

  Future<CommunityModel?> pickAndUpload(CommunityModel community) async {
    final selection = await _pickImage();
    if (selection == null) return null;
    if (selection.length > communityImageMaxOriginalBytes) {
      throw const CommunityImageUploadException(
        'Choose an image smaller than 20 MiB.',
      );
    }

    final idToken = await _getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const CommunityImageUploadException(
        'Sign in again before uploading a Community image.',
      );
    }
    final sourceBytes = await selection.readBytes();
    final jpegBytes = await _processImage(sourceBytes);
    final metadata = await _uploadImage(
      communityId: community.communityId,
      idToken: idToken,
      jpegBytes: jpegBytes,
    );
    try {
      await _persistImage(
        communityId: community.communityId,
        metadata: metadata,
      );
    } on FirebaseException {
      throw const CommunityImageUploadException(
        'The image was uploaded but could not be saved. Please try again.',
      );
    }
    return community.copyWith(
      imageUrl: metadata.imageUrl,
      imagePublicId: metadata.publicId,
      imageVersion: metadata.version,
    );
  }

  Future<CommunityModel> removeImage(CommunityModel community) async {
    final idToken = await _getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const CommunityImageDeleteException(
        'Sign in again before removing the Community image.',
      );
    }
    await _deleteImage(communityId: community.communityId, idToken: idToken);
    try {
      await _removePersistedImage(communityId: community.communityId);
    } on FirebaseException {
      throw const CommunityImageDeleteException(
        'The image was removed but the Community could not be updated. Please try again.',
      );
    } on StateError {
      throw const CommunityImageDeleteException(
        'The image was removed but the Community could not be updated. Please try again.',
      );
    }
    return community.withoutImage();
  }

  Future<void> deleteCloudinaryAsset(String communityId) async {
    final idToken = await _getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const CommunityImageDeleteException(
        'Sign in again before removing the Community image.',
      );
    }
    await _deleteImage(communityId: communityId, idToken: idToken);
  }

  static Future<CommunityImageSelection?> _defaultPickImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    return CommunityImageSelection(
      length: await file.length(),
      readBytes: file.readAsBytes,
    );
  }

  static Future<String?> _defaultGetIdToken() async =>
      FirebaseAuth.instance.currentUser?.getIdToken();

  static Future<Uint8List> _defaultProcessImage(Uint8List bytes) =>
      compute(processCommunityImageBytes, bytes);

  static Future<void> _defaultPersistImage({
    required String communityId,
    required CommunityImageUploadMetadata metadata,
  }) => CommunityRepository.instance.updateCommunityImage(
    communityId: communityId,
    metadata: metadata,
  );

  static Future<void> _defaultRemovePersistedImage({
    required String communityId,
  }) => CommunityRepository.instance.removeCommunityImage(
    communityId: communityId,
  );
}
