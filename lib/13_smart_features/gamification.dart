/// Gamification: experience points with a level curve, badges unlocked by
/// rules, leaderboards with fair tie handling, and time-boxed challenges —
/// plus an XP bar and badge grid.
///
/// **Rule-based, not AI.** XP comes from a points table, levels from a
/// formula, badges from conditions over the user's stats (JSON-loadable).
///
/// Suits: habit, study, fitness, language-learning, volunteering, recycling
/// or reading apps; classroom leaderboards; onboarding checklists.
///
/// ```dart
/// const curve = LevelCurve(baseXp: 100, growth: 1.5);
/// final xp = XpRules({'task_done': 10, 'focus_25min': 15, 'streak_day': 5}).pointsFor('task_done');
/// final level = curve.progressFor(user.totalXp);        // level 4, 37% to level 5
///
/// final badges = [
///   AchievementBadge.fromJson({'id': 'first', 'title': 'First steps', 'icon': 'flag',
///                   'when': {'field': 'tasksDone', 'op': '>=', 'value': 1}}),
///   AchievementBadge.fromJson({'id': 'streak7', 'title': 'On fire', 'icon': 'fire',
///                   'when': {'field': 'streak', 'op': '>=', 'value': 7}}),
/// ];
/// final newOnes = newlyUnlocked(badges, stats: {'tasksDone': 12, 'streak': 7}, alreadyEarned: user.badges);
/// ```
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../01_design_system/app_tokens.dart';
import 'rule_conditions.dart';

/// XP needed per level grows geometrically: level 1→2 needs [baseXp],
/// each next level needs [growth] times more.
class LevelCurve {
  const LevelCurve({this.baseXp = 100, this.growth = 1.5})
    : assert(baseXp > 0 && growth >= 1);

  final int baseXp;
  final double growth;

  /// XP needed to go from [level] to level + 1.
  int xpForNextLevel(int level) =>
      (baseXp * math.pow(growth, level - 1)).round();

  /// Total XP at which [level] starts (level 1 starts at 0).
  int xpToReach(int level) {
    var total = 0;
    for (var l = 1; l < level; l++) {
      total += xpForNextLevel(l);
    }
    return total;
  }

  ({int level, int xpIntoLevel, int xpNeeded, double fraction}) progressFor(
    int totalXp,
  ) {
    var level = 1;
    var remaining = math.max(0, totalXp);
    while (remaining >= xpForNextLevel(level)) {
      remaining -= xpForNextLevel(level);
      level++;
    }
    final needed = xpForNextLevel(level);
    return (
      level: level,
      xpIntoLevel: remaining,
      xpNeeded: needed,
      fraction: remaining / needed,
    );
  }
}

/// Points per action, with an optional multiplier for streaks.
class XpRules {
  const XpRules(
    this.points, {
    this.streakBonusPerDay = 0.05,
    this.maxStreakBonus = 0.5,
  });

  /// Action id → base XP.
  final Map<String, int> points;

  /// +5% per streak day by default, capped at +50%.
  final double streakBonusPerDay;
  final double maxStreakBonus;

  int pointsFor(String action, {int streakDays = 0}) {
    final base = points[action] ?? 0;
    final bonus = math.min(maxStreakBonus, streakDays * streakBonusPerDay);
    return (base * (1 + bonus)).round();
  }
}

class AchievementBadge {
  const AchievementBadge({
    required this.id,
    required this.title,
    required this.when,
    this.description,
    this.icon = Icons.emoji_events,
  });

  final String id;
  final String title;
  final String? description;
  final IconData icon;
  final Condition when;

  static const _icons = {
    'trophy': Icons.emoji_events,
    'fire': Icons.local_fire_department,
    'star': Icons.star,
    'flag': Icons.flag,
    'bolt': Icons.bolt,
    'heart': Icons.favorite,
    'book': Icons.menu_book,
    'medal': Icons.military_tech,
  };

