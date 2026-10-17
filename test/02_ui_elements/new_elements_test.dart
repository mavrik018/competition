import 'dart:math' as math;

import 'package:competition_toolkit/02_ui_elements/animations.dart';
import 'package:competition_toolkit/02_ui_elements/app_buttons.dart';
import 'package:competition_toolkit/02_ui_elements/cards.dart';
import 'package:competition_toolkit/02_ui_elements/donut_chart.dart';
import 'package:competition_toolkit/02_ui_elements/line_chart.dart';
import 'package:competition_toolkit/02_ui_elements/text_inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  group('AppButton', () {
    testWidgets('every variant renders and fires', (tester) async {
      for (final variant in ButtonVariant.values) {
        var taps = 0;
        await tester.pumpWidget(
          wrap(
            Center(
              child: AppButton(
                label: variant.name,
                icon: Icons.add,
                variant: variant,
                onPressed: () => taps++,
              ),
            ),
          ),
        );
        await tester.tap(find.text(variant.name));
        expect(taps, 1, reason: variant.name);
      }
    });

    testWidgets('loading shows a spinner and ignores taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(
          Center(
            child: AppButton(
              label: 'Pay',
              isLoading: true,
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Pay'), warnIfMissed: false);
      expect(taps, 0);
      expect(find.bySemanticsLabel('Pay, loading'), findsOneWidget);
    });

    testWidgets('sizes set the minimum height', (tester) async {
      await tester.pumpWidget(
        wrap(
          Center(
            child: AppButton(
              label: 'L',
              size: ButtonSize.large,
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(52),
      );
    });

    testWidgets('social buttons label the provider', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(
          Column(
            children: [
              SocialSignInButton(
                provider: SocialProvider.apple,
                onPressed: () => taps++,
              ),
              SocialSignInButton(
                provider: SocialProvider.google,
                onPressed: () => taps++,
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Continue with Apple'));
      await tester.tap(find.text('Continue with Google'));
      expect(taps, 2);
    });
  });

  group('Text inputs', () {
    testWidgets('AppTextField marks required and validates', (tester) async {
      final key = GlobalKey<FormState>();
      await tester.pumpWidget(
        wrap(
          Form(
            key: key,
            child: const AppTextField(label: 'Title', isRequired: true),
          ),
        ),
      );
      expect(find.text('Title *'), findsOneWidget);
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Title is required'), findsOneWidget);
    });

    testWidgets('clear button empties the field', (tester) async {
      final controller = TextEditingController(text: 'abc');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        wrap(AppTextField(controller: controller, clearable: true)),
      );
      await tester.tap(find.byTooltip('Clear'));
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(find.byTooltip('Clear'), findsNothing);
    });

    testWidgets('PasswordField toggles visibility', (tester) async {
      await tester.pumpWidget(wrap(const PasswordField()));
      bool obscured() =>
          tester.widget<EditableText>(find.byType(EditableText)).obscureText;
      expect(obscured(), isTrue);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(obscured(), isFalse);
    });

    testWidgets('PinCodeField accepts digits only and completes', (
      tester,
    ) async {
      String? completed;
      await tester.pumpWidget(
        wrap(PinCodeField(length: 4, onCompleted: (c) => completed = c)),
      );
      await tester.enterText(find.byType(TextField), '12a3');
      await tester.pump();
      expect(completed, isNull);
      expect(find.text('1'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '1234');
      await tester.pump();
      expect(completed, '1234');
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('TagInputField adds, de-duplicates, suggests and removes', (
      tester,
    ) async {
      var tags = <String>['work'];
      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (context, setState) => TagInputField(
              tags: tags,
              suggestions: const ['home', 'work'],
              maxTags: 3,
              onChanged: (t) => setState(() => tags = t),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'urgent');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(tags, ['work', 'urgent']);

      await tester.enterText(find.byType(TextField), 'WORK,');
      await tester.pump();
      expect(tags, ['work', 'urgent']); // duplicate ignored

      expect(find.widgetWithText(ActionChip, 'work'), findsNothing);
      await tester.tap(find.widgetWithText(ActionChip, 'home'));
      await tester.pump();
      expect(tags, ['work', 'urgent', 'home']);

      await tester.tap(find.byTooltip('Remove urgent'));
      await tester.pump();
      expect(tags, ['work', 'home']);
    });

    testWidgets('backspace in an empty tag field removes the last tag', (
      tester,
    ) async {
      var tags = <String>['a', 'b'];
      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (context, setState) => TagInputField(
              tags: tags,
              onChanged: (t) => setState(() => tags = t),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(tags, ['a']);
    });
  });

  group('Cards', () {
    testWidgets('StatCard colours the delta by direction', (tester) async {
      await tester.pumpWidget(
        wrap(
          const Column(
            children: [
              StatCard(label: 'Sales', value: '120', delta: 0.12),
              StatCard(
                label: 'Errors',
                value: '4',
                delta: 0.5,
                higherIsBetter: false,
              ),
            ],
          ),
        ),
      );
      expect(find.text('+12%'), findsOneWidget);
      expect(find.bySemanticsLabel('Sales: 120, +12%'), findsOneWidget);
      final context = tester.element(find.text('+50%'));
      expect(
        tester.widget<Text>(find.text('+50%')).style!.color,
        Theme.of(context).colorScheme.error,
      );
    });

    testWidgets('ActionCard taps and ImageCard falls back without an image', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(
          Column(
            children: [
              ActionCard(
                title: 'Import',
                icon: Icons.upload,
                onTap: () => taps++,
              ),
              const SizedBox(
                width: 200,
                child: ImageCard(title: 'Soup', badge: 'NEW'),
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Import'));
      expect(taps, 1);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.text('NEW'), findsOneWidget);
    });
  });

  group('Animations', () {
    testWidgets('AnimatedCounter ends on the value', (tester) async {
      await tester.pumpWidget(
        wrap(AnimatedCounter(value: 42, format: (v) => '${v.round()} pts')),
      );
      expect(find.text('0 pts'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('42 pts'), findsOneWidget);
    });

    testWidgets('SuccessCheckmark completes', (tester) async {
      var done = false;
      await tester.pumpWidget(
        wrap(SuccessCheckmark(onCompleted: () => done = true)),
      );
      await tester.pumpAndSettle();
      expect(done, isTrue);
      expect(find.bySemanticsLabel('Done'), findsOneWidget);
    });

    testWidgets('Shake moves the child and returns', (tester) async {
      final controller = ShakeController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        wrap(
          Center(
            child: Shake(controller: controller, child: const Text('pin')),
          ),
        ),
      );
      final start = tester.getCenter(find.text('pin'));
      controller.shake();
      await tester.pump(); // the ticker starts on this frame
      await tester.pump(const Duration(milliseconds: 30));
      expect(tester.getCenter(find.text('pin')).dx, isNot(start.dx));
      await tester.pumpAndSettle();
      expect(tester.getCenter(find.text('pin')), start);
    });
  });

  group('Charts', () {
    test('plotPoints maps into the box', () {
      final points = plotPoints([0, 5, 10], const Size(100, 50));
      expect(points, [
        const Offset(0, 50),
        const Offset(50, 25),
        const Offset(100, 0),
      ]);
      expect(
        plotPoints([3, 3], const Size(100, 50)).every((p) => p.dy == 25),
        isTrue,
      );
      expect(plotPoints([7], const Size(100, 50)).single, const Offset(50, 25));
      expect(plotPoints([], const Size(1, 1)), isEmpty);
    });

    test('donutSweeps are proportional and safe', () {
      final sweeps = donutSweeps([1, 1, 2]);
      expect(sweeps[2], closeTo(math.pi, 1e-9));
      expect(sweeps.reduce((a, b) => a + b), closeTo(2 * math.pi, 1e-9));
      expect(donutSweeps([0, 0]), [0, 0]);
      expect(donutSweeps([-5, 5]), [0, closeTo(2 * math.pi, 1e-9)]);
    });

    test('chartPalette gives distinct colours beyond the scheme', () {
      final colors = chartPalette(const ColorScheme.light(), 9);
      expect(colors.toSet().length, 9);
    });

    testWidgets('line chart, sparkline and donut render with semantics', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const SingleChildScrollView(
            child: Column(
              children: [
                SimpleLineChart(
                  values: [1, 4, 2, 8],
                  labels: ['a', 'b', 'c', 'd'],
                  comparison: [2, 2, 2, 2],
                ),
                Sparkline(values: [1, 2, 3]),
                SimpleLineChart(values: []),
                DonutChart(
                  segments: [
                    ChartSegment('Food', 30),
                    ChartSegment('Rent', 70),
                  ],
                  centerLabel: '100',
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('Line chart, from 1 to 8, high 8'),
        findsOneWidget,
      );
      expect(find.text('No data'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Food 30, 30%; Rent 70, 70%'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
