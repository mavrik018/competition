/// "Intelligent" insights: short, human sentences generated from a user's
/// own numbers — "You studied 23% more than last week", "Tuesdays are your
/// best day", "That was an unusually high day" — ranked by importance.
///
/// **Rule-based templates, not AI.** Each insight is a statistic
/// (`trends.dart`) that passed a threshold you configure, poured into a
/// sentence template. Nothing is invented: every number in the text comes
/// from the data. For freer wording, pass these facts to an LLM via
/// `14_ai` — the rule-based text remains the offline fallback.
///
/// Suits: weekly reviews, analytics screens, dashboards, end-of-session
/// summaries, coaching apps.
///
/// ```dart
/// final insights = generateInsights(
///   days,                                          // dailySeries(...) output, oldest first
///   config: const InsightConfig(metric: 'study time', unit: 'min', goalPerDay: 60),
///   now: DateTime.now(),
/// );
/// Column(children: [for (final i in insights) InsightCard(insight: i)]);
/// ```
library;

import 'package:flutter/material.dart';

import '../01_design_system/app_palette.dart';
import '../01_design_system/app_tokens.dart';
import '../11_utilities/date_utils.dart';
import '../11_utilities/streak.dart';
import 'trends.dart';

enum InsightTone { positive, negative, neutral }

class Insight {
  const Insight({
    required this.id,
    required this.title,
    required this.message,
    required this.tone,
    required this.importance,
  });

  /// Stable id (e.g. 'week_change') — use it to let users dismiss a type.
  final String id;
  final String title;
  final String message;
  final InsightTone tone;

  /// Higher first. 0–100.
  final int importance;
}

class InsightConfig {
  const InsightConfig({
    required this.metric,
    this.unit = '',
    this.higherIsBetter = true,
    this.goalPerDay,
    this.minChangePercent = 10,
    this.anomalyThreshold = 2,
    this.minDays = 7,
  });

  /// Noun phrase used in sentences: "study time", "spending", "steps".
  final String metric;

  /// Appended to numbers: "min", "kcal", "€".
  final String unit;

  /// False for things like spending or screen time, flipping the tone.
  final bool higherIsBetter;
  final double? goalPerDay;

  /// Week-over-week changes smaller than this (percent) are not mentioned.
  final double minChangePercent;
  final double anomalyThreshold;

  /// Below this many days of data, only a "keep logging" message is given.
  final int minDays;
}

