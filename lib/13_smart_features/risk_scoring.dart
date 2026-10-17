/// Risk scoring: a points-based scorecard. Each rule that matches adds
/// points; the total maps to a level (Low / Moderate / High / Severe), and
/// the matched rules explain why.
///
/// **Rule-based, not AI.** This is how many real screening tools work (e.g.
/// clinical scorecards, credit checklists): transparent, auditable, and
/// changeable without code because rules can be loaded from JSON. It is not
/// a validated predictive model — do not present it as a diagnosis.
///
/// Suits: student dropout / at-risk alerts, patient or elderly check-in
/// flags, burnout/wellbeing check-ins, budget overspend warnings, fraud-ish
/// "unusual activity" flags, safety inspections, plant/crop health checks.
///
/// ```dart
/// final model = RiskModel.fromJson({
///   'levels': {'moderate': 3, 'high': 6, 'severe': 9},
///   'rules': [
///     {'id': 'attendance', 'label': 'Attendance under 75%', 'points': 3,
///      'when': {'field': 'attendance', 'op': '<', 'value': 0.75}},
///     {'id': 'late', 'label': '3+ late submissions', 'points': 2,
///      'when': {'field': 'lateSubmissions', 'op': '>=', 'value': 3}},
///     {'id': 'grades', 'label': 'Grade average dropping', 'points': 4,
///      'when': {'field': 'gradeTrend', 'op': '<', 'value': -0.1}},
///   ],
/// });
/// final result = model.assess({'attendance': 0.7, 'lateSubmissions': 4, 'gradeTrend': 0.0});
/// result.level;   // RiskLevel.moderate (5 points)
/// result.reasons; // ['Attendance under 75%', '3+ late submissions']
/// ```
library;

import 'rule_conditions.dart';

enum RiskLevel { low, moderate, high, severe }

class RiskRule {
  const RiskRule({
    required this.id,
    required this.label,
    required this.points,
    required this.when,
  });

  final String id;

  /// Shown to the user as the reason.
  final String label;

  /// Can be negative for protective factors.
  final int points;
  final Condition when;

  factory RiskRule.fromJson(Map<String, Object?> json) => RiskRule(
    id: json['id']! as String,
    label: (json['label'] ?? json['id']) as String,
    points: (json['points']! as num).toInt(),
    when: Condition.fromJson((json['when']! as Map).cast<String, Object?>()),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'points': points,
    'when': when.toJson(),
  };
}

class RiskAssessment {
  const RiskAssessment({
    required this.points,
    required this.maxPoints,
    required this.level,
    required this.matched,
  });

  final int points;

  /// The sum of all positive rule points — the worst possible score.
  final int maxPoints;
  final RiskLevel level;
  final List<RiskRule> matched;

  List<String> get reasons => [for (final r in matched) r.label];

  /// 0…1 of the worst possible score, for a gauge.
  double get fraction =>
      maxPoints <= 0 ? 0 : (points / maxPoints).clamp(0.0, 1.0);
}

class RiskModel {
  const RiskModel({
    required this.rules,
    this.moderateAt = 3,
    this.highAt = 6,
    this.severeAt = 9,
  });

  final List<RiskRule> rules;

  /// Point thresholds for each level (inclusive).
  final int moderateAt;
  final int highAt;
  final int severeAt;

  /// Throws on a malformed rule ([FormatException] for an unknown operator,
  /// [TypeError] for a missing field), so bad remote config
  /// fails at load time rather than silently scoring everyone "low".
  factory RiskModel.fromJson(Map<String, Object?> json) {
    final levels =
        (json['levels'] as Map?)?.cast<String, Object?>() ?? const {};
    return RiskModel(
      rules: [
        for (final r in (json['rules']! as List))
          RiskRule.fromJson((r as Map).cast<String, Object?>()),
      ],
      moderateAt: (levels['moderate'] as num?)?.toInt() ?? 3,
      highAt: (levels['high'] as num?)?.toInt() ?? 6,
      severeAt: (levels['severe'] as num?)?.toInt() ?? 9,
    );
  }

  Map<String, Object?> toJson() => {
    'levels': {'moderate': moderateAt, 'high': highAt, 'severe': severeAt},
    'rules': [for (final r in rules) r.toJson()],
  };

  RiskAssessment assess(Map<String, Object?> facts) {
    final matched = [
      for (final rule in rules)
        if (rule.when.evaluate(facts)) rule,
    ];
    final points = matched.fold<int>(0, (sum, r) => sum + r.points);
    final maxPoints = rules
        .where((r) => r.points > 0)
        .fold<int>(0, (sum, r) => sum + r.points);
    final level = points >= severeAt
        ? RiskLevel.severe
        : points >= highAt
        ? RiskLevel.high
        : points >= moderateAt
        ? RiskLevel.moderate
        : RiskLevel.low;
    // Biggest contributors first, so the top reason is the most important.
    matched.sort((a, b) => b.points.compareTo(a.points));
    return RiskAssessment(
      points: points,
      maxPoints: maxPoints,
      level: level,
      matched: matched,
    );
  }
}
