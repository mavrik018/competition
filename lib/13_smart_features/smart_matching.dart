/// Smart matching: rank candidates for a seeker by weighted, explainable
/// criteria (skills overlap, distance, availability, budget…), optionally
/// pairing people one-to-one.
///
/// **Rule-based, not AI.** A match score is a weighted average of criterion
/// scores you define; the same inputs always give the same ranking, and
/// every score comes with a per-criterion breakdown you can show the user.
///
/// Suits: mentor ↔ mentee, volunteer ↔ task, tutor ↔ student, roommate or
/// study-buddy finders, job ↔ candidate shortlists, donor ↔ request,
/// "find a teammate" in hackathon apps.
///
/// ```dart
/// final matcher = SmartMatcher<Student, Tutor>([
///   MatchCriterion('Subjects', weight: 3, required: true,
///       score: (s, t) => jaccard(s.subjects, t.subjects)),
///   MatchCriterion('Distance', weight: 2,
///       score: (s, t) => proximityScore(s.home.distanceKmTo(t.home), maxKm: 15)),
///   MatchCriterion('Budget', weight: 1,
///       score: (s, t) => t.hourlyRate <= s.maxRate ? 1 : 0),
/// ], minScore: 0.4);
///
/// final results = matcher.rank(student, tutors);     // best first
/// results.first.explanation;  // "Subjects 100%, Distance 72%, Budget 100%"
/// ```
library;

import 'dart:math' as math;

/// One thing that makes a candidate a good fit.
class MatchCriterion<A, B> {
  const MatchCriterion(
    this.name, {
    required this.score,
    this.weight = 1,
    this.required = false,
  });

  final String name;

  /// 0.0 (no fit) … 1.0 (perfect fit). Values outside are clamped.
  final double Function(A seeker, B candidate) score;

  /// Relative importance; 0 disables the criterion.
  final double weight;

  /// When true, a candidate scoring 0 here is excluded entirely (a hard
  /// constraint such as "must teach maths").
  final bool required;
}

class MatchResult<B> {
  const MatchResult({
    required this.candidate,
    required this.score,
    required this.breakdown,
  });

  final B candidate;

  /// Weighted average, 0.0 … 1.0.
  final double score;

  /// Criterion name → its 0…1 score.
  final Map<String, double> breakdown;

  int get percent => (score * 100).round();

  /// "Subjects 100%, Distance 72%, Budget 100%" — show it next to the match.
  String get explanation => breakdown.entries
      .map((e) => '${e.key} ${(e.value * 100).round()}%')
      .join(', ');

  /// The best-scoring criteria, for "Why this match?" chips.
  List<String> strengths({double threshold = 0.75}) => [
    for (final e in breakdown.entries)
      if (e.value >= threshold) e.key,
  ];
}

class SmartMatcher<A, B> {
  const SmartMatcher(this.criteria, {this.minScore = 0});

  final List<MatchCriterion<A, B>> criteria;

  /// Candidates scoring below this are dropped from [rank].
  final double minScore;

  /// Scores one pair, or null when a required criterion scores 0.
  MatchResult<B>? score(A seeker, B candidate) {
    final breakdown = <String, double>{};
    var weighted = 0.0;
    var totalWeight = 0.0;
    for (final criterion in criteria) {
      if (criterion.weight <= 0) continue;
      final value = criterion.score(seeker, candidate).clamp(0.0, 1.0);
      if (criterion.required && value == 0) return null;
      breakdown[criterion.name] = value;
      weighted += value * criterion.weight;
      totalWeight += criterion.weight;
    }
    return MatchResult(
      candidate: candidate,
      score: totalWeight == 0 ? 0 : weighted / totalWeight,
      breakdown: breakdown,
    );
  }

  /// All acceptable candidates, best first (ties keep input order).
  List<MatchResult<B>> rank(A seeker, Iterable<B> candidates, {int? limit}) {
    final results = <MatchResult<B>>[
      for (final candidate in candidates)
        if (score(seeker, candidate) case final result?
            when result.score >= minScore)
          result,
    ];
    // Stable sort: List.sort is not stable, so tie-break on input position.
    final indexed = results.indexed.toList()
      ..sort((a, b) {
        final byScore = b.$2.score.compareTo(a.$2.score);
        return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
      });
    final sorted = [for (final entry in indexed) entry.$2];
    return limit == null ? sorted : sorted.take(limit).toList();
  }

