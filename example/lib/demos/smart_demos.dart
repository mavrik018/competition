import 'dart:async';

import 'package:competition_toolkit/02_ui_elements/app_buttons.dart';
import 'package:competition_toolkit/02_ui_elements/line_chart.dart';
import 'package:competition_toolkit/02_ui_elements/radial_gauge.dart';
import 'package:competition_toolkit/03_feedback/app_snackbars.dart';
import 'package:competition_toolkit/05_forms/segmented_control.dart';
import 'package:competition_toolkit/13_smart_features/accessibility.dart';
import 'package:competition_toolkit/13_smart_features/automation.dart';
import 'package:competition_toolkit/13_smart_features/contextual_actions.dart';
import 'package:competition_toolkit/13_smart_features/gamification.dart';
import 'package:competition_toolkit/13_smart_features/insights.dart';
import 'package:competition_toolkit/13_smart_features/personalization.dart';
import 'package:competition_toolkit/13_smart_features/predictions.dart';
import 'package:competition_toolkit/13_smart_features/priority_scoring.dart';
import 'package:competition_toolkit/13_smart_features/realtime_collaboration.dart';
import 'package:competition_toolkit/13_smart_features/recommendations.dart';
import 'package:competition_toolkit/13_smart_features/risk_scoring.dart';
import 'package:competition_toolkit/13_smart_features/smart_matching.dart';
import 'package:competition_toolkit/13_smart_features/smart_scheduling.dart';
import 'package:competition_toolkit/13_smart_features/trends.dart';
import 'package:competition_toolkit/13_smart_features/voice_input.dart';
import 'package:flutter/material.dart';

import '../main.dart';

const _section = 'Smart features (rule-based, offline)';

final smartDemos = <Demo>[
  Demo(_section, 'Smart matching', (_) => const _Matching()),
  Demo(_section, 'Recommendations', (_) => const _Recommendations()),
  Demo(_section, 'Priority scoring', (_) => const _Priority()),
  Demo(_section, 'Risk scorecard', (_) => const _Risk()),
  Demo(
    _section,
    'Trends, forecasts & insights',
    (_) => const _TrendsAndInsights(),
  ),
  Demo(_section, 'Smart scheduling', (_) => const _Scheduling()),
  Demo(_section, 'Gamification', (_) => const _Gamification()),
  Demo(_section, 'Automation rules', (_) => const _Automation()),
  Demo(_section, 'Contextual actions', (_) => const _Contextual()),
  Demo(_section, 'Personalization', (_) => const _Personalization()),
  Demo(_section, 'Accessibility', (_) => const _Accessibility()),
  Demo(
    _section,
    'Voice commands',
    (_) => const _Voice(),
    subtitle: 'Fake speech engine + rule-based parser',
  ),
  Demo(
    _section,
    'Real-time collaboration',
    (_) => const _Collaboration(),
    subtitle: 'Two replicas over an in-memory hub',
  ),
];

// ── Matching ────────────────────────────────────────────────────────────────

typedef _Student = ({Set<String> subjects, double maxRate, double km});
typedef _Tutor = ({String name, Set<String> subjects, double rate, double km});

class _Matching extends StatefulWidget {
  const _Matching();

  @override
  State<_Matching> createState() => _MatchingState();
}

class _MatchingState extends State<_Matching> {
  final _wanted = {'maths'};
  static const _tutors = <_Tutor>[
    (name: 'Ana', subjects: {'maths', 'physics'}, rate: 25, km: 2),
    (name: 'Ben', subjects: {'maths'}, rate: 15, km: 9),
    (name: 'Chen', subjects: {'chemistry', 'physics'}, rate: 18, km: 1),
    (name: 'Dee', subjects: {'maths', 'chemistry'}, rate: 30, km: 4),
  ];
  static final _matcher = SmartMatcher<_Student, _Tutor>([
    MatchCriterion(
      'Subjects',
      weight: 3,
      required: true,
      score: (s, t) => coverage(s.subjects, t.subjects),
    ),
    MatchCriterion(
      'Distance',
      weight: 2,
      score: (s, t) => proximityScore(t.km, maxKm: 10),
    ),
    MatchCriterion('Budget', score: (s, t) => t.rate <= s.maxRate ? 1 : 0),
  ], minScore: 0.3);