  factory AchievementBadge.fromJson(Map<String, Object?> json) =>
      AchievementBadge(
        id: json['id']! as String,
        title: json['title']! as String,
        description: json['description'] as String?,
        icon: _icons[json['icon']] ?? Icons.emoji_events,
        when: Condition.fromJson(
          (json['when']! as Map).cast<String, Object?>(),
        ),
      );
}

/// Badges whose condition now holds for [stats] and that were not already
/// earned — show a celebration for each, then save their ids.
List<AchievementBadge> newlyUnlocked(
  List<AchievementBadge> badges, {
  required Map<String, Object?> stats,
  required Set<String> alreadyEarned,
}) => [
  for (final b in badges)
    if (!alreadyEarned.contains(b.id) && b.when.evaluate(stats)) b,
];

/// Leaderboard positions using "standard competition" ranking: equal
/// scores share a rank and the next rank skips (1, 2, 2, 4).
List<({int rank, T entry})> leaderboard<T>(
  Iterable<T> entries,
  num Function(T entry) scoreOf,
) {
  final sorted = entries.toList()
    ..sort((a, b) => scoreOf(b).compareTo(scoreOf(a)));
  final ranked = <({int rank, T entry})>[];
  for (var i = 0; i < sorted.length; i++) {
    final tied = i > 0 && scoreOf(sorted[i]) == scoreOf(sorted[i - 1]);
    ranked.add((rank: tied ? ranked.last.rank : i + 1, entry: sorted[i]));
  }
  return ranked;
}

/// A goal with a deadline, e.g. "Study 300 minutes this week".
class Challenge {
  const Challenge({
    required this.id,
    required this.title,
    required this.target,
    required this.ends,
  });

  final String id;
  final String title;
  final num target;
  final DateTime ends;

  ({double fraction, bool completed, bool expired, num remaining}) progress(
    num current,
    DateTime now,
  ) {
    final completed = current >= target;
    return (
      fraction: target <= 0 ? 1 : (current / target).clamp(0, 1).toDouble(),
      completed: completed,
      expired: !completed && now.isAfter(ends),
      remaining: math.max(0, target - current),
    );
  }
}

/// "Level 4 · 120 / 337 XP" with a progress bar.
class XpProgressBar extends StatelessWidget {
  const XpProgressBar({
    super.key,
    required this.totalXp,
    this.curve = const LevelCurve(),
  });

  final int totalXp;
  final LevelCurve curve;

  @override
  Widget build(BuildContext context) {
    final p = curve.progressFor(totalXp);
    final theme = Theme.of(context);
    return Semantics(
      label:
          'Level ${p.level}, ${p.xpIntoLevel} of ${p.xpNeeded} experience points to the next level',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('Level ${p.level}', style: theme.textTheme.titleSmall),
              const Spacer(),
              Text(
                '${p.xpIntoLevel} / ${p.xpNeeded} XP',
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: p.fraction),
              duration: Motion.long,
              builder: (_, value, _) =>
                  LinearProgressIndicator(value: value, minHeight: 10),
            ),
          ),
        ],
      ),
    );
  }
}

/// Earned badges in colour, locked ones greyed out.
class BadgeGrid extends StatelessWidget {
  const BadgeGrid({
    super.key,
    required this.badges,
    required this.earned,
    this.onTap,
  });

  final List<AchievementBadge> badges;
  final Set<String> earned;
  final ValueChanged<AchievementBadge>? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: Gap.md,
      runSpacing: Gap.md,
      children: [
        for (final badge in badges)
          Semantics(
            button: onTap != null,
            label:
                '${badge.title}, ${earned.contains(badge.id) ? 'earned' : 'locked'}',
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.md),
              onTap: onTap == null ? null : () => onTap!(badge),
              child: SizedBox(
                width: 76,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: earned.contains(badge.id)
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHighest,
                      child: Icon(
                        earned.contains(badge.id)
                            ? badge.icon
                            : Icons.lock_outline,
                        color: earned.contains(badge.id)
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      badge.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
