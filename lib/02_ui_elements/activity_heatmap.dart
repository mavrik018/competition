import 'package:flutter/material.dart';

/// A GitHub-style contribution grid: one column per week (Monday at the top),
/// one square per day, shaded by how much happened that day.
///
/// Source: StudyBuddies `heatmap_calendar.dart`, which took a list of study
/// sessions and had its card chrome, header text and "hours total" pill built
/// in. Generalised to any per-day number and stripped to the grid and legend,
/// so the caller decides what surrounds it.
///
/// ```dart
/// ActivityHeatmap(
///   values: {for (final s in sessions) s.date: s.minutes},
///   levelThresholds: const [20, 60], // >0, >20, >60 minutes → 3 shades
///   tooltip: (day, minutes) => '${minutes.round()} min',
/// )
/// ```
class ActivityHeatmap extends StatelessWidget {
  const ActivityHeatmap({
    super.key,
    required this.values,
    this.weeks = 12,
    this.levelThresholds = const [20, 60],
    this.color,
    this.tooltip,
    this.showLegend = true,
    this.today,
  });

  /// Amount per day. Keys may carry a time of day; only the date is used,
  /// and several entries on one day are summed.
  final Map<DateTime, num> values;

  /// Number of week columns, ending with the current week.
  final int weeks;

  /// Ascending boundaries between shades. See [heatmapLevel].
  final List<num> levelThresholds;

  /// Full-intensity colour. Defaults to the theme's primary colour.
  final Color? color;

  /// Tooltip text for a day. No tooltips when null.
  final String Function(DateTime day, num value)? tooltip;
  final bool showLegend;

  /// Overrides "today" — for tests and previews.
  final DateTime? today;

  static const _gap = 3.0;
  static const _labelWidth = 18.0;
  static const _weekdayLabels = ['M', '', 'W', '', 'F', '', ''];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = color ?? scheme.primary;
    final empty = scheme.surfaceContainerHighest;
    final now = today ?? DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final totals = sumByDay(values);
    final columns = heatmapColumns(todayDate, weeks);
    final maxLevel = levelThresholds.length + 1;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    Color shade(int level) => level == 0
        ? empty
        : accent.withValues(
            alpha: maxLevel == 1 ? 1 : 0.2 + 0.8 * (level - 1) / (maxLevel - 1),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - _labelWidth - _gap;
        final cell = ((available - (weeks - 1) * _gap) / weeks).clamp(
          6.0,
          18.0,
        );

        Widget square(DateTime day) {
          final isFuture = day.isAfter(todayDate);
          final value = isFuture ? 0 : (totals[day] ?? 0);
          final box = Container(
            width: cell,
            height: cell,
            margin: const EdgeInsets.only(bottom: _gap),
            decoration: BoxDecoration(
              color: isFuture
                  ? empty.withValues(alpha: 0.4)
                  : shade(heatmapLevel(value, levelThresholds)),
              borderRadius: BorderRadius.circular(3),
              border: day == todayDate
                  ? Border.all(color: scheme.primary, width: 1.5)
                  : null,
            ),
          );
          if (tooltip == null || isFuture) return box;
          return Tooltip(message: tooltip!(day, value), child: box);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _labelWidth,
                  child: Column(
                    children: [
                      for (final label in _weekdayLabels)
                        SizedBox(
                          height: cell + _gap,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(label, style: labelStyle),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: _gap),
                for (var w = 0; w < columns.length; w++) ...[
                  if (w > 0) const SizedBox(width: _gap),
                  Column(children: [for (final day in columns[w]) square(day)]),
                ],
              ],
            ),
            if (showLegend) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Less', style: labelStyle),
                  for (var level = 0; level <= maxLevel; level++)
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: shade(level),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  Text('More', style: labelStyle),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// The shade index for [value]: 0 for nothing, then one more for every
/// threshold the value exceeds. With thresholds `[20, 60]`: 0 → 0, 10 → 1,
/// 30 → 2, 90 → 3.
int heatmapLevel(num value, List<num> thresholds) {
  if (value <= 0) return 0;
  return 1 + thresholds.where((t) => value > t).length;
}

/// [weeks] columns of seven days (Monday first), the last column holding
/// [today]'s week. Days after [today] are included so columns stay square.
List<List<DateTime>> heatmapColumns(DateTime today, int weeks) {
  final thisMonday = DateTime(
    today.year,
    today.month,
    today.day - (today.weekday - 1),
  );
  return [
    for (var w = weeks - 1; w >= 0; w--)
      [
        for (var d = 0; d < 7; d++)
          // Built from y/m/d rather than adding Durations so a daylight-saving
          // change can never shift a day by an hour.
          DateTime(
            thisMonday.year,
            thisMonday.month,
            thisMonday.day - 7 * w + d,
          ),
      ],
  ];
}

/// Sums [values] per calendar day, dropping the time of day.
Map<DateTime, num> sumByDay(Map<DateTime, num> values) {
  final totals = <DateTime, num>{};
  values.forEach((moment, value) {
    final day = DateTime(moment.year, moment.month, moment.day);
    totals[day] = (totals[day] ?? 0) + value;
  });
  return totals;
}
