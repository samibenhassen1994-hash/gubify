import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/core/app_links/gubify_app_link.dart';
import 'package:gubify/core/app_links/gubify_app_link_parser.dart';

void main() {
  group('GubifyAppLinkParser', () {
    test('preserves canonical and visible Private Gub invite links', () {
      final canonical = GubifyAppLinkParser.parse(
        Uri.parse('https://gubify.com/join/K7M4P9Q2'),
      );
      final visible = GubifyAppLinkParser.parse(
        Uri.parse('https://gubify.com/join/K7M4-P9Q2'),
      );

      expect(
        canonical,
        const PrivateGubInviteLink(
          canonicalCode: 'K7M4P9Q2',
          visibleCode: 'K7M4-P9Q2',
        ),
      );
      expect(visible, canonical);
    });

    test('parses a canonical Community link', () {
      expect(
        GubifyAppLinkParser.parse(
          Uri.parse(
            'https://gubify.com/community/football-italia?source=web#join',
          ),
        ),
        const CommunityAppLink(slug: 'football-italia'),
      );
    });

    test('rejects unsafe origins and malformed Community paths', () {
      const rejected = <String>[
        'http://gubify.com/community/commgub',
        'https://www.gubify.com/community/commgub',
        'https://gubify.com.evil.test/community/commgub',
        'https://user@gubify.com/community/commgub',
        'https://gubify.com:444/community/commgub',
        'https://gubify.com/community/',
        'https://gubify.com/community/CommunityName',
        'https://gubify.com/community/-commgub',
        'https://gubify.com/community/commgub-',
        'https://gubify.com/community/comm_gub',
        'https://gubify.com/community/comm%2Fgub',
        'https://gubify.com/community/commgub/extra',
      ];

      for (final value in rejected) {
        expect(
          GubifyAppLinkParser.parse(Uri.parse(value)),
          isNull,
          reason: value,
        );
      }
    });

    test('rejects Community slugs longer than 60 characters', () {
      final slug = List<String>.filled(61, 'a').join();
      expect(
        GubifyAppLinkParser.parse(
          Uri.parse('https://gubify.com/community/$slug'),
        ),
        isNull,
      );
    });
  });
}
