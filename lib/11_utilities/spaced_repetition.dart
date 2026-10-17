/// SM-2 spaced repetition: after each review, how many days until a card
/// should be shown again.
///
/// Source: StudyBuddies `features/study/domain/smart_review.dart`
/// (`nextRetention`) — the same arithmetic was also copied inline into
/// `spaced_repetition_screen.dart`; this is the single shared version.
///
/// Grades follow SM-2: 0–2 = forgotten (the card starts over), 3 = recalled
/// with effort, 4 = recalled, 5 = easy. Like the source, ease only changes on
/// grade 2 (−0.15) and grade 5 (+0.15) and stays within 1.3–3.0 — a
/// simplification of the original SM-2 ease formula that keeps two-button
/// ("didn't know" = 2, "knew it" = 4) reviews stable.
///
/// ```dart
/// var card = const ReviewState();          // new card
/// card = card.review(4, now: DateTime.now());
/// if (card.isDue(DateTime.now())) showCard();
/// ```
library;

import 'package:flutter/foundation.dart';

@immutable
class ReviewState {
  const ReviewState({
    this.repetitions = 0,
    this.intervalDays = 0,
    this.easeFactor = 2.5,
    this.nextReview,
  });

  /// Consecutive successful reviews.
  final int repetitions;
  final int intervalDays;
  final double easeFactor;

  /// Null for a card never reviewed — it is due immediately.
  final DateTime? nextReview;

  bool isDue(DateTime now) => nextReview == null || !nextReview!.isAfter(now);

  /// Days past due (0 when not yet due or never reviewed). Used to show the
  /// most overdue cards first.
  double overdueDays(DateTime now) {
    final due = nextReview;
    if (due == null || due.isAfter(now)) return 0;
    return now.difference(due).inMinutes / (60 * 24);
  }

  ReviewState review(int grade, {required DateTime now}) {
    assert(grade >= 0 && grade <= 5, 'SM-2 grades are 0–5');
    var ease = easeFactor;
    final int reps;
    final int interval;
    if (grade < 3) {
      reps = 0;
      interval = 1;
      if (grade == 2) ease = (ease - 0.15).clamp(1.3, 3.0);
    } else {
      reps = repetitions + 1;
      interval = switch (reps) {
        1 => 1,
        2 => 6,
        _ => (intervalDays * ease).round(),
      };
      if (grade == 5) ease = (ease + 0.15).clamp(1.3, 3.0);
    }
    return ReviewState(
      repetitions: reps,
      intervalDays: interval,
      easeFactor: ease,
      nextReview: now.add(Duration(days: interval)),
    );
  }

  Map<String, dynamic> toJson() => {
    'repetitions': repetitions,
    'interval_days': intervalDays,
    'ease_factor': easeFactor,
    'next_review': nextReview?.toIso8601String(),
  };

  factory ReviewState.fromJson(Map<String, dynamic> json) => ReviewState(
    repetitions: (json['repetitions'] as num?)?.toInt() ?? 0,
    intervalDays: (json['interval_days'] as num?)?.toInt() ?? 0,
    easeFactor: (json['ease_factor'] as num?)?.toDouble() ?? 2.5,
    nextReview: DateTime.tryParse(json['next_review'] as String? ?? ''),
  );
}

/// The ids of cards due at [now], most overdue first, never-reviewed cards
/// after the overdue ones, capped at [limit] — a due list of 80 is a chore,
/// not a session (the source capped at 12).
List<String> dueCards(
  Map<String, ReviewState> cards,
  DateTime now, {
  int limit = 20,
}) {
  final due = cards.entries.where((e) => e.value.isDue(now)).toList()
    ..sort((a, b) {
      final aNew = a.value.nextReview == null;
      final bNew = b.value.nextReview == null;
      if (aNew != bNew) return aNew ? 1 : -1;
      return b.value.overdueDays(now).compareTo(a.value.overdueDays(now));
    });
  return due.take(limit).map((e) => e.key).toList();
}
