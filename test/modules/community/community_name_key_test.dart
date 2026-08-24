import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/utils/community_name_key.dart';

void main() {
  group('CommunityNameKey', () {
    test('ignores case and all whitespace for duplicate detection', () {
      expect(CommunityNameKey.fromName('Calcio Italia'), 'calcioitalia');
      expect(CommunityNameKey.fromName('  CALCIO   ITALIA  '), 'calcioitalia');
      expect(CommunityNameKey.fromName('Ca lcio Ita lia'), 'calcioitalia');
      expect(CommunityNameKey.fromName('Calcio-Italia'), 'calcio-italia');
    });

    test('removes common accents while ignoring word boundaries', () {
      expect(CommunityNameKey.fromName('Caffè Roma'), 'cafferoma');
      expect(CommunityNameKey.fromName('Ca ffè Ro ma'), 'cafferoma');
      expect(CommunityNameKey.fromName('Caffe Roma Fans'), 'cafferomafans');
    });

    test('keeps punctuation distinct instead of applying slug rules', () {
      expect(CommunityNameKey.fromName('Calcio/Italia'), 'calcio∕italia');
      expect(CommunityNameKey.fromName('Calcio-Italia'), 'calcio-italia');
    });

    test(
      'uses the V2 canonical specification for mixed whitespace and accents',
      () {
        expect(CommunityNameKey.fromName(' \tCà ff\nè / Roma  '), 'caffe∕roma');
        expect(CommunityNameKey.fromName('Ærø ß'), 'aeross');
        expect(CommunityNameKey.fromName('Caffè Test'), 'caffetest');
        expect(CommunityNameKey.fromName('C A F F E T E S T'), 'caffetest');
      },
    );
  });
}
