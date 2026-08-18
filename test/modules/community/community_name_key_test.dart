import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/utils/community_name_key.dart';

void main() {
  group('CommunityNameKey', () {
    test('normalizes case and repeated spaces without using slug rules', () {
      expect(CommunityNameKey.fromName('Calcio Italia'), 'calcio italia');
      expect(CommunityNameKey.fromName('  CALCIO   ITALIA  '), 'calcio italia');
      expect(CommunityNameKey.fromName('Calcio-Italia'), 'calcio-italia');
    });

    test('removes common accents while retaining word boundaries', () {
      expect(CommunityNameKey.fromName('Caffè Roma'), 'caffe roma');
      expect(CommunityNameKey.fromName('Caffe Roma Fans'), 'caffe roma fans');
    });

    test('keeps punctuation distinct instead of applying slug rules', () {
      expect(CommunityNameKey.fromName('Calcio/Italia'), 'calcio∕italia');
    });
  });
}
