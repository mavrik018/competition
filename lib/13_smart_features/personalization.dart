/// Personalization: learn what a user likes from what they do — open,
/// favourite, complete, skip — and reorder content accordingly; also learn
/// the hour they are usually active (for reminder timing).
///
/// **Statistical, not AI.** A score per key (a tag, category, cuisine,
/// subject) that grows with each interaction and halves every [halfLife],
/// so recent behaviour matters most. Fully on-device and inspectable —
/// show `topKeys` in settings so users can see (and reset) what was learnt.
///
/// Suits: feeds and catalogues (recipes, courses, products, articles),
/// "your subjects first" in study apps, default filters, home-screen
/// ordering, best time for a reminder.
///
/// ```dart
/// final profile = PreferenceProfile.fromJson(prefs.getJson('profile') ?? {});
/// profile.record('cuisine:italian', weight: 3);       // favourited
/// profile.record('cuisine:thai');                      // opened
/// profile.record('cuisine:italian', weight: -1);       // skipped
/// profile.recordActiveAt(DateTime.now());
/// await prefs.setJson('profile', profile.toJson());
///
/// final feed = profile.orderByAffinity(recipes, (r) => ['cuisine:${r.cuisine}', ...r.tags]);
/// final reminderHour = profile.preferredHour() ?? 19;
/// ```
library;

import 'dart:math' as math;

/// Suggested interaction weights — tune them to your app.
abstract final class InteractionWeight {
  static const view = 1.0;
  static const complete = 2.0;
  static const favourite = 3.0;
  static const share = 3.0;
  static const skip = -1.0;
  static const hide = -3.0;
}

class PreferenceProfile {
  PreferenceProfile({this.halfLife = const Duration(days: 14)});

  /// After this long without new interactions a score is worth half.
  final Duration halfLife;

  final Map<String, ({double score, DateTime at})> _scores = {};
  final List<int> _activeHours = List.filled(24, 0);

  /// Adds [weight] to [key]'s score (after decaying the old score to [at]).
  void record(String key, {double weight = 1, DateTime? at}) {
    final now = at ?? DateTime.now();
    _scores[key] = (score: affinity(key, now: now) + weight, at: now);
  }

  /// [key]'s current score, decayed to [now]. 0 for unknown keys.
  double affinity(String key, {DateTime? now}) {
    final entry = _scores[key];
    if (entry == null) return 0;
    final elapsed = (now ?? DateTime.now()).difference(entry.at);
    if (elapsed <= Duration.zero) return entry.score;
    final halfLives = elapsed.inMinutes / halfLife.inMinutes;
    return entry.score * math.pow(0.5, halfLives);
  }

  /// The [limit] keys with the highest positive scores.
  List<({String key, double score})> topKeys({int limit = 5, DateTime? now}) {
    final scored = [
      for (final key in _scores.keys)
        (key: key, score: affinity(key, now: now)),
    ]..removeWhere((e) => e.score <= 0);
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).toList();
  }

  /// [items] sorted by the summed affinity of their keys, highest first;
  /// items with equal scores keep their order (so a "newest first" list
  /// stays newest-first among items the user feels the same about).
  List<T> orderByAffinity<T>(
    Iterable<T> items,
    Iterable<String> Function(T item) keysOf, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final scored =
        [
          for (final (index, item) in items.indexed)
            (
              index,
              item,
              keysOf(
                item,
              ).fold<double>(0, (s, k) => s + affinity(k, now: clock)),
            ),
        ]..sort((a, b) {
          final c = b.$3.compareTo(a.$3);
          return c != 0 ? c : a.$1.compareTo(b.$1);
        });
    return [for (final (_, item, _) in scored) item];
  }

  /// Counts one activity at [at]'s hour.
  void recordActiveAt(DateTime at) => _activeHours[at.hour]++;

  /// The hour with most activity, or null with fewer than [minSamples]
  /// recorded (too little to go on).
  int? preferredHour({int minSamples = 5}) {
    final total = _activeHours.fold<int>(0, (s, c) => s + c);
    if (total < minSamples) return null;
    var best = 0;
    for (var h = 1; h < 24; h++) {
      if (_activeHours[h] > _activeHours[best]) best = h;
    }
    return best;
  }

  /// Forgets everything — offer this in settings.
  void reset() {
    _scores.clear();
    _activeHours.fillRange(0, 24, 0);
  }

  Map<String, dynamic> toJson() => {
    'halfLifeHours': halfLife.inHours,
    'scores': {
      for (final e in _scores.entries)
        e.key: {'score': e.value.score, 'at': e.value.at.toIso8601String()},
    },
    'activeHours': _activeHours,
  };

  /// Tolerates missing or partial JSON (returns an empty profile).
  factory PreferenceProfile.fromJson(Map<String, dynamic> json) {
    final profile = PreferenceProfile(
      halfLife: Duration(
        hours: (json['halfLifeHours'] as num?)?.toInt() ?? 14 * 24,
      ),
    );
    final scores = json['scores'];
    if (scores is Map) {
      for (final MapEntry(:key, :value) in scores.entries) {
        if (value is! Map) continue;
        final at = DateTime.tryParse('${value['at']}');
        final score = value['score'];
        if (at != null && score is num) {
          profile._scores['$key'] = (score: score.toDouble(), at: at);
        }
      }
    }
    final hours = json['activeHours'];
    if (hours is List && hours.length == 24) {
      for (var h = 0; h < 24; h++) {
        profile._activeHours[h] = (hours[h] as num?)?.toInt() ?? 0;
      }
    }
    return profile;
  }
}
