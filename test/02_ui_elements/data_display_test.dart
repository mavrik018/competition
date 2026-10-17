import 'package:competition_toolkit/02_ui_elements/activity_heatmap.dart';
import 'package:competition_toolkit/02_ui_elements/markdown_view.dart';
import 'package:competition_toolkit/02_ui_elements/simple_bar_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  group('ActivityHeatmap helpers', () {
    test('heatmapLevel counts thresholds exceeded', () {
      expect(heatmapLevel(0, [20, 60]), 0);
      expect(heatmapLevel(-5, [20, 60]), 0);
      expect(heatmapLevel(10, [20, 60]), 1);
      expect(heatmapLevel(20, [20, 60]), 1);
      expect(heatmapLevel(21, [20, 60]), 2);
      expect(heatmapLevel(90, [20, 60]), 3);
      expect(heatmapLevel(1, []), 1);
    });

    test('heatmapColumns ends with the week holding today, Monday first', () {
      final wednesday = DateTime(2026, 10, 14);
      final columns = heatmapColumns(wednesday, 3);
      expect(columns, hasLength(3));
      expect(columns.last.first, DateTime(2026, 10, 12)); // Monday
      expect(columns.last, contains(wednesday));
      expect(columns.first.first, DateTime(2026, 9, 28));
      for (final column in columns) {
        expect(column, hasLength(7));
        expect(column.first.weekday, DateTime.monday);
      }
    });

    test('heatmapColumns stays on midnights across a DST change', () {
      // Weeks spanning late March / late October cross DST in many zones.
      for (final today in [DateTime(2026, 4, 2), DateTime(2026, 11, 3)]) {
        for (final day in heatmapColumns(today, 3).expand((c) => c)) {
          expect(day.hour, 0);
        }
      }
    });

    test('sumByDay merges entries on the same date', () {
      final totals = sumByDay({
        DateTime(2026, 1, 1, 9): 10,
        DateTime(2026, 1, 1, 18): 5,
        DateTime(2026, 1, 2): 3,
      });
      expect(totals[DateTime(2026, 1, 1)], 15);
      expect(totals[DateTime(2026, 1, 2)], 3);
    });
  });

  testWidgets('ActivityHeatmap draws 7 × weeks squares and a legend', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 360,
          child: ActivityHeatmap(
            weeks: 4,
            today: DateTime(2026, 10, 14),
            values: {DateTime(2026, 10, 13): 45},
            tooltip: (day, value) => '${day.day}: $value',
          ),
        ),
      ),
    );
    expect(find.text('Less'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    // Tooltips only on past/present days: 4 weeks minus the 4 future days.
    expect(find.byType(Tooltip), findsNWidgets(28 - 4));
    expect(find.byTooltip('13: 45'), findsOneWidget);
  });

  group('SimpleBarChart', () {
    test('chartMax adds headroom above the larger of data and target', () {
      expect(chartMax([10, 50, 20], null), closeTo(57.5, 0.001));
      expect(chartMax([10, 20], 100), closeTo(115, 0.001));
      expect(chartMax(<num>[], null), 1);
      expect(chartMax([0, 0], 0), 1);
    });

    testWidgets('labels every bar for screen readers', (tester) async {
      await tester.pumpWidget(
        wrap(
          SimpleBarChart(
            data: const [BarDatum('Mon', 1200), BarDatum('Tue', 0)],
            target: 2000,
            highlightIndex: 0,
            valueFormatter: (v) => '$v kcal',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Mon: 1200 kcal'), findsOneWidget);
      expect(find.bySemanticsLabel('Tue: 0 kcal'), findsOneWidget);
    });
  });

  group('MarkdownView', () {
    testWidgets('renders each block type', (tester) async {
      await tester.pumpWidget(
        wrap(
          const SingleChildScrollView(
            child: MarkdownView(
              data:
                  '# Title\n'
                  'Some **bold** text\n'
                  '- first\n'
                  '2. second\n'
                  '> quoted\n'
                  '```\ncode *not italic*\n```\n'
                  '| A | B |\n|---|---|\n| 1 | 2 |',
            ),
          ),
        ),
      );
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Some bold text', findRichText: true), findsOneWidget);
      expect(find.text('•'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
      expect(find.text('code *not italic*'), findsOneWidget);
      expect(find.byType(Table), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('selectable wraps the content in a SelectionArea', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const MarkdownView(data: 'hello', selectable: true)),
      );
      expect(find.byType(SelectionArea), findsOneWidget);
    });
  });

  test('markdownSpans styles inline runs', () {
    final spans = markdownSpans(
      'a **b** *c* `d` ~~e~~',
      const TextStyle(),
      const ColorScheme.light(),
    );
    final bold = spans.firstWhere((s) => s.text == 'b');
    final italic = spans.firstWhere((s) => s.text == 'c');
    final strike = spans.firstWhere((s) => s.text == 'e');
    expect(bold.style!.fontWeight, FontWeight.w700);
    expect(italic.style!.fontStyle, FontStyle.italic);
    expect(strike.style!.decoration, TextDecoration.lineThrough);
  });
}
