import 'package:competition_toolkit/01_design_system/app_palette.dart';
import 'package:competition_toolkit/01_design_system/app_theme.dart';
import 'package:competition_toolkit/02_ui_elements/cards.dart';
import 'package:competition_toolkit/02_ui_elements/donut_chart.dart';
import 'package:competition_toolkit/06_screen_templates/agenda_calendar.dart';
import 'package:competition_toolkit/06_screen_templates/analytics_template.dart';
import 'package:competition_toolkit/06_screen_templates/crud_list_screen.dart';
import 'package:competition_toolkit/06_screen_templates/dashboard_template.dart';
import 'package:competition_toolkit/06_screen_templates/list_detail_scaffold.dart';
import 'package:competition_toolkit/06_screen_templates/otp_screen.dart';
import 'package:competition_toolkit/06_screen_templates/profile_template.dart';
import 'package:competition_toolkit/06_screen_templates/settings_template.dart';
import 'package:competition_toolkit/08_state_management/list_query.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget home) => MaterialApp(
  theme: AppTheme.build(AppPalette.taskIndigo, Brightness.light),
  home: home,
);

class Item {
  const Item(this.id, this.name, {this.done = false});
  final String id;
  final String name;
  final bool done;
}

void main() {
  group('OtpVerificationScreen', () {
    testWidgets('wrong code shows an error, right code verifies', (
      tester,
    ) async {
      final tried = <String>[];
      await tester.pumpWidget(
        app(
          OtpVerificationScreen(
            destination: 'a@b.co',
            length: 4,
            onVerify: (code) async {
              tried.add(code);
              if (code != '1234') throw StateError('wrong');
            },
            onResend: () async {},
          ),
        ),
      );
      expect(find.textContaining('a@b.co'), findsOneWidget);
      expect(find.textContaining('Resend code in'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '0000');
      await tester.pumpAndSettle();
      expect(find.text('That code is wrong or has expired.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '1234');
      await tester.pumpAndSettle();
      expect(tried, ['0000', '1234']);
      expect(find.text('That code is wrong or has expired.'), findsNothing);
      await tester.pumpWidget(const SizedBox()); // stops the cooldown timer
    });
  });

  testWidgets('DashboardTemplate shows greeting, stats and sections', (
    tester,
  ) async {
    var refreshed = 0;
    await tester.pumpWidget(
      app(
        DashboardTemplate(
          greeting: 'Hi Sam',
          subtitle: '3 due today',
          stats: const [
            StatCard(label: 'Done', value: '12'),
            StatCard(label: 'Focus', value: '5h'),
          ],
          sections: [
            DashboardSection(
              title: 'Today',
              actionLabel: 'See all',
              onAction: () {},
              child: const Text('task list'),
            ),
          ],
          onRefresh: () async => refreshed++,
        ),
      ),
    );
    expect(find.text('Hi Sam'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('task list'), findsOneWidget);
    await tester.fling(find.text('Hi Sam'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(refreshed, 1);
  });

  group('CrudListScreen', () {
    Widget screen(
      AsyncValue<List<Item>> items, {
      Future<void> Function(Item)? onDelete,
      Future<void> Function(Item)? onRestore,
    }) => app(
      CrudListScreen<Item>(
        title: 'Items',
        items: items,
        idOf: (i) => i.id,
        titleOf: (i) => i.name,
        searchableText: (i) => i.name,
        filters: [FilterOption<Item>('done', 'Done', (i) => i.done)],
        onAdd: () {},
        onDelete: onDelete,
        onRestore: onRestore,
      ),
    );

    testWidgets('search, filters and empty states', (tester) async {
      await tester.pumpWidget(
        screen(
          const AsyncData([
            Item('1', 'Apples'),
            Item('2', 'Bananas', done: true),
          ]),
        ),
      );
      expect(find.text('Apples'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'ban');
      await tester.pump();
      expect(find.text('Apples'), findsNothing);
      expect(find.text('Bananas'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('No matches'), findsOneWidget);

      // The search text is screen state and survives a data change, so an
      // empty list while searching reads as "No matches".
      await tester.pumpWidget(screen(const AsyncData([])));
      expect(find.text('No matches'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(screen(const AsyncData([])));
      expect(find.text('Nothing here yet'), findsOneWidget);
      await tester.pumpWidget(screen(const AsyncLoading()));
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('swipe to delete offers Undo', (tester) async {
      final deleted = <String>[];
      final restored = <String>[];
      await tester.pumpWidget(
        screen(
          const AsyncData([Item('1', 'Apples')]),
          onDelete: (i) async => deleted.add(i.id),
          onRestore: (i) async => restored.add(i.id),
        ),
      );
      await tester.drag(find.text('Apples'), const Offset(-150, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(deleted, ['1']);
      expect(find.text('Deleted "Apples"'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      expect(restored, ['1']);
    });
  });

  group('ListDetailScaffold', () {
    Widget build() => app(
      ListDetailScaffold<Item>(
        title: 'Notes',
        items: const [Item('1', 'First'), Item('2', 'Second')],
        idOf: (i) => i.id,
        detailTitleOf: (i) => i.name,
        tileBuilder: (context, item, selected, open) =>
            ListTile(title: Text(item.name), selected: selected, onTap: open),
        detailBuilder: (context, item) => Text('detail of ${item.name}'),
      ),
    );

    testWidgets('phones push a detail page', (tester) async {
      await tester.pumpWidget(build());
      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();
      expect(find.text('detail of Second'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('wide windows show both panes', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(build());
      expect(find.text('Select an item'), findsOneWidget);
      await tester.tap(find.text('First'));
      await tester.pumpAndSettle();
      expect(find.text('detail of First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget); // list still visible
    });
  });

  testWidgets('AgendaCalendar lists the selected day', (tester) async {
    final today = DateTime(2026, 10, 14);
    await tester.pumpWidget(
      app(
        Scaffold(
          body: SingleChildScrollView(
            child: AgendaCalendar<(DateTime, String)>(
              today: today,
              events: [
                (DateTime(2026, 10, 14, 9), 'Standup'),
                (DateTime(2026, 10, 14, 8), 'Gym'),
                (DateTime(2026, 10, 20, 12), 'Lunch'),
              ],
              dateOf: (e) => e.$1,
              itemBuilder: (context, e) => ListTile(title: Text(e.$2)),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Today · 2 items'), findsOneWidget);
    final gym = tester.getTopLeft(find.text('Gym'));
    expect(
      gym.dy,
      lessThan(tester.getTopLeft(find.text('Standup')).dy),
    ); // sorted by time
    await tester.tap(find.text('20'));
    await tester.pump();
    expect(find.text('Lunch'), findsOneWidget);
    await tester.tap(find.text('21'));
    await tester.pump();
    expect(find.text('Nothing planned'), findsOneWidget);
  });

  testWidgets('AnalyticsTemplate switches periods', (tester) async {
    await tester.pumpWidget(
      app(
        const AnalyticsTemplate(
          title: 'Stats',
          periods: {
            'Week': AnalyticsSnapshot(
              kpis: [StatCard(label: 'Total', value: '7')],
              trend: [1, 2, 3],
              breakdown: [ChartSegment('A', 1)],
              insights: [Text('insight one')],
            ),
            'Month': AnalyticsSnapshot(),
          },
        ),
      ),
    );
    expect(find.text('7'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('insight one'), 200);
    expect(find.text('insight one'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Month'), -200);
    await tester.tap(find.text('Month'));
    await tester.pump();
    expect(find.text('No data for this period yet'), findsOneWidget);
  });

  group('Profile', () {
    test('initialsOf', () {
      expect(initialsOf('Ana Maria Lima'), 'AL');
      expect(initialsOf('sam'), 'S');
      expect(initialsOf('  '), '?');
      expect(initialsOf('Émile Zola'), 'ÉZ');
    });

    testWidgets('ProfileTemplate shows avatar, stats and edit', (tester) async {
      var edits = 0;
      await tester.pumpWidget(
        app(
          ProfileTemplate(
            name: 'Ana Lima',
            subtitle: 'ana@x.io',
            stats: const [ProfileStat('Notes', '12')],
            onEdit: () => edits++,
          ),
        ),
      );
      expect(find.text('AL'), findsOneWidget);
      expect(find.bySemanticsLabel('Notes: 12'), findsOneWidget);
      await tester.tap(find.text('Edit profile'));
      expect(edits, 1);
    });
  });

  testWidgets('SettingsTemplate toggles, chooses and acts', (tester) async {
    var on = false;
    var mode = 'light';
    var signedOut = 0;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) => SettingsTemplate(
            groups: [
              SettingsGroup(
                title: 'Appearance',
                items: [
                  SettingsChoice<String>(
                    label: 'Theme',
                    value: mode,
                    options: const {'light': 'Light', 'dark': 'Dark'},
                    onChanged: (v) => setState(() => mode = v),
                  ),
                  SettingsToggle(
                    label: 'Reminders',
                    value: on,
                    onChanged: (v) => setState(() => on = v),
                  ),
                ],
              ),
              SettingsGroup(
                items: [
                  SettingsAction(
                    label: 'Sign out',
                    destructive: true,
                    onTap: () => signedOut++,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('APPEARANCE'), findsOneWidget);
    await tester.tap(find.text('Reminders'));
    await tester.pump();
    expect(on, isTrue);
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(mode, 'dark');
    await tester.tap(find.text('Sign out'));
    expect(signedOut, 1);
  });
}
