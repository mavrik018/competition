/// Rule-based and statistical predictions: forecast the next values of a
/// series, estimate when a goal will be reached, check whether progress is
/// on pace for a deadline, and predict a category from if-then rules.
///
/// **Not AI / machine learning.** Forecasts are a straight-line fit or
/// exponential smoothing; category predictions are the first matching
/// rule. They are honest extrapolations — they cannot know about events
/// the data does not show (holidays, exams, a broken leg), so present them
/// as "at your current pace…", never as certainties.
///
/// Suits: savings and fitness goals ("you'll reach 10 km by…"), study plans
/// ("at this pace you'll finish the syllabus on…"), stock/inventory
/// run-out dates, habit forecasts, "likely to miss deadline" warnings.
///
/// ```dart
/// final eta = predictWhenReached(cumulativeSavings, target: 1000,
///     lastDate: DateTime.now(), step: const Duration(days: 1));
/// eta?.date;   // when, at the current rate (null if not increasing)
///
/// final pace = checkPace(done: 12, total: 40, start: termStart, due: examDay, now: now);
/// pace.status; // PaceStatus.behind — projected finish after the due date
/// ```
library;

import 'dart:math' as math;

import 'rule_conditions.dart';
import 'trends.dart';

/// Next [steps] values by extending the least-squares line, each with a
/// ±1 standard-error band from the fit's residuals.
List<({double value, double low, double high})> forecastLinear(
  List<num> values,
  int steps,
) {
  if (values.isEmpty || steps <= 0) return const [];
  final fit = linearFit(values);
  var squaredError = 0.0;
  for (var i = 0; i < values.length; i++) {
    final predicted = fit.intercept + fit.slope * i;
    squaredError += math.pow(values[i] - predicted, 2);
  }
  final spread = values.length > 2
      ? math.sqrt(squaredError / (values.length - 2))
      : 0.0;
  final forecasts = <({double value, double low, double high})>[];
  for (var s = 1; s <= steps; s++) {
    final value = fit.intercept + fit.slope * (values.length - 1 + s);
    forecasts.add((value: value, low: value - spread, high: value + spread));
  }
  return forecasts;
}

/// Simple exponential smoothing: a level that follows the data, weighting
/// recent values by [alpha] (0…1; higher reacts faster). Returns the
/// forecast for the next value. Good for noisy data with no clear trend.
double exponentialSmoothing(List<num> values, {double alpha = 0.3}) {
  if (values.isEmpty) return 0;
  var level = values.first.toDouble();
  for (final v in values.skip(1)) {
    level = alpha * v + (1 - alpha) * level;
  }
  return level;
}

/// When a *cumulative* series (oldest first, one value per [step], the last
/// on [lastDate]) will reach [target] at its recent linear rate. Uses the
/// last [window] points so old behaviour does not dominate. Null when the
/// series is not increasing; zero steps when already reached.
({int steps, DateTime date})? predictWhenReached(
  List<num> values, {
  required num target,
  required DateTime lastDate,
  Duration step = const Duration(days: 1),
  int window = 14,
}) {
  if (values.isEmpty) return null;
  if (values.last >= target) return (steps: 0, date: lastDate);
  final recent = values.length > window
      ? values.sublist(values.length - window)
      : values;
  final slope = linearFit(recent).slope;
  if (slope <= 0) return null;
  final steps = ((target - values.last) / slope).ceil();
  return (steps: steps, date: lastDate.add(step * steps));
}

enum PaceStatus { ahead, onTrack, behind, notStarted, done }

class PaceCheck {
  const PaceCheck({
    required this.status,
    required this.expectedDone,
    this.projectedFinish,
  });

  final PaceStatus status;

  /// How much should be done by now for a steady pace.
  final double expectedDone;

  /// When the work finishes at the average pace so far; null if no progress.
  final DateTime? projectedFinish;
}

/// Compares progress ([done] of [total]) with a steady pace from [start]
/// to [due]. Within [tolerance] (default 10% of total) of the expected
/// amount counts as on track.
PaceCheck checkPace({
  required num done,
  required num total,
  required DateTime start,
  required DateTime due,
  required DateTime now,
  double tolerance = 0.1,
}) {
  final span = due.difference(start).inMinutes;
  final elapsed = now
      .difference(start)
      .inMinutes
      .clamp(0, span <= 0 ? 0 : span);
  final expected = span <= 0 ? total.toDouble() : total * elapsed / span;
  if (done >= total) {
    return PaceCheck(
      status: PaceStatus.done,
      expectedDone: expected.toDouble(),
      projectedFinish: now,
    );
  }
  if (done <= 0) {
    return PaceCheck(
      status: PaceStatus.notStarted,
      expectedDone: expected.toDouble(),
    );
  }

  final perMinute = done / math.max(1, now.difference(start).inMinutes);
  final projected = now.add(
    Duration(minutes: ((total - done) / perMinute).ceil()),
  );
  final gap = (done - expected) / total;
  final status = gap > tolerance
      ? PaceStatus.ahead
      : gap < -tolerance
      ? PaceStatus.behind
      : PaceStatus.onTrack;
  return PaceCheck(
    status: status,
    expectedDone: expected.toDouble(),
    projectedFinish: projected,
  );
}

/// One "if these facts, then this outcome" rule.
class PredictionRule<R> {
  const PredictionRule({
    required this.when,
    required this.outcome,
    this.confidence = 1,
    this.because,
  });

  final Condition when;
  final R outcome;

  /// Your own stated confidence (0…1) for display — not a probability
  /// learned from data.
  final double confidence;

  /// Why, in words — shown to the user.
  final String? because;
}

/// The first rule whose condition matches decides the outcome; otherwise
/// [fallback]. Order rules from most to least specific.
class RulePredictor<R> {
  const RulePredictor(this.rules, {required this.fallback});

  final List<PredictionRule<R>> rules;
  final R fallback;

  ({R outcome, double confidence, String? because}) predict(
    Map<String, Object?> facts,
  ) {
    for (final rule in rules) {
      if (rule.when.evaluate(facts)) {
        return (
          outcome: rule.outcome,
          confidence: rule.confidence,
          because: rule.because ?? rule.when.describe(),
        );
      }
    }
    return (outcome: fallback, confidence: 0, because: null);
  }
}
