import 'package:competition_toolkit/05_forms/calendar_grid.dart';
import 'package:competition_toolkit/06_screen_templates/responsive_layout.dart';
import 'package:competition_toolkit/07_navigation/tab_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  test('windowSizeFor uses the Material 3 breakpoints', () {
    expect(windowSizeFor(599), WindowSize.compact);
    expect(windowSizeFor(600), WindowSize.medium);
    expect(windowSizeFor(839), WindowSize.medium);
    expect(windowSizeFor(840), WindowSize.expanded);
  });

  test('gridColumnsFor', () {
    expect(gridColumnsFor(360, minItemWidth: 160), 2);
    expect(gridColumnsFor(100, minItemWidth: 160), 1);
    expect(gridColumnsFor(2000, minItemWidth: 100, maxColumns: 4), 4);
    expect(gridColumnsFor(0, minItemWidth: 100), 1);
  });

  testWidgets('ResponsiveBuilder falls back to smaller layouts', (
    tester,
  ) async {
    Widget at(double width) => wrap(
      Center(
        child: SizedBox(
          width: width,
          child: ResponsiveBuilder(
            compact: (_) => const Text('compact'),
            expanded: (_) => const Text('expanded'),
          ),
        ),
      ),
    );
    await tester.pumpWidget(at(400));
    expect(find.text('compact'), findsOneWidget);
    await tester.pumpWidget(at(700)); // medium → compact fallback
    expect(find.text('compact'), findsOneWidget);
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(at(1000));
    expect(find.text('expanded'), findsOneWidget);
  });

  testWidgets('ResponsiveGrid lays out rows with equal widths', (tester) async {
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 360,
          child: ResponsiveGrid(
            minItemWidth: 160,
            spacing: 8,
            children: [
              for (var i = 0; i < 3; i++)
                Container(height: 40, color: Colors.red, key: ValueKey(i)),
            ],
          ),
        ),
      ),
    );
    final first = tester.getSize(find.byKey(const ValueKey(0)));
    final third = tester.getSize(find.byKey(const ValueKey(2)));
    expect(first.width, third.width); // the lone item in row 2 is not stretched
    expect(
      tester.getTopLeft(find.byKey(const ValueKey(2))).dy,
      greaterThan(tester.getTopLeft(find.byKey(const ValueKey(0))).dy),
    );
  });

  testWidgets('TabShell switches to a NavigationRail on wide windows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: TabShell(
          destinations: [
            TabDestination(
              label: 'Home',
              icon: Icons.home,
              builder: (_) => const Text('home page'),
            ),
            TabDestination(
              label: 'Stats',
              icon: Icons.bar_chart,
              builder: (_) => const Text('stats page'),
            ),
          ],
        ),
      ),
    );
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();
    expect(find.text('stats page'), findsOneWidget);
  });

  testWidgets('CalendarGrid draws event markers and announces them', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        SingleChildScrollView(
          child: CalendarGrid(
            selected: DateTime(2026, 10, 14),
            onSelected: (_) {},
            markerCount: (day) => day.day == 20 ? 2 : 0,
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('October 20, has events'), findsOneWidget);
    expect(find.bySemanticsLabel('October 21'), findsOneWidget);
  });
}
