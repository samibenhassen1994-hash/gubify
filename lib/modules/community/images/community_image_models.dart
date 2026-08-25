class CommunityImageUploadMetadata {
  final String imageUrl;
  final String publicId;
  final int version;

  const CommunityImageUploadMetadata({
    required this.imageUrl,
    required this.publicId,
    required this.version,
  });
}

class CommunityImageUploadException implements Exception {
  final String message;

  const CommunityImageUploadException(this.message);

  @override
  String toString() => message;
}
