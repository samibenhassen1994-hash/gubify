import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/core/invites/invite_link_parser.dart';

void main() {
  group('InviteLinkParser', () {
    test('accepts formatted and canonical invite links', () {
      final formatted = InviteLinkParser.tryParse(
        'https://gubify.com/join/K7M4-P9Q2',
      );
      final canonical = InviteLinkParser.tryParse(
        'https://gubify.com/join/K7M4P9Q2',
      );

      for (final result in [formatted, canonical]) {
        expect(result?.canonicalCode, 'K7M4P9Q2');
        expect(result?.visibleCode, 'K7M4-P9Q2');
      }
    });

    test('query and fragment do not alter the invite code', () {
      final result = InviteLinkParser.tryParse(
        'https://gubify.com/join/K7M4-P9Q2?source=share#join',
      );

      expect(result?.canonicalCode, 'K7M4P9Q2');
    });

    test('rejects non-HTTPS, foreign, similar, and subdomain hosts', () {
      for (final value in [
        'http://gubify.com/join/K7M4-P9Q2',
        'https://example.com/join/K7M4-P9Q2',
        'https://gubify.com.evil.test/join/K7M4-P9Q2',
        'https://www.gubify.com/join/K7M4-P9Q2',
        'https://user@gubify.com/join/K7M4-P9Q2',
      ]) {
        expect(InviteLinkParser.tryParse(value), isNull, reason: value);
      }
    });

    test('rejects missing, different, and additional path segments', () {
      for (final value in [
        'https://gubify.com/join',
        'https://gubify.com/join/',
        'https://gubify.com/other/K7M4-P9Q2',
        'https://gubify.com/join/K7M4-P9Q2/extra',
      ]) {
        expect(InviteLinkParser.tryParse(value), isNull, reason: value);
      }
    });

    test(
      'rejects wrong lengths, special characters, and excluded alphabet',
      () {
        for (final value in [
          'https://gubify.com/join/K7M4-P9Q',
          'https://gubify.com/join/K7M4-P9Q22',
          'https://gubify.com/join/K7M4_P9Q2',
          'https://gubify.com/join/K7M4%20P9Q2',
          'https://gubify.com/join/K7M4-P9O2',
        ]) {
          expect(InviteLinkParser.tryParse(value), isNull, reason: value);
        }
      },
    );

    test('rejects malformed URLs', () {
      for (final value in ['', 'not a url', 'https://[broken']) {
        expect(InviteLinkParser.tryParse(value), isNull, reason: value);
      }
    });
  });
}
