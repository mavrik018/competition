import 'package:competition_toolkit/02_ui_elements/cards.dart';
import 'package:competition_toolkit/02_ui_elements/donut_chart.dart';
import 'package:competition_toolkit/03_feedback/app_snackbars.dart';
import 'package:competition_toolkit/06_screen_templates/agenda_calendar.dart';
import 'package:competition_toolkit/06_screen_templates/analytics_template.dart';
import 'package:competition_toolkit/06_screen_templates/crud_list_screen.dart';
import 'package:competition_toolkit/06_screen_templates/dashboard_template.dart';
import 'package:competition_toolkit/06_screen_templates/list_detail_scaffold.dart';
import 'package:competition_toolkit/06_screen_templates/otp_screen.dart';
import 'package:competition_toolkit/06_screen_templates/profile_template.dart';
import 'package:competition_toolkit/06_screen_templates/settings_template.dart';
import 'package:competition_toolkit/08_state_management/list_query.dart';
import 'package:competition_toolkit/13_smart_features/activity_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart';

final screenDemos = <Demo>[
  Demo('Screens', 'Dashboard', (_) => const _Dashboard(), fullScreen: true),
  Demo(
    'Screens',
    'CRUD list',
    (_) => const _CrudList(),
    subtitle: 'Search, filter, sort, swipe to delete + undo',
    fullScreen: true,
  ),
  Demo(
    'Screens',
    'List / detail',
    (_) => const _ListDetail(),
    subtitle: 'Side by side on wide screens',
    fullScreen: true,
  ),
  Demo('Screens', 'Agenda calendar', (_) => const _Agenda()),
  Demo('Screens', 'Analytics', (_) => const _Analytics(), fullScreen: true),
  Demo('Screens', 'Profile', (_) => const _Profile(), fullScreen: true),
  Demo('Screens', 'Settings', (_) => const _Settings(), fullScreen: true),
  Demo(
    'Screens',
    'OTP verification',
    (_) => const _Otp(),
    subtitle: 'The correct code is 123456',
    fullScreen: true,
  ),
];

class _Dashboard extends StatelessWidget {
  const _Dashboard();

  @override
  Widget build(BuildContext context) => DashboardTemplate(
    greeting: 'Good morning, Sam',
    subtitle: '3 tasks due today',
    stats: const [
      StatCard(label: 'Focus', value: '2h 15m', icon: Icons.timer, delta: 0.18),
      StatCard(
        label: 'Tasks done',
        value: '12',
        icon: Icons.check,
        delta: -0.05,
      ),
      StatCard(label: 'Streak', value: '6 days', icon: Icons.whatshot),
    ],
    highlight: const ActionCard(
      title: 'Exam in 4 days',
      subtitle: 'Biology — 62% of the syllabus revised',
      icon: Icons.school_outlined,
    ),
    sections: [
      DashboardSection(
        title: 'Recent activity',
        icon: Icons.history,
        child: ActivityTimeline(
          events: [
            ActivityEvent(
              id: '1',
              title: 'Completed "Essay draft"',
              at: DateTime.now().subtract(const Duration(hours: 1)),
              icon: Icons.check_circle,
            ),
            ActivityEvent(
              id: '2',
              title: 'Ana joined Biology 101',
              at: DateTime.now().subtract(const Duration(days: 1)),
              icon: Icons.group_add,
            ),
          ],
        ),
      ),
    ],
    onRefresh: () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
}

typedef _Task = ({String id, String title, String list, int priority});

class _CrudList extends StatefulWidget {
  const _CrudList();

  @override
  State<_CrudList> createState() => _CrudListState();
}

class _CrudListState extends State<_CrudList> {
  final _tasks = <_Task>[
    (id: '1', title: 'Buy oat milk', list: 'Home', priority: 1),
    (id: '2', title: 'Finish essay', list: 'School', priority: 3),
    (id: '3', title: 'Book dentist', list: 'Home', priority: 2),
    (id: '4', title: 'Revise chapter 4', list: 'School', priority: 2),
  ];
  int _nextId = 5;

  @override
  Widget build(BuildContext context) => CrudListScreen<_Task>(
    title: 'Tasks',
    items: AsyncValue.data(List.of(_tasks)),
    idOf: (t) => t.id,
    titleOf: (t) => t.title,
    subtitleOf: (t) => '${t.list} · priority ${t.priority}',
    searchableText: (t) => '${t.title} ${t.list}',
    filters: [
      FilterOption('home', 'Home', (t) => t.list == 'Home'),
      FilterOption('school', 'School', (t) => t.list == 'School'),
    ],
    sorts: [
      SortOption('title', 'Title', (a, b) => a.title.compareTo(b.title)),
      SortOption(
        'priority',
        'Priority',
        (a, b) => b.priority.compareTo(a.priority),
      ),
    ],
    onAdd: () => setState(
      () => _tasks.add((
        id: '${_nextId++}',
        title: 'New task $_nextId',
        list: 'Home',
        priority: 1,
      )),
    ),
    onDelete: (t) async => setState(() => _tasks.remove(t)),
    onRestore: (t) async => setState(() => _tasks.add(t)),
    onRefresh: () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
}

class _ListDetail extends StatelessWidget {
  const _ListDetail();

