import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/utils/community_slug.dart';

void main() {
  group('CommunitySlug', () {
    test('normalizes names into readable URL-safe slugs', () {
      expect(CommunitySlug.fromName(' Football Italia '), 'football-italia');
      expect(CommunitySlug.fromName('Study   &  Travel!'), 'study-travel');
    });

    test('removes common accents and falls back for empty names', () {
      expect(CommunitySlug.fromName('Caffè e São Paulo'), 'caffe-e-sao-paulo');
      expect(CommunitySlug.fromName('___'), 'community');
    });

    test('keeps bases and suffixed candidates within the maximum length', () {
      final base = CommunitySlug.fromName('a' * 100);
      expect(base.length, CommunitySlug.maxLength);
      expect(CommunitySlug.withSuffix(base, 2), endsWith('-2'));
      expect(
        CommunitySlug.withSuffix(base, 2).length,
        lessThanOrEqualTo(CommunitySlug.maxLength),
      );
    });
  });
}
