import 'package:competition_toolkit/13_smart_features/activity_timeline.dart';
import 'package:competition_toolkit/13_smart_features/automation.dart';
import 'package:competition_toolkit/13_smart_features/gamification.dart';
import 'package:competition_toolkit/13_smart_features/insights.dart';
import 'package:competition_toolkit/13_smart_features/predictions.dart';
import 'package:competition_toolkit/13_smart_features/rule_conditions.dart';
import 'package:competition_toolkit/13_smart_features/smart_scheduling.dart';
import 'package:competition_toolkit/13_smart_features/trends.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Daily series starting March 1st 2026 (a Sunday).
List<({DateTime day, double value})> days(List<double> values) => [
  for (var i = 0; i < values.length; i++)
    (day: DateTime(2026, 3, 1 + i), value: values[i]),
];

void main() {
  group('trends', () {
    test('linear fit, mean, deviation, moving average', () {
      final fit = linearFit([1, 2, 3, 4]);
      expect(fit.slope, closeTo(1, 1e-9));
      expect(fit.intercept, closeTo(1, 1e-9));
      expect(fit.r2, closeTo(1, 1e-9));
      expect(mean([]), 0);
      expect(standardDeviation([2, 4, 4, 4, 5, 5, 7, 9]), closeTo(2, 1e-9));
      expect(movingAverage([2, 4, 6, 8], 2), [2, 3, 5, 7]);
    });

    test('percent change and anomalies', () {
      expect(percentChange(0, 5), isNull);
      expect(percentChange(50, 75), 50);
      expect(anomalies([10, 10, 10, 10, 10, 10, 50]), [6]);
      expect(anomalies([5, 5, 5, 5]), isEmpty);
      expect(anomalies([1, 100, 1]), isEmpty); // too few points
    });

    test('analyzeTrend direction and half-on-half change', () {
      final up = analyzeTrend([10, 12, 14, 16, 18, 20]);
      expect(up.direction, TrendDirection.up);
      expect(up.changePercent, closeTo(50, 1e-9));
      expect(up.min, 10);
      expect(up.max, 20);
      expect(
        analyzeTrend([20, 18, 16, 14, 12, 10]).direction,
        TrendDirection.down,
      );
      expect(analyzeTrend([5, 5, 5, 5]).direction, TrendDirection.flat);
      expect(analyzeTrend([1, 2]).direction, TrendDirection.flat);
    });

    test('dailySeries fills gaps and weekdayAverages groups', () {
      final series = dailySeries<(DateTime, int)>(
        [
          (DateTime(2026, 3, 1, 9), 2),
          (DateTime(2026, 3, 1, 18), 3),
          (DateTime(2026, 3, 3), 4),
        ],
        dateOf: (e) => e.$1,
        valueOf: (e) => e.$2,
        from: DateTime(2026, 3, 1, 12),
        to: DateTime(2026, 3, 4),
      );
      expect([for (final d in series) d.value], [5, 0, 4, 0]);
      expect(weekdayAverages(series), {7: 5, 1: 0, 2: 4, 3: 0});
    });
  });

  group('predictions', () {
    test('forecastLinear extends the line with a residual band', () {
      final exact = forecastLinear([1, 2, 3], 2);
      expect([for (final f in exact) f.value], [4, 5]);
      expect(exact.first.low, exact.first.high);
      final noisy = forecastLinear([1, 3, 2, 4], 1).single;
      expect(noisy.low, lessThan(noisy.value));
      expect(noisy.high, greaterThan(noisy.value));
      expect(forecastLinear([], 3), isEmpty);
    });

    test('exponential smoothing', () {
      expect(exponentialSmoothing([10, 20], alpha: 0.5), 15);
      expect(exponentialSmoothing([]), 0);
    });

    test('predictWhenReached', () {
      final last = DateTime(2026, 3, 10);
      final eta = predictWhenReached(
        [0, 10, 20, 30],
        target: 100,
        lastDate: last,
      );
      expect(eta!.steps, 7);
      expect(eta.date, DateTime(2026, 3, 17));
      expect(
        predictWhenReached([30, 20, 10], target: 100, lastDate: last),
        isNull,
      );
      expect(predictWhenReached([100], target: 50, lastDate: last)!.steps, 0);
    });

    test('checkPace classifies progress against a steady pace', () {
      PaceCheck pace(num done) => checkPace(
        done: done,
        total: 100,
        start: DateTime(2026, 3, 1),
        due: DateTime(2026, 3, 11),
        now: DateTime(2026, 3, 6),
      );
      final onTrack = pace(50);
      expect(onTrack.status, PaceStatus.onTrack);
      expect(onTrack.expectedDone, closeTo(50, 1e-9));
      expect(
        onTrack.projectedFinish!.difference(DateTime(2026, 3, 11)).inMinutes,
        inInclusiveRange(0, 1),
      );
      expect(pace(20).status, PaceStatus.behind);
      expect(pace(80).status, PaceStatus.ahead);
      expect(pace(0).status, PaceStatus.notStarted);
      expect(pace(0).projectedFinish, isNull);
      expect(pace(100).status, PaceStatus.done);
    });

    test('RulePredictor: first matching rule wins, else fallback', () {
      const predictor = RulePredictor<String>([
        PredictionRule(
          when: FieldCondition('sleepHours', Op.lt, 5),
          outcome: 'tired',
          confidence: 0.8,
          because: 'Less than 5 hours of sleep',
        ),
        PredictionRule(
          when: FieldCondition('steps', Op.gt, 10000),
          outcome: 'energised',
        ),
      ], fallback: 'normal');

      final tired = predictor.predict({'sleepHours': 4, 'steps': 12000});
      expect(tired.outcome, 'tired');
      expect(tired.confidence, 0.8);
      final energised = predictor.predict({'steps': 12000});
      expect(energised.outcome, 'energised');
      expect(energised.because, 'steps > 10000');
      final normal = predictor.predict({});
      expect(
        (normal.outcome, normal.confidence, normal.because),
        ('normal', 0.0, null),
      );
    });
  });

  group('insights', () {
    const config = InsightConfig(
      metric: 'study time',
      unit: 'min',
      goalPerDay: 15,
    );
    final now = DateTime(2026, 3, 14, 20);
    final doubled = days([for (var i = 0; i < 14; i++) i < 7 ? 10 : 20]);

    test('too little data gives one "keep logging" message', () {
      final result = generateInsights(
        days([1, 2, 3]),
        config: config,
        now: now,
      );
      expect(result.single.id, 'need_data');
    });

    test('week change, goal streak and trend, most important first', () {
      final result = generateInsights(doubled, config: config, now: now);
      expect(
        [for (final i in result) i.id],
        ['week_change', 'goal_streak', 'trend'],
      );
      expect(
        result.first.message,
        'Your study time is 100% higher than last week (140 min vs 70 min).',
      );
      expect(result.first.tone, InsightTone.positive);
      expect(result[1].title, '7-day streak');
    });

    test('higherIsBetter=false flips the tone', () {
      final result = generateInsights(
        doubled,
        config: const InsightConfig(metric: 'spending', higherIsBetter: false),
        now: now,
      );
      expect(result.first.id, 'week_change');
      expect(result.first.tone, InsightTone.negative);
    });

    test('unusual day and unreachable goal', () {
      final spike = days([for (var i = 0; i < 13; i++) 10, 60]);
      final result = generateInsights(
        spike,
        config: const InsightConfig(
          metric: 'study time',
          unit: 'min',
          goalPerDay: 100,
        ),
        now: now,
      );
      final anomaly = result.firstWhere((i) => i.id == 'anomaly');
      expect(anomaly.title, 'Unusually high day');
      expect(anomaly.message, startsWith('Today you logged 60 min'));
      expect(result.map((i) => i.id), contains('goal_rate'));
    });

    testWidgets('InsightCard shows text and can be dismissed', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        wrap(
          InsightCard(
            insight: const Insight(
              id: 'x',
              title: 'Trending up',
              message: 'Nice work.',
              tone: InsightTone.positive,
              importance: 50,
            ),
            onDismiss: () => dismissed = true,
          ),
        ),
      );
      expect(find.text('Trending up'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up), findsOneWidget);
      await tester.tap(find.byTooltip('Dismiss'));
      expect(dismissed, isTrue);
    });
  });

  group('AutomationEngine', () {
    final lowStock = AutomationRule.fromJson({
      'id': 'low_stock',
      'name': 'Restock reminder',
      'trigger': 'item_used',
      'when': {'field': 'remaining', 'op': '<', 'value': 3},
      'actions': [
        {
          'type': 'add_to_list',
          'params': {'list': 'shopping'},
        },
      ],
      'cooldownMinutes': 60,
    });
    final t0 = DateTime(2026, 3, 1, 9);

    test('runs matching rules only, passing params', () async {
      final added = <String>[];
      final engine = AutomationEngine(
        rules: [lowStock],
        handlers: {
          'add_to_list': (event, params) async =>
              added.add('${event.data['name']}→${params['list']}'),
        },
      );
      await engine.handle(
        AppEvent('item_used', {'name': 'Eggs', 'remaining': 5}, t0),
      );
      await engine.handle(
        AppEvent('item_bought', {'name': 'Milk', 'remaining': 1}, t0),
      );
      final runs = await engine.handle(
        AppEvent('item_used', {'name': 'Milk', 'remaining': 1}, t0),
      );
      expect(runs.single.succeeded, isTrue);
      expect(added, ['Milk→shopping']);
      expect(
        lowStock.describe(),
        'When item_used and remaining < 3 → add_to_list',
      );
    });

    test('cooldown, enable/disable and rule edits', () async {
      var count = 0;
      final engine = AutomationEngine(
        rules: [lowStock],
        handlers: {'add_to_list': (_, _) async => count++},
      );
      AppEvent used(Duration after) =>
          AppEvent('item_used', {'remaining': 0}, t0.add(after));
      await engine.handle(used(Duration.zero));
      await engine.handle(used(const Duration(minutes: 30)));
      expect(count, 1);
      await engine.handle(used(const Duration(minutes: 61)));
      expect(count, 2);

      engine.setEnabled('low_stock', false);
      await engine.handle(used(const Duration(hours: 5)));
      expect(count, 2);

      engine.upsertRule(lowStock.copyWith(enabled: true));
      expect(engine.rules, hasLength(1));
      await engine.handle(used(const Duration(hours: 6)));
      expect(count, 3);

      engine.removeRule('low_stock');
      await engine.handle(used(const Duration(hours: 9)));
      expect(count, 3);
    });

    test('a failing or missing handler does not stop the others', () async {
      var okCalled = false;
      final engine = AutomationEngine(
        rules: const [
          AutomationRule(
            id: 'r',
            name: 'r',
            trigger: 'go',
            actions: [
              AutomationAction('fail'),
              AutomationAction('missing'),
              AutomationAction('ok'),
            ],
          ),
        ],
        handlers: {
          'fail': (_, _) async => throw Exception('boom'),
          'ok': (_, _) async => okCalled = true,
        },
      );
      final runs = await engine.handle(AppEvent('go'));
      expect([for (final r in runs) r.succeeded], [false, false, true]);
      expect(runs[1].error, isA<StateError>());
      expect(okCalled, isTrue);
      expect(engine.log, hasLength(3));
    });

    test('JSON round trip keeps the rule', () {
      final copy = AutomationRule.fromJson(lowStock.toJson());
      expect(copy.describe(), lowStock.describe());
      expect(copy.cooldown, const Duration(minutes: 60));
      expect(copy.actions.single.params, {'list': 'shopping'});
    });
  });

  group('smart scheduling', () {
    DateTime mon(int hour, [int minute = 0]) =>
        DateTime(2026, 3, 9, hour, minute); // a Monday
    final busy = [TimeSlot(mon(10), mon(11)), TimeSlot(mon(13), mon(14))];
    const hours = WorkingHours(startHour: 9, endHour: 17);

    test('findFreeSlots respects busy time, hours and weekdays', () {
      final free = findFreeSlots(
        busy: busy,
        from: mon(8),
        until: DateTime(2026, 3, 10),
        hours: hours,
      );
      expect(free, [
        TimeSlot(mon(9), mon(10)),
        TimeSlot(mon(11), mon(13)),
        TimeSlot(mon(14), mon(17)),
      ]);
      expect(
        findFreeSlots(
          busy: busy,
          from: mon(8),
          until: DateTime(2026, 3, 10),
          hours: hours,
          minLength: const Duration(minutes: 90),
        ),
        hasLength(2),
      );
      expect(
        findFreeSlots(
          busy: const [],
          from: DateTime(2026, 3, 14),
          until: DateTime(2026, 3, 16),
          hours: const WorkingHours(days: {1, 2, 3, 4, 5}),
        ),
        isEmpty,
      );
    });

    test('scheduleTasks places by deadline and explains failures', () {
      final plan = scheduleTasks(
        tasks: [
          const SchedulableTask(
            id: 'reading',
            duration: Duration(minutes: 45),
            priority: 2,
          ),
          SchedulableTask(
            id: 'essay',
            duration: const Duration(hours: 2),
            deadline: mon(17),
            priority: 5,
          ),
          const SchedulableTask(id: 'marathon', duration: Duration(hours: 9)),
          SchedulableTask(
            id: 'late',
            duration: const Duration(minutes: 30),
            deadline: mon(8),
          ),
        ],
        busy: busy,
        from: mon(9),
        until: DateTime(2026, 3, 10, 17),
        hours: hours,
      );
      expect(
        [for (final (t, s) in plan.placed) (t.id, s.start)],
        [('reading', mon(9)), ('essay', mon(11))],
      );
      final reasons = {for (final (t, r) in plan.unplaced) t.id: r};
      expect(reasons['marathon'], startsWith('Longer than a working day'));
      expect(reasons['late'], 'Deadline has already passed');
    });

    test('keeps a buffer between placed tasks', () {
      final plan = scheduleTasks(
        tasks: const [
          SchedulableTask(id: 'a', duration: Duration(hours: 1)),
          SchedulableTask(id: 'b', duration: Duration(hours: 1)),
        ],
        busy: const [],
        from: mon(9),
        until: mon(17),
        hours: hours,
      );
      expect(
        [for (final (_, s) in plan.placed) s.start],
        [mon(9), mon(10, 10)],
      );
    });

    test('conflicts and first common slot', () {
      expect(
        findConflicts([
          TimeSlot(mon(9), mon(10)),
          TimeSlot(mon(9, 30), mon(11)),
          TimeSlot(mon(11), mon(12)),
        ]),
        [(0, 1)],
      );
      expect(
        firstCommonSlot(
          calendars: [
            [TimeSlot(mon(9), mon(12))],
            [TimeSlot(mon(12), mon(13))],
          ],
          length: const Duration(hours: 1),
          from: mon(9),
          until: mon(17),
          hours: hours,
        ),
        TimeSlot(mon(13), mon(14)),
      );
    });
  });

  group('gamification', () {
    const curve = LevelCurve();

    test('level curve', () {
      expect(curve.xpForNextLevel(1), 100);
      expect(curve.xpForNextLevel(3), 225);
      expect(curve.xpToReach(3), 250);
      expect(curve.progressFor(0).level, 1);
      final p = curve.progressFor(260);
      expect((p.level, p.xpIntoLevel, p.xpNeeded), (3, 10, 225));
    });

    test('XP rules with capped streak bonus', () {
      const rules = XpRules({'task_done': 10});
      expect(rules.pointsFor('task_done'), 10);
      expect(rules.pointsFor('task_done', streakDays: 4), 12);
      expect(rules.pointsFor('task_done', streakDays: 20), 15);
      expect(rules.pointsFor('unknown'), 0);
    });

    test('badges, leaderboard and challenges', () {
      final badges = [
        AchievementBadge.fromJson({
          'id': 'first',
          'title': 'First steps',
          'icon': 'flag',
          'when': {'field': 'tasksDone', 'op': '>=', 'value': 1},
        }),
        AchievementBadge.fromJson({
          'id': 'streak7',
          'title': 'On fire',
          'icon': 'fire',
          'when': {'field': 'streak', 'op': '>=', 'value': 7},
        }),
      ];
      expect(badges.first.icon, Icons.flag);
      final unlocked = newlyUnlocked(
        badges,
        stats: {'tasksDone': 3, 'streak': 7},
        alreadyEarned: {'first'},
      );
      expect([for (final b in unlocked) b.id], ['streak7']);

      final ranks = leaderboard([
        ('a', 50),
        ('b', 40),
        ('c', 40),
        ('d', 10),
      ], (e) => e.$2);
      expect([for (final r in ranks) r.rank], [1, 2, 2, 4]);

      final challenge = Challenge(
        id: 'c',
        title: 'Study 300 minutes',
        target: 300,
        ends: DateTime(2026, 3, 8),
      );
      final half = challenge.progress(150, DateTime(2026, 3, 5));
      expect(
        (half.fraction, half.completed, half.expired, half.remaining),
        (0.5, false, false, 150),
      );
      expect(challenge.progress(100, DateTime(2026, 3, 9)).expired, isTrue);
      final done = challenge.progress(400, DateTime(2026, 3, 9));
      expect(
        (done.completed, done.expired, done.fraction, done.remaining),
        (true, false, 1.0, 0),
      );
    });

    testWidgets('XpProgressBar and BadgeGrid', (tester) async {
      AchievementBadge? tapped;
      final badges = [
        const AchievementBadge(
          id: 'first',
          title: 'First steps',
          when: Always(),
        ),
        const AchievementBadge(id: 'fire', title: 'On fire', when: Always()),
      ];
      await tester.pumpWidget(
        wrap(
          Column(
            children: [
              const XpProgressBar(totalXp: 260),
              BadgeGrid(
                badges: badges,
                earned: const {'first'},
                onTap: (b) => tapped = b,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Level 3'), findsOneWidget);
      expect(find.text('10 / 225 XP'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Level 3, 10 of 225 experience points to the next level',
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('First steps, earned'), findsOneWidget);
      expect(find.bySemanticsLabel('On fire, locked'), findsOneWidget);
      await tester.tap(find.text('On fire'));
      expect(tapped?.id, 'fire');
    });
  });

  group('activity timeline', () {
    final now = DateTime(2026, 3, 11, 15); // a Wednesday
    final events = [
      ActivityEvent(
        id: 't1',
        title: 'Started essay',
        at: DateTime(2026, 3, 11, 10),
      ),
      ActivityEvent(
        id: 't2',
        title: 'Finished essay',
        at: DateTime(2026, 3, 11, 14),
      ),
      ActivityEvent(
        id: 'y',
        title: 'Joined group',
        at: DateTime(2026, 3, 10, 9),
      ),
      ActivityEvent(id: 'm', title: 'Set goal', at: DateTime(2026, 3, 9, 9)),
      ActivityEvent(id: 'f', title: 'Signed up', at: DateTime(2026, 2, 1)),
      ActivityEvent(id: 'o', title: 'Invited', at: DateTime(2025, 12, 31)),
    ];

    test('groups newest first with friendly day labels', () {
      final groups = groupActivityByDay(events, now: now);
      expect(
        [for (final g in groups) g.label],
        ['Today', 'Yesterday', 'Monday', 'Feb 1', 'Dec 31, 2025'],
      );
      expect([for (final e in groups.first.events) e.id], ['t2', 't1']);
    });

    testWidgets('renders groups, times and taps', (tester) async {
      ActivityEvent? tapped;
      await tester.pumpWidget(
        wrap(
          SingleChildScrollView(
            child: ActivityTimeline(
              events: events,
              now: now,
              onTap: (e) => tapped = e,
            ),
          ),
        ),
      );
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Finished essay'), findsOneWidget);
      expect(find.text('2:00 PM'), findsOneWidget);
      await tester.tap(find.text('Joined group'));
      expect(tapped?.id, 'y');

      await tester.pumpWidget(wrap(const ActivityTimeline(events: [])));
      expect(find.text('No activity yet'), findsOneWidget);
    });
  });
}
