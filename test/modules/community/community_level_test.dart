import 'package:flutter_test/flutter_test.dart';
import 'package:gubify/modules/community/leveling/community_level.dart';

void main() {
  test('derives Community levels from the fixed XP thresholds', () {
    expect(CommunityLevel.fromXp(null).level, 1);
    expect(CommunityLevel.fromXp(-4).level, 1);
    expect(CommunityLevel.fromXp(0).level, 1);
    expect(CommunityLevel.fromXp(20).level, 2);
    expect(CommunityLevel.fromXp(60).level, 3);
    expect(CommunityLevel.fromXp(3800).level, 20);
    expect(CommunityLevel.fromXp(99999).level, 20);
  });

  test('calculates in-level progress and next level values', () {
    final level = CommunityLevel.fromXp(640);

    expect(level.level, 8);
    expect(level.currentThreshold, 560);
    expect(level.nextThreshold, 720);
    expect(level.xpWithinCurrentLevel, 80);
    expect(level.xpNeededForNextLevel, 160);
    expect(level.xpRequiredForNextLevel, 160);
    expect(level.xpRemainingToNextLevel, 80);
    expect(level.progress, 0.5);
    expect(level.percentage, 50);
    expect(level.nextLevel, 9);
    expect(level.isMaxLevel, isFalse);
  });

  test('caps Level 20 with complete progress and no next level', () {
    final level = CommunityLevel.fromXp(3800);

    expect(level.isMaxLevel, isTrue);
    expect(level.progress, 1);
    expect(level.percentage, 100);
    expect(level.nextLevel, isNull);
    expect(level.xpNeededForNextLevel, isNull);
  });

  test('exposes only the highest unlocked recognition', () {
    expect(CommunityLevel.fromXp(199).recognition, isNull);
    expect(CommunityLevel.fromXp(200).recognition, 'Contributor');
    expect(CommunityLevel.fromXp(900).recognition, 'Trusted Member');
    expect(CommunityLevel.fromXp(2100).recognition, 'Community Expert');
    expect(CommunityLevel.fromXp(3800).recognition, 'Community Legend');
  });
}
