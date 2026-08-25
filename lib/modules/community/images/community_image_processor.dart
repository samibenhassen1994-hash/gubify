import 'dart:typed_data';

import 'package:image/image.dart' as image;

const int communityImageDimension = 512;
const int communityImageJpegQuality = 82;

class CommunityImageProcessingException implements Exception {
  final String message;

  const CommunityImageProcessingException(this.message);

  @override
  String toString() => message;
}

Uint8List processCommunityImageBytes(Uint8List sourceBytes) {
  image.Image? decoded;
  try {
    decoded = image.decodeImage(sourceBytes);
  } catch (_) {
    throw const CommunityImageProcessingException(
      'Choose a supported still image.',
    );
  }
  if (decoded == null || decoded.numFrames > 1) {
    throw const CommunityImageProcessingException(
      'Choose a supported still image.',
    );
  }

  final oriented = image.bakeOrientation(decoded);
  final cropSize = oriented.width < oriented.height
      ? oriented.width
      : oriented.height;
  final cropped = image.copyCrop(
    oriented,
    x: (oriented.width - cropSize) ~/ 2,
    y: (oriented.height - cropSize) ~/ 2,
    width: cropSize,
    height: cropSize,
  );
  final resized = image.copyResize(
    cropped,
    width: communityImageDimension,
    height: communityImageDimension,
    interpolation: image.Interpolation.cubic,
  );
  return Uint8List.fromList(
    image.encodeJpg(resized, quality: communityImageJpegQuality),
  );
}
