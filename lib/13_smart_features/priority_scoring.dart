/// Priority scoring: turn due date, importance, effort and age into one
/// 0–100 score and a band (Critical / High / Medium / Low), with the
/// reasons — plus the classic Eisenhower quadrant.
///
/// **Rule-based, not AI.** A weighted sum of normalised factors with
/// thresholds you configure ([PriorityRules]); the same task always gets
/// the same score.
///
/// Suits: to-do and study planners ("what should I do next?"), support
/// ticket triage, maintenance requests, assignment trackers, volunteer
/// task boards, bug lists.
///
/// ```dart
/// const rules = PriorityRules();                     // or tune the weights
/// final p = scorePriority(
///   PriorityInput(due: task.due, importance: task.importance, effortHours: 2, createdAt: task.created),
///   now: DateTime.now(),
///   rules: rules,
/// );
/// p.score;     // 78
/// p.band;      // PriorityBand.high
/// p.reasons;   // ['Due in 1 day', 'Importance 4/5']
/// final ordered = rankByPriority(tasks, (t) => t.toPriorityInput(), now: now);
/// ```
library;

import 'dart:math' as math;

enum PriorityBand { critical, high, medium, low }

class PriorityInput {
  const PriorityInput({
    this.due,
    this.importance = 3,
    this.effortHours,
    this.createdAt,
  });

  final DateTime? due;

  /// 1 (trivial) … 5 (essential).
  final int importance;

  /// Estimated work. Quick tasks get a small boost ("quick win").
  final double? effortHours;
  final DateTime? createdAt;
}

/// The business rules. Weights need not sum to 1 — they are normalised.
class PriorityRules {
  const PriorityRules({
    this.urgencyWeight = 0.5,
    this.importanceWeight = 0.35,
    this.quickWinWeight = 0.1,
    this.ageWeight = 0.05,
    this.urgentWithinDays = 7,
    this.quickWinHours = 1,
    this.staleAfterDays = 30,
    this.criticalAt = 80,
    this.highAt = 60,
    this.mediumAt = 35,
  });

  final double urgencyWeight;
  final double importanceWeight;
  final double quickWinWeight;

  /// Old items creep up so nothing waits forever.
  final double ageWeight;

  /// Urgency rises linearly over this window before the due date; overdue
  /// items get full urgency.
  final int urgentWithinDays;
  final double quickWinHours;
  final int staleAfterDays;

  /// Band thresholds on the 0–100 score.
  final int criticalAt;
  final int highAt;
  final int mediumAt;
}

class PriorityScore {
  const PriorityScore({
    required this.score,
    required this.band,
    required this.reasons,
  });

  /// 0–100.
  final int score;
  final PriorityBand band;
  final List<String> reasons;
}

PriorityScore scorePriority(
  PriorityInput input, {
  required DateTime now,
  PriorityRules rules = const PriorityRules(),
}) {
  final reasons = <String>[];

  // Urgency: 0 when due beyond the window (or no due date), 1 when due now
  // or overdue.
  var urgency = 0.0;
  final due = input.due;
  if (due != null) {
    final hoursLeft = due.difference(now).inMinutes / 60;
    final window = rules.urgentWithinDays * 24.0;
    urgency = hoursLeft <= 0 ? 1.0 : (1 - hoursLeft / window).clamp(0.0, 1.0);
    if (hoursLeft <= 0) {
      final daysLate = (-hoursLeft / 24).ceil();
      reasons.add(daysLate <= 1 ? 'Overdue' : 'Overdue by $daysLate days');
    } else if (hoursLeft < window) {
      final days = (hoursLeft / 24).ceil();
      reasons.add(
        hoursLeft < 24
            ? 'Due today'
            : 'Due in $days day${days == 1 ? '' : 's'}',
      );
    }
  }

  final importance = ((input.importance.clamp(1, 5) - 1) / 4).toDouble();
  if (input.importance >= 4) reasons.add('Importance ${input.importance}/5');

  final effort = input.effortHours;
  final quickWin = effort != null && effort <= rules.quickWinHours ? 1.0 : 0.0;
  if (quickWin > 0) reasons.add('Quick win');

  var age = 0.0;
  if (input.createdAt != null) {
    final days = now.difference(input.createdAt!).inDays;
    age = (days / rules.staleAfterDays).clamp(0.0, 1.0);
    if (days >= rules.staleAfterDays) reasons.add('Waiting $days days');
  }

  final totalWeight =
      rules.urgencyWeight +
      rules.importanceWeight +
      rules.quickWinWeight +
      rules.ageWeight;
  final raw = totalWeight == 0
      ? 0.0
      : (rules.urgencyWeight * urgency +
                rules.importanceWeight * importance +
                rules.quickWinWeight * quickWin +
                rules.ageWeight * age) /
            totalWeight;
  final score = (raw * 100).round();

  // Overdue and important is always critical, whatever the weights say.
  final overdueAndImportant = urgency == 1 && input.importance >= 4;
  final band = overdueAndImportant || score >= rules.criticalAt
      ? PriorityBand.critical
      : score >= rules.highAt
      ? PriorityBand.high
      : score >= rules.mediumAt
      ? PriorityBand.medium
      : PriorityBand.low;

  return PriorityScore(
    score: math.max(score, overdueAndImportant ? rules.criticalAt : 0),
    band: band,
    reasons: reasons,
  );
}

/// Items sorted highest priority first (stable for equal scores).
List<(T, PriorityScore)> rankByPriority<T>(
  Iterable<T> items,
  PriorityInput Function(T item) inputOf, {
  required DateTime now,
  PriorityRules rules = const PriorityRules(),
}) {
  final scored =
      [
        for (final (i, item) in items.indexed)
          (i, item, scorePriority(inputOf(item), now: now, rules: rules)),
      ]..sort((a, b) {
        final c = b.$3.score.compareTo(a.$3.score);
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
  return [for (final (_, item, score) in scored) (item, score)];
}

enum EisenhowerQuadrant { doFirst, schedule, delegate, eliminate }

/// Urgent = due within [urgentWithinDays] (or overdue); important =
/// importance ≥ [importantFrom].
EisenhowerQuadrant eisenhowerQuadrant(
  PriorityInput input, {
  required DateTime now,
  int urgentWithinDays = 2,
  int importantFrom = 4,
}) {
  final urgent =
      input.due != null &&
      input.due!.difference(now).inHours <= urgentWithinDays * 24;
  final important = input.importance >= importantFrom;
  return switch ((urgent, important)) {
    (true, true) => EisenhowerQuadrant.doFirst,
    (false, true) => EisenhowerQuadrant.schedule,
    (true, false) => EisenhowerQuadrant.delegate,
    (false, false) => EisenhowerQuadrant.eliminate,
  };
}
