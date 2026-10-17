/// Trend analysis for a series of numbers over time: direction (up / down /
/// flat), change versus the previous period, moving averages, weekday
/// patterns, volatility and unusual values.
///
/// **Statistical, not AI.** Least-squares slope, means, standard deviations
/// and z-scores — textbook formulas, deterministic, offline.
///
/// Suits: any app that logs something daily — study minutes, spending,
/// steps, calories, sleep, mood, sales, energy use, water intake — and
/// wants to say "you're trending up" or "Mondays are your best day".
///
/// ```dart
/// final days = dailySeries(sessions, dateOf: (s) => s.date, valueOf: (s) => s.minutes,
///     from: DateTime.now().subtract(const Duration(days: 27)), to: DateTime.now());
/// final summary = analyzeTrend([for (final d in days) d.value]);
/// summary.direction;      // TrendDirection.up
/// summary.changePercent;  // 18.5  (second half vs first half)
/// weekdayAverages(days);  // {1: 42.0, 2: 30.5, …}  Monday = 1
/// ```
library;

import 'dart:math' as math;

enum TrendDirection { up, down, flat }

/// Least-squares line through (index, value): value ≈ intercept + slope·index.
/// [r2] (0…1) says how well a straight line explains the data.
({double slope, double intercept, double r2}) linearFit(List<num> values) {
  final n = values.length;
  if (n == 0) return (slope: 0, intercept: 0, r2: 0);
  if (n == 1) return (slope: 0, intercept: values.first.toDouble(), r2: 0);
  final meanX = (n - 1) / 2;
  final meanY = mean(values);
  var sxy = 0.0;
  var sxx = 0.0;
  var syy = 0.0;
  for (var i = 0; i < n; i++) {
    final dx = i - meanX;
    final dy = values[i] - meanY;
    sxy += dx * dy;
    sxx += dx * dx;
    syy += dy * dy;
  }
  final slope = sxy / sxx;
  final r2 = syy == 0 ? 0.0 : (sxy * sxy) / (sxx * syy);
  return (slope: slope, intercept: meanY - slope * meanX, r2: r2);
}

double mean(List<num> values) => values.isEmpty
    ? 0
    : values.fold<double>(0, (s, v) => s + v) / values.length;

/// Population standard deviation.
double standardDeviation(List<num> values) {
  if (values.length < 2) return 0;
  final m = mean(values);
  return math.sqrt(
    values.fold<double>(0, (s, v) => s + (v - m) * (v - m)) / values.length,
  );
}

/// Trailing average over [window] points; the first points average what is
/// available so the output has the same length as the input.
List<double> movingAverage(List<num> values, int window) {
  final out = <double>[];
  var sum = 0.0;
  for (var i = 0; i < values.length; i++) {
    sum += values[i];
    if (i >= window) sum -= values[i - window];
    out.add(sum / math.min(i + 1, window));
  }
  return out;
}

/// Percentage change from [previous] to [current]; null when previous is 0
/// (a change from nothing has no meaningful percentage).
double? percentChange(num previous, num current) =>
    previous == 0 ? null : (current - previous) / previous.abs() * 100;

/// Indexes whose value is more than [threshold] standard deviations from
/// the mean (needs at least 4 points; returns none for flat data).
List<int> anomalies(List<num> values, {double threshold = 2}) {
  if (values.length < 4) return const [];
  final m = mean(values);
  final sd = standardDeviation(values);
  if (sd == 0) return const [];
  return [
    for (var i = 0; i < values.length; i++)
      if ((values[i] - m).abs() / sd > threshold) i,
  ];
}

class TrendSummary {
  const TrendSummary({
    required this.direction,
    required this.slope,
    required this.fit,
    required this.average,
    required this.latest,
    required this.min,
    required this.max,
    required this.volatility,
    required this.changePercent,
  });

  final TrendDirection direction;

  /// Change per step (per day for daily data).
  final double slope;

  /// How straight the trend is, 0…1 (r²). Below ~0.3 the "trend" is weak.
  final double fit;
  final double average;
  final double latest;
  final double min;
  final double max;

  /// Coefficient of variation: standard deviation / mean.
  final double volatility;

  /// Second half's total versus the first half's, in percent; null when the
  /// first half was all zero.
  final double? changePercent;
}

/// Summarises [values] (oldest first). The trend is "flat" when the
/// fitted line moves less than [flatThreshold] (default 2%) of the average
/// per step, or when there are fewer than 3 points.
TrendSummary analyzeTrend(List<num> values, {double flatThreshold = 0.02}) {
  final fit = linearFit(values);
  final avg = mean(values);
  final relativeSlope = avg == 0 ? fit.slope : fit.slope / avg.abs();
  final direction = values.length < 3 || relativeSlope.abs() < flatThreshold
      ? TrendDirection.flat
      : (fit.slope > 0 ? TrendDirection.up : TrendDirection.down);
  final half = values.length ~/ 2;
  final firstHalf = values.take(half).fold<double>(0, (s, v) => s + v);
  final secondHalf = values
      .skip(values.length - half)
      .fold<double>(0, (s, v) => s + v);
  return TrendSummary(
    direction: direction,
    slope: fit.slope,
    fit: fit.r2,
    average: avg,
    latest: values.isEmpty ? 0 : values.last.toDouble(),
    min: values.isEmpty ? 0 : values.map((v) => v.toDouble()).reduce(math.min),
    max: values.isEmpty ? 0 : values.map((v) => v.toDouble()).reduce(math.max),
    volatility: avg == 0 ? 0 : standardDeviation(values) / avg.abs(),
    changePercent: half == 0 ? null : percentChange(firstHalf, secondHalf),
  );
}

/// One value per calendar day from [from] to [to] inclusive, summing
/// [valueOf] for events on the same day and filling empty days with 0.
List<({DateTime day, double value})> dailySeries<T>(
  Iterable<T> events, {
  required DateTime Function(T event) dateOf,
  required num Function(T event) valueOf,
  required DateTime from,
  required DateTime to,
}) {
  final totals = <DateTime, double>{};
  for (final event in events) {
    final d = dateOf(event);
    final day = DateTime(d.year, d.month, d.day);
    totals[day] = (totals[day] ?? 0) + valueOf(event);
  }
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day);
  return [
    for (
      var day = start;
      !day.isAfter(end);
      day = DateTime(day.year, day.month, day.day + 1)
    )
      (day: day, value: totals[day] ?? 0),
  ];
}

/// Average value per weekday (1 = Monday … 7 = Sunday) over [days].
Map<int, double> weekdayAverages(List<({DateTime day, double value})> days) {
  final sums = <int, double>{};
  final counts = <int, int>{};
  for (final d in days) {
    sums[d.day.weekday] = (sums[d.day.weekday] ?? 0) + d.value;
    counts[d.day.weekday] = (counts[d.day.weekday] ?? 0) + 1;
  }
  return {for (final w in sums.keys) w: sums[w]! / counts[w]!};
}
