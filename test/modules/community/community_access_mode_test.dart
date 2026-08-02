import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/models/community_model.dart';

void main() {
  group('Community access mode', () {
    test('preserves supported modes', () {
      expect(
        CommunityModel.normalizeAccessMode(CommunityModel.openAccessMode),
        CommunityModel.openAccessMode,
      );
      expect(
        CommunityModel.normalizeAccessMode(CommunityModel.approvalAccessMode),
        CommunityModel.approvalAccessMode,
      );
    });

    test('uses the safe approval fallback for legacy or invalid values', () {
      expect(
        CommunityModel.normalizeAccessMode(null),
        CommunityModel.approvalAccessMode,
      );
      expect(
        CommunityModel.normalizeAccessMode('unexpected'),
        CommunityModel.approvalAccessMode,
      );
    });
  });
}