  /// Pairs seekers with candidates one-to-one, greedily taking the highest
  /// remaining score each time. Simple and explainable; not guaranteed
  /// globally optimal (use the Hungarian algorithm if that matters).
  List<(A, MatchResult<B>)> assignOneToOne(
    List<A> seekers,
    List<B> candidates,
  ) {
    final all = <(int, int, MatchResult<B>)>[];
    for (var s = 0; s < seekers.length; s++) {
      for (var c = 0; c < candidates.length; c++) {
        final result = score(seekers[s], candidates[c]);
        if (result != null && result.score >= minScore) all.add((s, c, result));
      }
    }
    all.sort((a, b) => b.$3.score.compareTo(a.$3.score));
    final usedSeekers = <int>{};
    final usedCandidates = <int>{};
    final pairs = <(A, MatchResult<B>)>[];
    for (final (s, c, result) in all) {
      if (usedSeekers.contains(s) || usedCandidates.contains(c)) continue;
      usedSeekers.add(s);
      usedCandidates.add(c);
      pairs.add((seekers[s], result));
    }
    return pairs;
  }
}

// ── Ready-made criterion scores ─────────────────────────────────────────────

/// Overlap of two sets: |A ∩ B| / |A ∪ B|. Case-insensitive for strings.
/// Two empty sets score 0 (nothing in common to go on).
double jaccard(Iterable<Object?> a, Iterable<Object?> b) {
  Object? norm(Object? v) => v is String ? v.toLowerCase().trim() : v;
  final setA = a.map(norm).toSet();
  final setB = b.map(norm).toSet();
  final union = setA.union(setB);
  if (union.isEmpty) return 0;
  return setA.intersection(setB).length / union.length;
}

/// Share of [required] items present in [offered] — "covers 3 of 4 needs".
double coverage(Iterable<Object?> required, Iterable<Object?> offered) {
  Object? norm(Object? v) => v is String ? v.toLowerCase().trim() : v;
  final needs = required.map(norm).toSet();
  if (needs.isEmpty) return 1;
  final has = offered.map(norm).toSet();
  return needs.where(has.contains).length / needs.length;
}

/// 1.0 at distance 0, falling linearly to 0.0 at [maxKm] and beyond.
double proximityScore(double distanceKm, {required double maxKm}) =>
    maxKm <= 0 ? 0 : (1 - distanceKm / maxKm).clamp(0.0, 1.0);

/// 1.0 when [value] equals [target], falling to 0.0 at ±[tolerance].
double closeness(num value, num target, {required num tolerance}) =>
    tolerance <= 0
    ? (value == target ? 1 : 0)
    : (1 - (value - target).abs() / tolerance).clamp(0.0, 1.0);

/// Fraction of range A that overlaps range B (e.g. available hours).
double rangeOverlap(num aStart, num aEnd, num bStart, num bEnd) {
  final length = aEnd - aStart;
  if (length <= 0) return 0;
  final overlap = math.min(aEnd, bEnd) - math.max(aStart, bStart);
  return (overlap / length).clamp(0.0, 1.0).toDouble();
}

/// Similarity of two strings, 0–1, from Levenshtein edit distance —
/// tolerant of typos ("recieve" vs "receive" ≈ 0.71). Case-insensitive.
double textSimilarity(String a, String b) {
  final x = a.toLowerCase().trim();
  final y = b.toLowerCase().trim();
  if (x.isEmpty && y.isEmpty) return 1;
  final longest = math.max(x.length, y.length);
  return 1 - levenshtein(x, y) / longest;
}

/// Minimum single-character edits (insert, delete, substitute) turning
/// [a] into [b].
int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      current[j] = math.min(
        math.min(current[j - 1] + 1, previous[j] + 1),
        previous[j - 1] + cost,
      );
    }
    previous = current;
  }
  return previous[b.length];
}