  static const _notes = [
    (id: 'a', title: 'Cell biology', body: 'Mitochondria produce ATP…'),
    (id: 'b', title: 'Essay outline', body: 'Intro, three arguments, …'),
    (id: 'c', title: 'Shopping', body: 'Oats, lentils, coffee'),
  ];

  @override
  Widget build(BuildContext context) => ListDetailScaffold(
    title: 'Notes',
    items: _notes,
    idOf: (n) => n.id,
    detailTitleOf: (n) => n.title,
    tileBuilder: (context, note, selected, open) =>
        ListTile(selected: selected, title: Text(note.title), onTap: open),
    detailBuilder: (context, note) =>
        Padding(padding: const EdgeInsets.all(16), child: Text(note.body)),
  );
}

class _Agenda extends StatelessWidget {
  const _Agenda();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final events = [
      (title: 'Lecture', at: DateTime(now.year, now.month, now.day, 9)),
      (title: 'Gym', at: DateTime(now.year, now.month, now.day, 18)),
      (title: 'Exam', at: DateTime(now.year, now.month, now.day + 3, 10)),
    ];
    return SingleChildScrollView(
      child: AgendaCalendar(
        events: events,
        dateOf: (e) => e.at,
        itemBuilder: (context, e) => ListTile(
          leading: const Icon(Icons.event),
          title: Text(e.title),
          subtitle: Text('${e.at.hour.toString().padLeft(2, '0')}:00'),
        ),
      ),
    );
  }
}

class _Analytics extends StatelessWidget {
  const _Analytics();

  @override
  Widget build(BuildContext context) => AnalyticsTemplate(
    title: 'Spending',
    periods: {
      'Week': const AnalyticsSnapshot(
        kpis: [
          StatCard(
            label: 'Total',
            value: '€184',
            delta: 0.08,
            higherIsBetter: false,
          ),
          StatCard(label: 'Per day', value: '€26'),
        ],
        trend: [20, 35, 18, 40, 22, 31, 18],
        trendLabels: ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
        comparisonTrend: [25, 20, 22, 30, 24, 15, 20],
        breakdown: [
          ChartSegment('Food', 92),
          ChartSegment('Transport', 40),
          ChartSegment('Fun', 52),
        ],
      ),
      'Month': const AnalyticsSnapshot(
        kpis: [StatCard(label: 'Total', value: '€812')],
        trend: [180, 210, 190, 232],
        trendLabels: ['W1', 'W2', 'W3', 'W4'],
        breakdown: [
          ChartSegment('Food', 380),
          ChartSegment('Transport', 160),
          ChartSegment('Fun', 272),
        ],
      ),
    },
  );
}

class _Profile extends StatelessWidget {
  const _Profile();

  @override
  Widget build(BuildContext context) => ProfileTemplate(
    name: 'Sam Rivera',
    subtitle: 'Biology · Year 2',
    stats: const [
      ProfileStat('Notes', '48'),
      ProfileStat('Streak', '6'),
      ProfileStat('Level', '4'),
    ],
    onEdit: () => context.showInfo('Edit profile tapped'),
    sections: const [
      Card(
        child: ListTile(
          leading: Icon(Icons.emoji_events_outlined),
          title: Text('Achievements'),
          trailing: Icon(Icons.chevron_right),
        ),
      ),
    ],
  );
}

class _Settings extends StatefulWidget {
  const _Settings();

  @override
  State<_Settings> createState() => _SettingsState();
}

class _SettingsState extends State<_Settings> {
  bool _notifications = true;
  String _theme = 'system';

  @override
  Widget build(BuildContext context) => SettingsTemplate(
    groups: [
      SettingsGroup(
        title: 'Preferences',
        items: [
          SettingsToggle(
            label: 'Notifications',
            icon: Icons.notifications_outlined,
            value: _notifications,
            onChanged: (v) => setState(() => _notifications = v),
          ),
          SettingsChoice<String>(
            label: 'Theme',
            icon: Icons.palette_outlined,
            value: _theme,
            options: const {
              'system': 'System',
              'light': 'Light',
              'dark': 'Dark',
            },
            onChanged: (v) => setState(() => _theme = v),
          ),
        ],
      ),
      SettingsGroup(
        title: 'Account',
        footer: 'Deleting your account removes all your data.',
        items: [
          SettingsLink(
            label: 'Privacy policy',
            icon: Icons.privacy_tip_outlined,
            onTap: () {},
          ),
          SettingsAction(
            label: 'Delete account',
            icon: Icons.delete_outline,
            destructive: true,
            onTap: () => context.showInfo('Would confirm, then delete'),
          ),
        ],
      ),
    ],
  );
}

class _Otp extends StatelessWidget {
  const _Otp();

  @override
  Widget build(BuildContext context) => OtpVerificationScreen(
    destination: 'sam@example.com',
    onVerify: (code) async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (code != '123456') throw Exception('Wrong code');
      if (context.mounted) Navigator.of(context).pop();
    },
    onResend: () async {},
  );
}
