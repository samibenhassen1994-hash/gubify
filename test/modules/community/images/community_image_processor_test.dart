import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/images/community_image_processor.dart';
import 'package:image/image.dart' as image;

void main() {
  test('center crops and encodes a 512 square JPEG', () {
    final source = image.Image(width: 900, height: 600);
    image.fill(source, color: image.ColorRgb8(20, 80, 160));

    final result = processCommunityImageBytes(
      Uint8List.fromList(image.encodePng(source)),
    );
    final decoded = image.decodeJpg(result);

    expect(decoded, isNotNull);
    expect(decoded!.width, 512);
    expect(decoded.height, 512);
  });

  test('rejects bytes that are not a supported image', () {
    expect(
      () => processCommunityImageBytes(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<CommunityImageProcessingException>()),
    );
  });
}
