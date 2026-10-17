/// Daily-streak arithmetic ("you've studied 5 days in a row").
///
/// Source: TaskFlow `core/utils/streak_manager.dart`, which mixed the rule
/// with SharedPreferences reads and a Supabase sync in one static method.
/// The rule is pulled out here as pure functions; store the result wherever
/// you like (e.g. `PrefsStore`). [currentStreak] / [longestStreak] are added
/// for apps that keep a list of active days instead of a counter.
///
/// ```dart
/// final next = recordActivity(
///   lastActiveDay: stored.lastDay,
///   count: stored.count,
///   today: DateTime.now(),
/// );
/// await save(next.lastActiveDay, next.count);
/// ```
library;

/// Updates a counter-style streak for activity on [today].
///
/// Same day → unchanged (at least 1); the next day → +1; a gap → back to 1.
({DateTime lastActiveDay, int count}) recordActivity({
  required DateTime? lastActiveDay,
  required int count,
  required DateTime today,
}) {
  final day = DateTime.utc(today.year, today.month, today.day);
  if (lastActiveDay == null) return (lastActiveDay: day, count: 1);
  final last = DateTime.utc(
    lastActiveDay.year,
    lastActiveDay.month,
    lastActiveDay.day,
  );
  final gap = day.difference(last).inDays;
  final next = switch (gap) {
    0 => count < 1 ? 1 : count,
    1 => count + 1,
    // gap > 1 is a break; gap < 0 means the clock went backwards — restart
    // rather than trust it.
    _ => 1,
  };
  return (lastActiveDay: gap < 0 ? last : day, count: next);
}

/// Consecutive active days ending today — or ending yesterday, so a streak
/// is not shown as broken before the user has had a chance to act today.
int currentStreak(Iterable<DateTime> activeDays, DateTime today) {
  final days = _daySet(activeDays);
  var cursor = DateTime.utc(today.year, today.month, today.day);
  if (!days.contains(cursor)) cursor = cursor.subtract(const Duration(days: 1));
  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

/// The longest run of consecutive active days.
int longestStreak(Iterable<DateTime> activeDays) {
  final days = _daySet(activeDays).toList()..sort();
  var best = 0;
  var run = 0;
  DateTime? previous;
  for (final day in days) {
    run = previous != null && day.difference(previous).inDays == 1
        ? run + 1
        : 1;
    if (run > best) best = run;
    previous = day;
  }
  return best;
}

// UTC midnights, so subtracting a day is always exactly 24 hours.
Set<DateTime> _daySet(Iterable<DateTime> days) => {
  for (final d in days) DateTime.utc(d.year, d.month, d.day),
};
