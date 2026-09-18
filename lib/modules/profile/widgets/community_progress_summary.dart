import 'package:flutter/material.dart';

import '../../community/leveling/community_level.dart';

class CommunityProgressSummary extends StatelessWidget {
  const CommunityProgressSummary({
    super.key,
    required this.level,
    this.showTitle = false,
    this.showTotalXp = false,
  });

  final CommunityLevel level;
  final bool showTitle;
  final bool showTotalXp;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final barText = level.isMaxLevel
        ? '${CommunityLevel.maxXp}+ XP'
        : '${level.xpWithinCurrentLevel} / '
              '${level.xpRequiredForNextLevel} XP';
    final detail = level.isMaxLevel
        ? 'Max level'
        : '${level.percentage}% to Level ${level.nextLevel}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle) ...[
          Text(
            'Community progress',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                'Level ${level.level}',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (showTotalXp) ...[
                const SizedBox(height: 3),
                Text(
                  '${level.xp} XP total',
                  style: textTheme.bodyMedium?.copyWith(color: Colors.black54),
                ),
              ],
              if (level.recognition != null) ...[
                const SizedBox(height: 3),
                Text(
                  level.recognition!,
                  style: textTheme.bodyMedium?.copyWith(color: Colors.black54),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                height: 32,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.primary),
                      ),
                      child: const SizedBox.expand(),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: level.progress,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                    Text(
                      barText,
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Center(child: Text(detail, style: textTheme.bodySmall)),
            ],
          ),
        ),
      ],
    );
  }
}