  @override
  Widget build(BuildContext context) {
    final results = _matcher.rank((
      subjects: _wanted,
      maxRate: 20,
      km: 0,
    ), _tutors);
    return ListView(
      children: [
        DemoBlock(
          'I need help with…',
          note: 'Budget €20/h. Subjects is a required criterion.',
          child: Wrap(
            spacing: 8,
            children: [
              for (final s in ['maths', 'physics', 'chemistry'])
                FilterChip(
                  label: Text(s),
                  selected: _wanted.contains(s),
                  onSelected: (on) =>
                      setState(() => on ? _wanted.add(s) : _wanted.remove(s)),
                ),
            ],
          ),
        ),
        for (final r in results)
          ListTile(
            leading: CircleAvatar(child: Text('${r.percent}')),
            title: Text(r.candidate.name),
            subtitle: Text(r.explanation),
            trailing: Text(r.strengths().join(', ')),
          ),
        if (results.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No tutor covers those subjects.'),
          ),
      ],
    );
  }
}

// ── Recommendations ─────────────────────────────────────────────────────────

typedef _Recipe = ({String id, String title, Set<String> tags});

const _recipes = <_Recipe>[
  (id: 'r1', title: 'Lentil soup', tags: {'soup', 'vegan', 'quick'}),
  (id: 'r2', title: 'Tomato soup', tags: {'soup', 'vegetarian', 'quick'}),
  (id: 'r3', title: 'Chickpea curry', tags: {'curry', 'vegan', 'spicy'}),
  (id: 'r4', title: 'Beef stew', tags: {'stew', 'meat'}),
  (id: 'r5', title: 'Thai green curry', tags: {'curry', 'spicy', 'thai'}),
  (id: 'r6', title: 'Pad thai', tags: {'noodles', 'thai', 'quick'}),
];

class _Recommendations extends StatefulWidget {
  const _Recommendations();

  @override
  State<_Recommendations> createState() => _RecommendationsState();
}

class _RecommendationsState extends State<_Recommendations> {
  final _liked = <String>{'r1'};
  static final _recommender = Recommender<_Recipe>(
    idOf: (r) => r.id,
    tagsOf: (r) => r.tags,
    titleOf: (r) => r.title,
  );
  // What other (imaginary) users liked — powers "liked together".
  static const _histories = [
    {'r1', 'r3'},
    {'r1', 'r3', 'r5'},
    {'r4'},
    {'r5', 'r6'},
  ];

  @override
  Widget build(BuildContext context) {
    final picks = _recommender.recommend(
      catalog: _recipes,
      liked: _liked,
      histories: _histories,
      limit: 4,
    );
    return ListView(
      children: [
        DemoBlock(
          'Tap ♥ to like',
          child: Wrap(
            spacing: 8,
            children: [
              for (final r in _recipes)
                FilterChip(
                  avatar: const Icon(Icons.favorite, size: 16),
                  label: Text(r.title),
                  selected: _liked.contains(r.id),
                  onSelected: (on) => setState(
                    () => on ? _liked.add(r.id) : _liked.remove(r.id),
                  ),
                ),
            ],
          ),
        ),
        const DemoBlock('You might also like', child: SizedBox.shrink()),
        for (final p in picks)
          ListTile(
            title: Text(p.item.title),
            subtitle: Text(p.reason),
            trailing: Text(p.score.toStringAsFixed(2)),
          ),
      ],
    );
  }
}

// ── Priority ────────────────────────────────────────────────────────────────

class _Priority extends StatelessWidget {
  const _Priority();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final tasks = [
      (
        'Submit lab report',
        PriorityInput(
          due: now.subtract(const Duration(hours: 3)),
          importance: 5,
        ),
      ),
      ('Reply to Ana', const PriorityInput(importance: 2, effortHours: 0.2)),
      (
        'Revise chapter 4',
        PriorityInput(
          due: now.add(const Duration(days: 2)),
          importance: 4,
          effortHours: 3,
        ),
      ),
      (
        'Clean desk',
        PriorityInput(
          importance: 1,
          createdAt: now.subtract(const Duration(days: 45)),
        ),
      ),
    ];
    final ranked = rankByPriority(tasks, (t) => t.$2, now: now);
    return ListView(
      children: [
        for (final (task, score) in ranked)
          ListTile(
            leading: CircleAvatar(child: Text('${score.score}')),
            title: Text(task.$1),
            subtitle: Text(
              [
                score.band.name,
                eisenhowerQuadrant(task.$2, now: now).name,
                ...score.reasons,
              ].join(' · '),
            ),
          ),
      ],
    );
  }
}

