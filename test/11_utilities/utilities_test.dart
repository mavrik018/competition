import 'package:competition_toolkit/11_utilities/app_logger.dart';
import 'package:competition_toolkit/11_utilities/collection_utils.dart';
import 'package:competition_toolkit/11_utilities/date_utils.dart';
import 'package:competition_toolkit/11_utilities/geo.dart';
import 'package:competition_toolkit/11_utilities/health_calc.dart';
import 'package:competition_toolkit/11_utilities/markdown_parser.dart';
import 'package:competition_toolkit/11_utilities/number_format.dart';
import 'package:competition_toolkit/11_utilities/quantity_scaler.dart';
import 'package:competition_toolkit/11_utilities/spaced_repetition.dart';
import 'package:competition_toolkit/11_utilities/streak.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('date_utils', () {
    final now = DateTime(2026, 10, 14, 15, 30); // a Wednesday

    test('dateOnly, isSameDay, addDays, daysBetween', () {
      expect(dateOnly(now), DateTime(2026, 10, 14));
      expect(dateOnly(DateTime.utc(2026, 1, 1, 5)).isUtc, isTrue);
      expect(isSameDay(now, DateTime(2026, 10, 14)), isTrue);
      expect(addDays(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
      expect(addDays(DateTime(2026, 3, 1), -1), DateTime(2026, 2, 28));
      expect(
        daysBetween(DateTime(2026, 10, 14, 23), DateTime(2026, 10, 15, 1)),
        1,
      );
      expect(daysBetween(DateTime(2026, 10, 15), DateTime(2026, 10, 14)), -1);
    });

    test('daysInMonth handles leap years', () {
      expect(daysInMonth(2028, 2), 29);
      expect(daysInMonth(2026, 2), 28);
      expect(daysInMonth(2026, 12), 31);
    });

    test('startOfWeek', () {
      expect(startOfWeek(now), DateTime(2026, 10, 12));
      expect(
        startOfWeek(now, firstWeekday: DateTime.sunday),
        DateTime(2026, 10, 11),
      );
      expect(startOfWeek(DateTime(2026, 10, 12)), DateTime(2026, 10, 12));
    });

    test('isoWeekNumber, including year boundaries', () {
      expect(isoWeekNumber(DateTime(2026, 10, 14)), 42);
      expect(isoWeekNumber(DateTime(2026, 1, 1)), 1); // Thursday
      expect(
        isoWeekNumber(DateTime(2027, 1, 1)),
        53,
      ); // Friday → last week of 2026
      expect(isoWeekNumber(DateTime(2024, 12, 30)), 1); // Monday of 2025-W01
    });

    test('addYears clamps Feb 29', () {
      expect(addYears(DateTime(2024, 2, 29), 1), DateTime(2025, 2, 28));
      expect(addYears(DateTime(2024, 2, 29), 4), DateTime(2028, 2, 29));
      expect(
        addYears(DateTime(2026, 5, 10, 8, 15), 2),
        DateTime(2028, 5, 10, 8, 15),
      );
    });

    test('formatting', () {
      expect(formatShortDate(now), 'Oct 14');
      expect(formatLongDate(now), 'October 14, 2026');
      expect(formatTime(DateTime(2026, 1, 1, 0, 5)), '12:05 AM');
      expect(formatTime(DateTime(2026, 1, 1, 13, 0)), '1:00 PM');
      expect(formatTime(DateTime(2026, 1, 1, 9, 7), use24Hour: true), '09:07');
      expect(weekRangeLabel(DateTime(2026, 9, 14)), 'Sep 14 — Sep 20, 2026');
    });

    test('relativeDayLabel', () {
      expect(relativeDayLabel(DateTime(2026, 10, 14, 8), now: now), 'Today');
      expect(relativeDayLabel(DateTime(2026, 10, 15), now: now), 'Tomorrow');
      expect(relativeDayLabel(DateTime(2026, 10, 13), now: now), 'Yesterday');
      expect(relativeDayLabel(DateTime(2026, 10, 17), now: now), 'Saturday');
      expect(relativeDayLabel(DateTime(2026, 11, 2), now: now), 'Nov 2');
      expect(relativeDayLabel(DateTime(2027, 1, 2), now: now), 'Jan 2, 2027');
    });

    test('timeAgo', () {
      expect(
        timeAgo(now.subtract(const Duration(seconds: 30)), now: now),
        'just now',
      );
      expect(
        timeAgo(now.subtract(const Duration(minutes: 5)), now: now),
        '5m ago',
      );
      expect(
        timeAgo(now.subtract(const Duration(hours: 3)), now: now),
        '3h ago',
      );
      expect(
        timeAgo(now.subtract(const Duration(days: 1)), now: now),
        '1 day ago',
      );
      expect(
        timeAgo(now.subtract(const Duration(days: 4)), now: now),
        '4 days ago',
      );
    });
  });

  group('number_format', () {
    test('formatQuantity', () {
      expect(formatQuantity(2.0), '2');
      expect(formatQuantity(1.5), '1.5');
      expect(formatQuantity(1 / 3), '0.33');
      expect(formatQuantity(2.005, maxDecimals: 1), '2');
      expect(formatQuantity(-0.25), '-0.25');
    });

    test('formatCompact, formatBytes, formatDuration', () {
      expect(formatCompact(950), '950');
      expect(formatCompact(1200), '1.2k');
      expect(formatCompact(3400000), '3.4M');
      expect(formatCompact(2500000000), '2.5B');
      expect(formatBytes(512), '512 B');
      expect(formatBytes(2048), '2.0 KB');
      expect(formatBytes(3355443), '3.2 MB');
      expect(formatDuration(const Duration(seconds: 45)), '45s');
      expect(formatDuration(const Duration(minutes: 5, seconds: 3)), '5m 03s');
      expect(formatDuration(const Duration(hours: 1, minutes: 5)), '1h 05m');
    });
  });

  group('markdown_parser', () {
    test('classifies lines', () {
      expect(
        parseMarkdownLine('## Title'),
        isA<MarkdownHeading>().having((h) => h.level, 'level', 2),
      );
      expect(parseMarkdownLine('#hashtag'), isA<MarkdownParagraph>());
      expect(
        parseMarkdownLine('  - nested'),
        isA<MarkdownBullet>().having((b) => b.indent, 'indent', 1),
      );
      expect(
        parseMarkdownLine('3. third'),
        isA<MarkdownNumbered>().having((n) => n.number, 'number', '3'),
      );
      expect(parseMarkdownLine('> quote'), isA<MarkdownQuote>());
      expect(parseMarkdownLine('   '), isA<MarkdownBlank>());
      expect(parseMarkdownLine('**bold** start'), isA<MarkdownParagraph>());
    });

    test('fences are verbatim and an unterminated fence runs to the end', () {
      final blocks = parseMarkdown(
        '```dart\n  - not a bullet\n*x*\n```\nafter',
      );
      final code = blocks.first as MarkdownCode;
      expect(code.language, 'dart');
      expect(code.code, '  - not a bullet\n*x*');
      expect(blocks.last, isA<MarkdownParagraph>());

      final open = parseMarkdown('```\nline1\nline2');
      expect(open, hasLength(1));
      expect((open.single as MarkdownCode).code, 'line1\nline2');
    });

    test('tables need two rows, keep escaped pipes and pad ragged rows', () {
      expect(parseMarkdown('| just prose |').single, isA<MarkdownParagraph>());
      final table =
          parseMarkdown(
                '| op | meaning |\n|---|---|\n| a \\| b | or |\n| c |',
              ).single
              as MarkdownTable;
      expect(table.hasHeader, isTrue);
      expect(table.rows, [
        ['op', 'meaning'],
        ['a | b', 'or'],
        ['c', ''],
      ]);
    });

    test('handles Windows line endings', () {
      expect(parseMarkdown('# A\r\n- b'), hasLength(2));
    });

    test('inline spans', () {
      expect(parseInline('a **b** *c* `d *e*` ~~f~~'), const [
        InlineSpanData('a ', InlineStyle.plain),
        InlineSpanData('b', InlineStyle.bold),
        InlineSpanData(' ', InlineStyle.plain),
        InlineSpanData('c', InlineStyle.italic),
        InlineSpanData(' ', InlineStyle.plain),
        InlineSpanData('d *e*', InlineStyle.code),
        InlineSpanData(' ', InlineStyle.plain),
        InlineSpanData('f', InlineStyle.strikethrough),
      ]);
      expect(parseInline('2 * 3 * 4'), const [
        InlineSpanData('2 * 3 * 4', InlineStyle.plain),
      ]);
      expect(parseInline('snake_case_name'), const [
        InlineSpanData('snake_case_name', InlineStyle.plain),
      ]);
    });
  });

  test('distanceKm and formatDistance', () {
    final london = (51.5072, -0.1276);
    final newYork = (40.7128, -74.0060);
    final km = distanceKm(london.$1, london.$2, newYork.$1, newYork.$2);
    expect(km, closeTo(5570, 10));
    expect(distanceKm(10, 10, 10, 10), 0);
    expect(formatDistance(0.85), '850 m');
    expect(formatDistance(12.44), '12.4 km');
    expect(formatDistance(km), '5,570 km');
  });

  group('spaced_repetition', () {
    final now = DateTime(2026, 10, 14);

    test('SM-2 intervals 1, 6, then × ease', () {
      var card = const ReviewState();
      expect(card.isDue(now), isTrue);
      card = card.review(4, now: now);
      expect(card.intervalDays, 1);
      card = card.review(4, now: now);
      expect(card.intervalDays, 6);
      card = card.review(4, now: now);
      expect(card.intervalDays, 15); // 6 × 2.5
      expect(card.nextReview, now.add(const Duration(days: 15)));
      expect(card.isDue(now), isFalse);
    });

    test('forgetting resets; ease stays within 1.3–3.0', () {
      var card = const ReviewState().review(4, now: now).review(4, now: now);
      card = card.review(2, now: now);
      expect(card.repetitions, 0);
      expect(card.intervalDays, 1);
      expect(card.easeFactor, closeTo(2.35, 1e-9));
      for (var i = 0; i < 20; i++) {
        card = card.review(2, now: now);
      }
      expect(card.easeFactor, 1.3);
      for (var i = 0; i < 20; i++) {
        card = card.review(5, now: now);
      }
      expect(card.easeFactor, 3.0);
    });

    test('JSON round-trip and due ordering', () {
      final reviewed = const ReviewState().review(4, now: now);
      expect(
        ReviewState.fromJson(reviewed.toJson()).nextReview,
        reviewed.nextReview,
      );

      final later = now.add(const Duration(days: 10));
      final due = dueCards({
        'new': const ReviewState(),
        'slightly': ReviewState(
          nextReview: later.subtract(const Duration(days: 1)),
        ),
        'very': ReviewState(
          nextReview: later.subtract(const Duration(days: 5)),
        ),
        'future': ReviewState(nextReview: later.add(const Duration(days: 1))),
      }, later);
      expect(due, ['very', 'slightly', 'new']);
      expect(
        dueCards(
          {'a': const ReviewState(), 'b': const ReviewState()},
          now,
          limit: 1,
        ),
        hasLength(1),
      );
    });
  });

  group('streak', () {
    final today = DateTime(2026, 10, 14, 20);

    test('recordActivity', () {
      expect(
        recordActivity(lastActiveDay: null, count: 0, today: today).count,
        1,
      );
      final yesterday = DateTime(2026, 10, 13);
      expect(
        recordActivity(lastActiveDay: yesterday, count: 4, today: today).count,
        5,
      );
      expect(
        recordActivity(lastActiveDay: today, count: 4, today: today).count,
        4,
      );
      expect(
        recordActivity(
          lastActiveDay: DateTime(2026, 10, 10),
          count: 9,
          today: today,
        ).count,
        1,
      );
      // Clock moved backwards: restart without moving the last day forward.
      final backwards = recordActivity(
        lastActiveDay: DateTime(2026, 10, 20),
        count: 3,
        today: today,
      );
      expect(backwards.count, 1);
      expect(backwards.lastActiveDay, DateTime.utc(2026, 10, 20));
    });

    test('currentStreak allows today to be not yet done', () {
      final days = [
        DateTime(2026, 10, 11),
        DateTime(2026, 10, 12),
        DateTime(2026, 10, 13, 22),
      ];
      expect(currentStreak(days, today), 3);
      expect(currentStreak([...days, today], today), 4);
      expect(currentStreak([DateTime(2026, 10, 1)], today), 0);
    });

    test('longestStreak', () {
      expect(
        longestStreak([
          DateTime(2026, 1, 1),
          DateTime(2026, 1, 2),
          DateTime(2026, 1, 2, 18),
          DateTime(2026, 1, 5),
          DateTime(2026, 1, 6),
          DateTime(2026, 1, 7),
        ]),
        3,
      );
      expect(longestStreak([]), 0);
    });
  });

  test('scaleQuantity', () {
    expect(scaleQuantity('2-3 cloves', 2), '4-6 cloves');
    expect(scaleQuantity('1 1/2 cups', 2), '3 cups');
    expect(scaleQuantity('1/2 cup', 3), '1.5 cup');
    expect(scaleQuantity('3', 0.5), '2');
    expect(scaleQuantity('1 egg', 0.25), '1 egg'); // counts never drop below 1
    expect(scaleQuantity('250 g', 0.5), '125 g');
    expect(scaleQuantity('400g', 1.5), '600g');
    expect(scaleQuantity('a pinch', 2), 'a pinch');
    expect(scaleQuantity('1/0 cup', 2), '1/0 cup');
    expect(scaleQuantity('2 tbsp', 1), '2 tbsp');
  });

  group('health_calc', () {
    test('Mifflin-St Jeor', () {
      expect(
        basalMetabolicRate(weightKg: 70, heightCm: 175, age: 30, sex: Sex.male),
        1649,
      );
      expect(
        basalMetabolicRate(
          weightKg: 60,
          heightCm: 165,
          age: 30,
          sex: Sex.female,
        ),
        1320,
      );
    });

    test('target, floor and macros', () {
      final kcal = dailyCalorieTarget(
        weightKg: 70,
        heightCm: 175,
        age: 30,
        sex: Sex.male,
        activity: ActivityLevel.moderate,
        goal: WeightGoal.lose,
      );
      expect(kcal, (1649 * 1.55).round() - 500);
      expect(
        dailyCalorieTarget(
          weightKg: 35,
          heightCm: 140,
          age: 80,
          sex: Sex.female,
          activity: ActivityLevel.sedentary,
          goal: WeightGoal.lose,
        ),
        1000,
      );
      final macros = macroTargets(2000, WeightGoal.lose);
      expect(macros.proteinG, 175);
      expect(macros.carbsG, 175);
      expect(macros.fatG, 67);
    });

    test('bmi', () {
      final value = bmi(weightKg: 70, heightCm: 175);
      expect(value, closeTo(22.86, 0.01));
      expect(bmiCategory(value), 'Healthy weight');
      expect(bmiCategory(17), 'Underweight');
      expect(bmiCategory(31), 'Obese');
    });
  });

  group('collection_utils', () {
    test('reorder, including ReorderableListView indexes', () {
      expect(reorder([1, 2, 3, 4], 0, 2), [2, 3, 1, 4]);
      expect(reorder([1, 2, 3, 4], 0, 3, fromReorderableListView: true), [
        2,
        3,
        1,
        4,
      ]);
      expect(reorder([1, 2, 3, 4], 3, 0, fromReorderableListView: true), [
        4,
        1,
        2,
        3,
      ]);
      final original = [1, 2];
      reorder(original, 0, 1);
      expect(original, [1, 2]); // not mutated
    });

    test('groupBy and distinctBy keep order', () {
      expect(groupBy(['apple', 'avocado', 'banana'], (s) => s[0]), {
        'a': ['apple', 'avocado'],
        'b': ['banana'],
      });
      expect(distinctBy([1, 11, 2, 21, 3], (n) => n % 10), [1, 2, 3]);
    });
  });

  test('AppLogger routes to the sink and suppresses debug when asked', () {
    final seen = <String>[];
    AppLogger.sink = (level, message, tag) =>
        seen.add('${level.name}:$tag:$message');
    addTearDown(() {
      AppLogger.sink = null;
      AppLogger.suppressDebug = false;
    });
    AppLogger.suppressDebug = true;
    AppLogger.debug('hidden');
    AppLogger.info('saved', tag: 'notes');
    AppLogger.error('failed', error: StateError('x'));
    expect(seen, ['info:notes:saved', 'error:app:failed']);
  });
}