/// Insights for daily data (oldest first), most important first.
List<Insight> generateInsights(
  List<({DateTime day, double value})> days, {
  required InsightConfig config,
  required DateTime now,
}) {
  final insights = <Insight>[];
  String fmt(double v) =>
      '${v % 1 == 0 ? v.toInt() : v.toStringAsFixed(1)}${config.unit.isEmpty ? '' : ' ${config.unit}'}';
  InsightTone toneFor(bool wentUp) => wentUp == config.higherIsBetter
      ? InsightTone.positive
      : InsightTone.negative;

  if (days.length < config.minDays) {
    return [
      Insight(
        id: 'need_data',
        title: 'Keep logging',
        message:
            'A few more days of ${config.metric} and insights will appear here.',
        tone: InsightTone.neutral,
        importance: 10,
      ),
    ];
  }
  final values = [for (final d in days) d.value];

  // 1. This week vs last week.
  if (values.length >= 14) {
    final thisWeek = values
        .sublist(values.length - 7)
        .fold<double>(0, (s, v) => s + v);
    final lastWeek = values
        .sublist(values.length - 14, values.length - 7)
        .fold<double>(0, (s, v) => s + v);
    final change = percentChange(lastWeek, thisWeek);
    if (change != null && change.abs() >= config.minChangePercent) {
      insights.add(
        Insight(
          id: 'week_change',
          title: change > 0 ? 'Up on last week' : 'Down on last week',
          message:
              'Your ${config.metric} is ${change.abs().round()}% ${change > 0 ? 'higher' : 'lower'} than last week (${fmt(thisWeek)} vs ${fmt(lastWeek)}).',
          tone: toneFor(change > 0),
          importance: 60 + (change.abs() / 5).clamp(0, 30).round(),
        ),
      );
    }
  }

  // 2. Overall direction.
  final trend = analyzeTrend(values);
  if (trend.direction != TrendDirection.flat && trend.fit >= 0.3) {
    final up = trend.direction == TrendDirection.up;
    insights.add(
      Insight(
        id: 'trend',
        title: up ? 'Trending up' : 'Trending down',
        message:
            'Over the last ${values.length} days your ${config.metric} has been ${up ? 'rising' : 'falling'} steadily.',
        tone: toneFor(up),
        importance: 50,
      ),
    );
  }

  // 3. Best weekday (needs at least two of each weekday to mean anything).
  if (values.length >= 14) {
    final averages = weekdayAverages(days);
    final best = averages.entries.reduce((a, b) => b.value > a.value ? b : a);
    final overall = mean(values);
    if (overall > 0 && best.value > overall * 1.25) {
      insights.add(
        Insight(
          id: 'best_weekday',
          title: '${weekdayNames[best.key - 1]}s stand out',
          message:
              '${weekdayNames[best.key - 1]}s average ${fmt(best.value)}, against ${fmt(overall)} overall.',
          tone: InsightTone.neutral,
          importance: 35,
        ),
      );
    }
  }

  // 4. Unusual latest day.
  final unusual = anomalies(values, threshold: config.anomalyThreshold);
  if (unusual.contains(values.length - 1)) {
    final high = values.last > mean(values);
    insights.add(
      Insight(
        id: 'anomaly',
        title: high ? 'Unusually high day' : 'Unusually low day',
        message:
            '${relativeDayLabel(days.last.day, now: now)} you logged ${fmt(values.last)}, far ${high ? 'above' : 'below'} your usual ${fmt(mean(values))}.',
        tone: toneFor(high),
        importance: 70,
      ),
    );
  }

  // 5. Goal streak.
  final goal = config.goalPerDay;
  if (goal != null) {
    final metDays = [
      for (final d in days)
        if (config.higherIsBetter ? d.value >= goal : d.value <= goal) d.day,
    ];
    final streak = currentStreak(metDays, now);
    if (streak >= 3) {
      insights.add(
        Insight(
          id: 'goal_streak',
          title: '$streak-day streak',
          message:
              "You've hit your ${config.metric} goal $streak days in a row.",
          tone: InsightTone.positive,
          importance: 65 + streak.clamp(0, 25),
        ),
      );
    }
    final hitRate = metDays.length / days.length;
    if (streak < 3 && hitRate < 0.3) {
      insights.add(
        Insight(
          id: 'goal_rate',
          title: 'Goal within reach?',
          message:
              'You met your goal of ${fmt(goal)} on ${metDays.length} of ${days.length} days. A smaller goal might help you build momentum.',
          tone: InsightTone.neutral,
          importance: 40,
        ),
      );
    }
  }

  insights.sort((a, b) => b.importance.compareTo(a.importance));
  return insights;
}

/// A compact card for one [Insight], coloured by tone.
class InsightCard extends StatelessWidget {
  const InsightCard({super.key, required this.insight, this.onDismiss});

  final Insight insight;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = SemanticColors.of(context);
    final (color, icon) = switch (insight.tone) {
      InsightTone.positive => (semantic.success, Icons.trending_up),
      InsightTone.negative => (theme.colorScheme.error, Icons.trending_down),
      InsightTone.neutral => (semantic.info, Icons.lightbulb_outline),
    };
    return Card(
      child: Padding(
        padding: Insets.card,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: Gap.md - 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(insight.title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(insight.message, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            if (onDismiss != null)
              IconButton(
                tooltip: 'Dismiss',
                icon: const Icon(Icons.close, size: 18),
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}
