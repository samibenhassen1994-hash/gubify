class CommunityLevel {
  const CommunityLevel._({
    required this.xp,
    required this.level,
    required this.currentThreshold,
    required this.nextThreshold,
    required this.progress,
    required this.recognition,
  });

  static const int minLevel = 1;
  static const int maxLevel = 20;
  static const int maxXp = 3800;

  final int xp;
  final int level;
  final int currentThreshold;
  final int? nextThreshold;
  final double progress;
  final String? recognition;

  factory CommunityLevel.fromXp(int? value) {
    final xp = (value ?? 0).clamp(0, maxXp).toInt();
    var level = minLevel;
    for (var candidate = minLevel + 1; candidate <= maxLevel; candidate++) {
      if (xp < thresholdForLevel(candidate)) {
        break;
      }
      level = candidate;
    }

    final currentThreshold = thresholdForLevel(level);
    final isMaxLevel = level == maxLevel;
    final nextThreshold = isMaxLevel ? null : thresholdForLevel(level + 1);
    final progress = isMaxLevel
        ? 1.0
        : (xp - currentThreshold) / (nextThreshold! - currentThreshold);

    return CommunityLevel._(
      xp: xp,
      level: level,
      currentThreshold: currentThreshold,
      nextThreshold: nextThreshold,
      progress: progress,
      recognition: _recognitionForLevel(level),
    );
  }

  static int thresholdForLevel(int level) {
    if (level < minLevel || level > maxLevel) {
      throw ArgumentError.value(level, 'level', 'Must be between 1 and 20.');
    }
    return 10 * (level - 1) * level;
  }

  bool get isMaxLevel => level == maxLevel;
  int get percentage => (progress * 100).round();
  int get xpWithinCurrentLevel => xp - currentThreshold;
  int? get xpRequiredForNextLevel =>
      nextThreshold == null ? null : nextThreshold! - currentThreshold;
  int? get xpRemainingToNextLevel =>
      nextThreshold == null ? null : nextThreshold! - xp;
  int? get xpNeededForNextLevel => xpRequiredForNextLevel;
  int? get nextLevel => isMaxLevel ? null : level + 1;

  static String? _recognitionForLevel(int level) {
    if (level >= 20) return 'Community Legend';
    if (level >= 15) return 'Community Expert';
    if (level >= 10) return 'Trusted Member';
    if (level >= 5) return 'Contributor';
    return null;
  }
}