// ── Risk ────────────────────────────────────────────────────────────────────

class _Risk extends StatefulWidget {
  const _Risk();

  @override
  State<_Risk> createState() => _RiskState();
}

class _RiskState extends State<_Risk> {
  double _attendance = 0.9;
  double _late = 1;
  bool _mentor = false;

  static final _model = RiskModel.fromJson({
    'levels': {'moderate': 3, 'high': 6, 'severe': 9},
    'rules': [
      {
        'id': 'attendance',
        'label': 'Attendance under 75%',
        'points': 4,
        'when': {'field': 'attendance', 'op': '<', 'value': 0.75},
      },
      {
        'id': 'late',
        'label': '3+ late submissions',
        'points': 3,
        'when': {'field': 'late', 'op': '>=', 'value': 3},
      },
      {
        'id': 'very_late',
        'label': '6+ late submissions',
        'points': 3,
        'when': {'field': 'late', 'op': '>=', 'value': 6},
      },
      {
        'id': 'mentor',
        'label': 'Has a mentor (protective)',
        'points': -2,
        'when': {'field': 'mentor', 'op': '==', 'value': true},
      },
    ],
  });

  @override
  Widget build(BuildContext context) {
    final result = _model.assess({
      'attendance': _attendance,
      'late': _late.round(),
      'mentor': _mentor,
    });
    return ListView(
      children: [
        DemoBlock(
          'Inputs',
          child: Column(
            children: [
              Text('Attendance ${(_attendance * 100).round()}%'),
              Slider(
                value: _attendance,
                onChanged: (v) => setState(() => _attendance = v),
              ),
              Text('Late submissions ${_late.round()}'),
              Slider(
                value: _late,
                max: 10,
                divisions: 10,
                onChanged: (v) => setState(() => _late = v),
              ),
              SwitchListTile(
                title: const Text('Has a mentor'),
                value: _mentor,
                onChanged: (v) => setState(() => _mentor = v),
              ),
            ],
          ),
        ),
        DemoBlock(
          'Result: ${result.level.name} (${result.points} points)',
          note: 'A transparent scorecard, not a validated prediction.',
          child: Row(
            children: [
              RadialGauge(
                value: result.fraction,
                size: 72,
                child: Text('${result.points}'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  result.reasons.isEmpty
                      ? 'No risk factors.'
                      : result.reasons.join('\n'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Trends & insights ───────────────────────────────────────────────────────

class _TrendsAndInsights extends StatelessWidget {
  const _TrendsAndInsights();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // 28 days of synthetic study minutes: rising, with Saturday peaks.
    final days = [
      for (var i = 0; i < 28; i++)
        (
          day: today.subtract(Duration(days: 27 - i)),
          value: 30 + i * 1.5 + ((i * 37) % 11 - 5).toDouble(),
        ),
    ];
    final values = [for (final d in days) d.value];
    final summary = analyzeTrend(values);
    final forecast = forecastLinear(values, 7);
    final cumulative = <double>[];
    for (final v in values) {
      cumulative.add((cumulative.isEmpty ? 0 : cumulative.last) + v);
    }
    final eta = predictWhenReached(cumulative, target: 2500, lastDate: today);
    final insights = generateInsights(
      days,
      config: const InsightConfig(
        metric: 'study time',
        unit: 'min',
        goalPerDay: 60,
      ),
      now: now,
    );
    return ListView(
      children: [
        DemoBlock(
          'Last 14 days',
          note:
              '${summary.direction.name}, ${summary.slope.toStringAsFixed(1)} min/day '
              '(fit ${(summary.fit * 100).round()}%)',
          child: SimpleLineChart(values: values.sublist(14)),
        ),
        DemoBlock(
          'Forecast (straight-line extrapolation)',
          child: Text(
            'Next 7 days ≈ ${forecast.map((f) => f.value.round()).join(', ')} min\n'
            '${eta == null ? 'Not increasing' : '2,500 min total reached in ${eta.steps} days'}',
          ),
        ),
        DemoBlock(
          'Insights',
          child: Column(
            children: [for (final i in insights) InsightCard(insight: i)],
          ),
        ),
      ],
    );
  }
}

// ── Scheduling ──────────────────────────────────────────────────────────────

class _Scheduling extends StatelessWidget {
  const _Scheduling();

  String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day + 1); // tomorrow
    DateTime at(int h, [int m = 0]) =>
        DateTime(day.year, day.month, day.day, h, m);
    final busy = [TimeSlot(at(10), at(11, 30)), TimeSlot(at(13), at(14))];
    final plan = scheduleTasks(
      tasks: [
        SchedulableTask(
          id: 'Essay draft',
          duration: const Duration(hours: 2),
          deadline: at(17),
          priority: 5,
        ),
        const SchedulableTask(
          id: 'Reading',
          duration: Duration(minutes: 45),
          priority: 2,
        ),
        const SchedulableTask(id: 'Gym', duration: Duration(hours: 1)),
        const SchedulableTask(
          id: 'Marathon study',
          duration: Duration(hours: 10),
        ),
      ],
      busy: busy,
      from: at(9),
      until: at(18),
      hours: const WorkingHours(startHour: 9, endHour: 18),
    );
    return ListView(
      children: [
        DemoBlock(
          'Tomorrow, 09:00–18:00',
          note: 'Busy: 10:00–11:30 lecture, 13:00–14:00 lunch',
          child: Column(
            children: [
              for (final (task, slot) in plan.placed)
                ListTile(
                  leading: const Icon(Icons.event_available),
                  title: Text(task.id),
                  trailing: Text('${_time(slot.start)}–${_time(slot.end)}'),
                ),
              for (final (task, reason) in plan.unplaced)
                ListTile(
                  leading: const Icon(Icons.event_busy),
                  title: Text(task.id),
                  subtitle: Text(reason),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Gamification ────────────────────────────────────────────────────────────

class _Gamification extends StatefulWidget {
  const _Gamification();

  @override
  State<_Gamification> createState() => _GamificationState();
}

class _GamificationState extends State<_Gamification> {
  int _xp = 80;
  int _tasksDone = 0;
  final _earned = <String>{};
  static const _rules = XpRules({'task_done': 25});
  static final _badges = [
    AchievementBadge.fromJson({
      'id': 'first',
      'title': 'First steps',
      'icon': 'flag',
      'when': {'field': 'tasksDone', 'op': '>=', 'value': 1},
    }),
    AchievementBadge.fromJson({
      'id': 'five',
      'title': 'High five',
      'icon': 'star',
      'when': {'field': 'tasksDone', 'op': '>=', 'value': 5},
    }),
    AchievementBadge.fromJson({
      'id': 'level3',
      'title': 'Level 3',
      'icon': 'medal',
      'when': {'field': 'level', 'op': '>=', 'value': 3},
    }),
  ];

  void _complete() {
    setState(() {
      _tasksDone++;
      _xp += _rules.pointsFor('task_done', streakDays: 4);
    });
    final unlocked = newlyUnlocked(
      _badges,
      stats: {
        'tasksDone': _tasksDone,
        'level': const LevelCurve().progressFor(_xp).level,
      },
      alreadyEarned: _earned,
    );
    if (unlocked.isEmpty) return;
    setState(() => _earned.addAll(unlocked.map((b) => b.id)));
    context.showSuccess(
      'Badge unlocked: ${unlocked.map((b) => b.title).join(', ')}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final board = leaderboard([
      ('You', _xp),
      ('Ana', 240),
      ('Ben', 240),
      ('Chen', 90),
    ], (e) => e.$2);
    return ListView(
      children: [
        DemoBlock(
          'XP',
          note: '+25 XP per task, +20% for a 4-day streak',
          child: Column(
            children: [
              XpProgressBar(totalXp: _xp),
              const SizedBox(height: 12),
              AppButton(
                label: 'Complete a task',
                icon: Icons.check,
                expand: true,
                onPressed: _complete,
              ),
            ],
          ),
        ),
        DemoBlock(
          'Badges',
          child: BadgeGrid(badges: _badges, earned: _earned),
        ),
        DemoBlock(
          'Leaderboard (ties share a rank)',
          child: Column(
            children: [
              for (final r in board)
                ListTile(
                  dense: true,
                  leading: Text('#${r.rank}'),
                  title: Text(r.entry.$1),
                  trailing: Text('${r.entry.$2} XP'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Automation ──────────────────────────────────────────────────────────────

class _Automation extends StatefulWidget {
  const _Automation();

  @override
  State<_Automation> createState() => _AutomationState();
}

class _AutomationState extends State<_Automation> {
  int _milk = 4;
  final _shopping = <String>[];
  final _log = <String>[];
  late final AutomationEngine _engine = AutomationEngine(
    rules: [
      AutomationRule.fromJson({
        'id': 'restock',
        'name': 'Restock reminder',
        'trigger': 'item_used',
        'when': {'field': 'remaining', 'op': '<', 'value': 2},
        'actions': [
          {'type': 'add_to_list'},
          {'type': 'log'},
        ],
        'cooldownMinutes': 1,
      }),
    ],
    handlers: {
      'add_to_list': (event, _) async {
        final name = event.data['name']! as String;
        if (!_shopping.contains(name)) setState(() => _shopping.add(name));
      },
      'log': (event, _) async => setState(
        () => _log.insert(0, 'Rule fired for ${event.data['name']}'),
      ),
    },
  );

  Future<void> _useMilk() async {
    if (_milk == 0) return;
    setState(() => _milk--);
    await _engine.handle(
      AppEvent('item_used', {'name': 'Milk', 'remaining': _milk}),
    );
  }

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      DemoBlock(
        'Rule',
        note: 'Stored as JSON — editable without a new build.',
        child: Text(_engine.rules.single.describe()),
      ),
      DemoBlock(
        'Milk left: $_milk',
        child: AppButton(
          label: 'Use one',
          variant: ButtonVariant.tonal,
          onPressed: _useMilk,
        ),
      ),
      DemoBlock(
        'Shopping list',
        child: Text(_shopping.isEmpty ? '(empty)' : _shopping.join(', ')),
      ),
      DemoBlock(
        'Automation log',
        child: Text(_log.isEmpty ? '(nothing yet)' : _log.join('\n')),
      ),
    ],
  );
}

// ── Contextual actions ──────────────────────────────────────────────────────

class _Contextual extends StatefulWidget {
  const _Contextual();

  @override
  State<_Contextual> createState() => _ContextualState();
}

class _ContextualState extends State<_Contextual> {
  int _hour = 8;
  bool _lowStock = true;
  String? _ran;
  final _engine = ContextualActionEngine([
    ContextualAction.fromJson({
      'id': 'focus',
      'label': 'Start focus session',
      'icon': 'timer',
      'priority': 5,
      'when': {'field': 'partOfDay', 'op': '==', 'value': 'morning'},
    }),
    ContextualAction.fromJson({
      'id': 'dinner',
      'label': 'Log dinner',
      'icon': 'meal',
      'priority': 4,
      'when': {'field': 'partOfDay', 'op': '==', 'value': 'evening'},
    }),
    ContextualAction.fromJson({
      'id': 'water',
      'label': 'Drink water',
      'icon': 'water',
      'when': {'field': 'partOfDay', 'op': '==', 'value': 'afternoon'},
    }),
    ContextualAction.fromJson({
      'id': 'restock',
      'label': 'Restock milk',
      'icon': 'cart',
      'priority': 2,
      'when': {'field': 'lowStock', 'op': '==', 'value': true},
    }),
  ]);

  @override
  Widget build(BuildContext context) {
    final facts = contextFacts(DateTime(2026, 1, 5, _hour), {
      'lowStock': _lowStock,
    });
    return ListView(
      children: [
        DemoBlock(
          'Context',
          child: Column(
            children: [
              SegmentedControl<int>(
                segments: const {8: 'Morning', 14: 'Afternoon', 19: 'Evening'},
                selected: _hour,
                onChanged: (h) => setState(() => _hour = h),
              ),
              SwitchListTile(
                title: const Text('Milk running low'),
                value: _lowStock,
                onChanged: (v) => setState(() => _lowStock = v),
              ),
            ],
          ),
        ),
        DemoBlock(
          'Suggested now',
          note: 'Tap × to hide one for 12 hours.',
          child: ContextualActionBar(
            actions: _engine.suggest(facts),
            onSelected: (a) => setState(() => _ran = a.label),
            onDismissed: (a) => setState(() => _engine.dismiss(a.id)),
          ),
        ),
        if (_ran != null)
          Padding(padding: const EdgeInsets.all(16), child: Text('Ran: $_ran')),
      ],
    );
  }
}

// ── Personalization ─────────────────────────────────────────────────────────

class _Personalization extends StatefulWidget {
  const _Personalization();

  @override
  State<_Personalization> createState() => _PersonalizationState();
}

class _PersonalizationState extends State<_Personalization> {
  final _profile = PreferenceProfile();

  @override
  Widget build(BuildContext context) {
    final ordered = _profile.orderByAffinity(_recipes, (r) => r.tags);
    final top = _profile.topKeys(limit: 3);
    return ListView(
      children: [
        DemoBlock(
          'Learnt so far',
          note:
              'Open = +1, favourite = +3, hide = −3. Scores halve every 14 days.',
          child: Text(
            top.isEmpty
                ? 'Nothing yet — interact with the list.'
                : top
                      .map((e) => '${e.key} ${e.score.toStringAsFixed(1)}')
                      .join(' · '),
          ),
        ),
        for (final r in ordered)
          ListTile(
            title: Text(r.title),
            subtitle: Text(r.tags.join(', ')),
            onTap: () => setState(() {
              for (final t in r.tags) {
                _profile.record(t, weight: InteractionWeight.view);
              }
            }),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Favourite ${r.title}',
                  icon: const Icon(Icons.favorite_border),
                  onPressed: () => setState(() {
                    for (final t in r.tags) {
                      _profile.record(t, weight: InteractionWeight.favourite);
                    }
                  }),
                ),
                IconButton(
                  tooltip: 'Hide ${r.title}',
                  icon: const Icon(Icons.visibility_off_outlined),
                  onPressed: () => setState(() {
                    for (final t in r.tags) {
                      _profile.record(t, weight: InteractionWeight.hide);
                    }
                  }),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Accessibility ───────────────────────────────────────────────────────────

class _Accessibility extends StatefulWidget {
  const _Accessibility();

  @override
  State<_Accessibility> createState() => _AccessibilityState();
}

class _AccessibilityState extends State<_Accessibility> {
  var _prefs = const AccessibilityPreferences();

  @override
  Widget build(BuildContext context) {
    final pairs = [
      ('Grey on white', Colors.grey, Colors.white),
      ('#767676 on white', const Color(0xFF767676), Colors.white),
      ('White on indigo', Colors.white, Colors.indigo),
    ];
    return ListView(
      children: [
        DemoBlock(
          'In-app settings',
          child: Column(
            children: [
              Text('Text size ×${_prefs.textScale.toStringAsFixed(1)}'),
              Slider(
                value: _prefs.textScale,
                min: 0.8,
                max: 2,
                divisions: 12,
                onChanged: (v) =>
                    setState(() => _prefs = _prefs.copyWith(textScale: v)),
              ),
              SwitchListTile(
                title: const Text('Bold text'),
                value: _prefs.boldText,
                onChanged: (v) =>
                    setState(() => _prefs = _prefs.copyWith(boldText: v)),
              ),
              SwitchListTile(
                title: const Text('High contrast'),
                value: _prefs.highContrast,
                onChanged: (v) =>
                    setState(() => _prefs = _prefs.copyWith(highContrast: v)),
              ),
            ],
          ),
        ),
        DemoBlock(
          'Preview',
          child: AccessibilityScope(
            preferences: _prefs,
            child: Builder(
              builder: (context) => Card(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your next class',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Text('Biology, room 2.14, at 10:00'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          AppButton(label: 'Directions', onPressed: () {}),
                          const SizedBox(width: 8),
                          AccessibleTapTarget(
                            label: 'Remind me',
                            onTap: () => announce(context, 'Reminder set'),
                            child: const Icon(Icons.alarm_add, size: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        DemoBlock(
          'Contrast checker (WCAG AA, normal text)',
          child: Column(
            children: [
              for (final (label, fg, bg) in pairs)
                ListTile(
                  dense: true,
                  tileColor: bg,
                  title: Text(label, style: TextStyle(color: fg)),
                  trailing: Text(
                    '${contrastRatio(fg, bg).toStringAsFixed(1)}:1 '
                    '${meetsWcag(fg, bg) ? '✓' : '✗'}',
                    style: TextStyle(color: readableOn(bg)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Voice ───────────────────────────────────────────────────────────────────

class _Voice extends StatefulWidget {
  const _Voice();

  @override
  State<_Voice> createState() => _VoiceState();
}

class _VoiceState extends State<_Voice> {
  final _speech = FakeSpeechInput([
    'remind me to call mum tomorrow at 5pm',
    'add buy oat milk',
    'set a timer for 10 minutes',
    'what is the capital of France',
  ], step: const Duration(milliseconds: 150));
  static const _parser = VoiceCommandParser([
    VoiceIntent('add_task', ['remind me to {title}', 'add {title}']),
    VoiceIntent('timer', ['set a timer for {minutes} minutes']),
  ]);
  String _heard = '';
  String _result = 'Tap the mic (this demo uses scripted phrases).';

  void _onResult(String text) {
    final command = _parser.parse(text, now: DateTime.now());
    setState(() {
      _heard = text;
      _result = command == null
          ? 'No rule matched → fall back (e.g. search for it).'
          : 'intent: ${command.intent}\nslots: ${command.slots}'
                '${command.at == null ? '' : '\nwhen: ${command.at}'}';
    });
  }

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      DemoBlock(
        'Speak',
        note: 'FakeSpeechInput — not a real microphone.',
        child: Row(
          children: [
            VoiceInputButton(
              speech: _speech,
              onPartial: (words) => setState(() => _heard = '$words…'),
              onResult: _onResult,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(_heard)),
          ],
        ),
      ),
      DemoBlock('Parsed (rule-based)', child: Text(_result)),
    ],
  );
}

// ── Collaboration ───────────────────────────────────────────────────────────

class _Collaboration extends StatefulWidget {
  const _Collaboration();

  @override
  State<_Collaboration> createState() => _CollaborationState();
}

class _CollaborationState extends State<_Collaboration> {
  final _hub = InMemoryCollabHub();
  late final _docs = [
    CollaborativeDocument(replicaId: 'phone-a', transport: _hub.transport()),
    CollaborativeDocument(replicaId: 'phone-b', transport: _hub.transport()),
  ];
  final _subscriptions = <StreamSubscription<Object?>>[];

  @override
  void initState() {
    super.initState();
    for (final doc in _docs) {
      _subscriptions.add(doc.changes.listen((_) => setState(() {})));
      unawaited(doc.connect());
    }
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    for (final d in _docs) {
      unawaited(d.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      DemoBlock(
        'Network',
        note:
            'Hold messages, edit the same item on both phones, then deliver '
            'them reversed and duplicated — both phones still agree.',
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Simulate lag (hold messages)'),
              value: _hub.holdMessages,
              onChanged: (v) => setState(() => _hub.holdMessages = v),
            ),
            AppButton(
              label: 'Deliver ${_hub.heldCount} held (shuffled + duplicated)',
              variant: ButtonVariant.tonal,
              onPressed: _hub.heldCount == 0
                  ? null
                  : () => setState(
                      () => _hub.deliverHeld(reverse: true, duplicate: true),
                    ),
            ),
          ],
        ),
      ),
      for (final doc in _docs)
        _CollabPane(doc: doc, onChanged: () => setState(() {})),
    ],
  );
}

class _CollabPane extends StatefulWidget {
  const _CollabPane({required this.doc, required this.onChanged});

  final CollaborativeDocument doc;
  final VoidCallback onChanged;

  @override
  State<_CollabPane> createState() => _CollabPaneState();
}

class _CollabPaneState extends State<_CollabPane> {
  final _text = TextEditingController();
  int _counter = 0;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final title = _text.text.trim();
    if (title.isEmpty) return;
    _text.clear();
    await widget.doc.set('item:${widget.doc.replicaId}-${_counter++}', {
      'title': title,
      'done': false,
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.doc.values.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return DemoBlock(
      widget.doc.replicaId,
      child: Card(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: _text,
                decoration: InputDecoration(
                  hintText: 'Add an item',
                  suffixIcon: IconButton(
                    tooltip: 'Add on ${widget.doc.replicaId}',
                    icon: const Icon(Icons.add),
                    onPressed: _add,
                  ),
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            for (final MapEntry(:key, :value) in items)
              if (value case {
                'title': final String title,
                'done': final bool done,
              })
                CheckboxListTile(
                  dense: true,
                  value: done,
                  title: Text(title),
                  secondary: IconButton(
                    tooltip: 'Remove $title',
                    icon: const Icon(Icons.close),
                    onPressed: () async {
                      await widget.doc.remove(key);
                      widget.onChanged();
                    },
                  ),
                  onChanged: (v) async {
                    await widget.doc.set(key, {'title': title, 'done': v});
                    widget.onChanged();
                  },
                ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Empty list'),
              ),
          ],
        ),
      ),
    );
  }
}
