import 'package:competition_toolkit/02_ui_elements/app_chip.dart';
import 'package:competition_toolkit/02_ui_elements/fade_slide_in.dart';
import 'package:competition_toolkit/02_ui_elements/pressable.dart';
import 'package:competition_toolkit/02_ui_elements/primary_button.dart';
import 'package:competition_toolkit/02_ui_elements/radial_gauge.dart';
import 'package:competition_toolkit/02_ui_elements/search_field.dart';
import 'package:competition_toolkit/02_ui_elements/section_header.dart';
import 'package:competition_toolkit/02_ui_elements/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  group('Pressable', () {
    testWidgets('calls onTap and onLongPress', (tester) async {
      var taps = 0;
      var longPresses = 0;
      await tester.pumpWidget(
        wrap(
          Pressable(
            onTap: () => taps++,
            onLongPress: () => longPresses++,
            child: const Text('card'),
          ),
        ),
      );
      await tester.tap(find.text('card'));
      await tester.longPress(find.text('card'));
      expect(taps, 1);
      expect(longPresses, 1);
    });

    testWidgets('shrinks while pressed and is not a button when inert', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(Pressable(onTap: () {}, child: const Text('card'))),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('card')),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        0.98,
      );
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);

      await tester.pumpWidget(wrap(const Pressable(child: Text('static'))));
      expect(
        tester.getSemantics(find.text('static')),
        isNot(matchesSemantics(isButton: true)),
      );
    });
  });

  group('PrimaryButton', () {
    testWidgets('fires onPressed', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        wrap(PrimaryButton(label: 'Save', onPressed: () => pressed++)),
      );
      await tester.tap(find.text('Save'));
      expect(pressed, 1);
    });

    testWidgets('loading shows a spinner and ignores taps', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        wrap(
          PrimaryButton(
            label: 'Save',
            isLoading: true,
            onPressed: () => pressed++,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      await tester.tap(find.byType(FilledButton));
      expect(pressed, 0);
    });

    testWidgets('destructive uses the error colour', (tester) async {
      await tester.pumpWidget(
        wrap(
          PrimaryButton(label: 'Delete', destructive: true, onPressed: () {}),
        ),
      );
      final context = tester.element(find.byType(FilledButton));
      final style = tester
          .widget<FilledButton>(find.byType(FilledButton))
          .style!;
      expect(
        style.backgroundColor!.resolve({}),
        Theme.of(context).colorScheme.error,
      );
    });
  });

  group('AppChip', () {
    testWidgets('taps and reports selection to semantics', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(AppChip(label: 'Vegan', selected: true, onTap: () => taps++)),
      );
      await tester.tap(find.text('Vegan'));
      expect(taps, 1);
      expect(
        tester.getSemantics(find.text('Vegan')),
        matchesSemantics(
          isSelected: true,
          hasSelectedState: true,
          label: 'Vegan',
          isButton: true,
          hasTapAction: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
    });
  });

  testWidgets('SectionHeader upper-cases and shows its action', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      wrap(
        SectionHeader(
          title: 'Recent',
          actionLabel: 'See all',
          onAction: () => opened++,
        ),
      ),
    );
    expect(find.text('RECENT'), findsOneWidget);
    await tester.tap(find.text('See all'));
    expect(opened, 1);
  });

  group('SearchField', () {
    testWidgets('clear button appears with text and clears it', (tester) async {
      final changes = <String>[];
      await tester.pumpWidget(wrap(SearchField(onChanged: changes.add)));
      expect(find.byTooltip('Clear search'), findsNothing);

      await tester.enterText(find.byType(TextField), 'milk');
      await tester.pump();
      expect(find.byTooltip('Clear search'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();
      expect(find.text('milk'), findsNothing);
      expect(changes, ['milk', '']);
    });

    testWidgets('works with an external controller swapped at runtime', (
      tester,
    ) async {
      final a = TextEditingController(text: 'a');
      final b = TextEditingController();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await tester.pumpWidget(wrap(SearchField(controller: a)));
      expect(find.byTooltip('Clear search'), findsOneWidget);
      await tester.pumpWidget(wrap(SearchField(controller: b)));
      b.text = 'typed';
      await tester.pump();
      expect(find.byTooltip('Clear search'), findsOneWidget);
    });
  });

  group('RadialGauge', () {
    testWidgets('clamps the value and labels it for screen readers', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const Center(child: RadialGauge(value: 1.7, size: 100))),
      );
      expect(find.bySemanticsLabel('100 percent'), findsOneWidget);
      await tester.pumpWidget(
        wrap(const Center(child: RadialGauge(value: double.nan, size: 100))),
      );
      expect(find.bySemanticsLabel('0 percent'), findsOneWidget);
    });

    testWidgets('scales a long centre label down instead of overflowing', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const Center(
            child: RadialGauge(
              value: 0.5,
              size: 60,
              child: Text('A very long label that would overflow'),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('Skeletons render and animate without errors', (tester) async {
    await tester.pumpWidget(
      wrap(
        const Column(
          children: [SkeletonList(rows: 2), SkeletonCardRow(height: 80)],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(SkeletonBox), findsNWidgets(5));
    expect(find.bySemanticsLabel('Loading'), findsNWidgets(2));
  });

  group('FadeSlideIn', () {
    testWidgets('starts transparent and ends fully visible', (tester) async {
      await tester.pumpWidget(
        wrap(const FadeSlideIn(index: 2, child: Text('item'))),
      );
      Opacity opacity() => tester.widget<Opacity>(
        find.ancestor(of: find.text('item'), matching: find.byType(Opacity)),
      );
      expect(opacity().opacity, 0);
      // index 2 × 55 ms stagger: nothing moves until the delay has passed.
      await tester.pump(const Duration(milliseconds: 100));
      expect(opacity().opacity, 0);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpAndSettle();
      expect(opacity().opacity, 1);
    });

    testWidgets('shows content immediately when animations are disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: wrap(const FadeSlideIn(child: Text('item'))),
        ),
      );
      expect(find.byType(Opacity), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('Stagger lays out a row without a bounded height', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const SingleChildScrollView(
            child: Stagger(
              axis: Axis.horizontal,
              children: [Text('a'), Text('b')],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('b'), findsOneWidget);
    });
  });
}
