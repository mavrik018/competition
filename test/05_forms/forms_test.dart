import 'package:competition_toolkit/05_forms/calendar_grid.dart';
import 'package:competition_toolkit/05_forms/consent_checkbox.dart';
import 'package:competition_toolkit/05_forms/form_section.dart';
import 'package:competition_toolkit/05_forms/markdown_editing_controller.dart';
import 'package:competition_toolkit/05_forms/number_stepper.dart';
import 'package:competition_toolkit/05_forms/password_checklist.dart';
import 'package:competition_toolkit/05_forms/segmented_control.dart';
import 'package:competition_toolkit/05_forms/validators.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  group('Validators', () {
    test('required', () {
      final v = Validators.required('Needed');
      expect(v(null), 'Needed');
      expect(v('   '), 'Needed');
      expect(v('x'), isNull);
    });

    test('email accepts common forms and passes empty input', () {
      final v = Validators.email();
      expect(v('a@b.co'), isNull);
      expect(v('first.last+tag@sub.example.org'), isNull);
      expect(v(''), isNull);
      expect(v('not-an-email'), isNotNull);
      expect(v('a@b'), isNotNull);
      expect(v('a b@c.com'), isNotNull);
    });

    test('length, match and integer', () {
      expect(Validators.minLength(3)('ab'), 'Must be at least 3 characters');
      expect(Validators.minLength(3)('abc'), isNull);
      expect(Validators.maxLength(2)('abc'), isNotNull);
      var other = 'secret';
      expect(Validators.matches(() => other)('secret'), isNull);
      other = 'changed';
      expect(Validators.matches(() => other)('secret'), "Doesn't match");
      final age = Validators.integer(min: 13, max: 120);
      expect(age('abc'), 'Enter a whole number');
      expect(age('12'), 'Must be at least 13');
      expect(age('121'), 'Must be at most 120');
      expect(age('30'), isNull);
      expect(age(''), isNull);
    });

    test('compose returns the first failure', () {
      final v = Validators.compose([
        Validators.required('Enter your email'),
        Validators.email('Bad email'),
      ]);
      expect(v(''), 'Enter your email');
      expect(v('nope'), 'Bad email');
      expect(v('a@b.io'), isNull);
    });
  });

  group('Password rules', () {
    test('default rules', () {
      expect(passwordMeetsAll('Abcdefg1'), isTrue);
      expect(passwordMeetsAll('abcdefg1'), isFalse); // no uppercase
      expect(passwordMeetsAll('Abcdefgh'), isFalse); // no digit/symbol
      expect(passwordMeetsAll('Abc!'), isFalse); // too short
      expect(passwordMeetsAll('Abcdefg_'), isTrue); // symbol counts
    });

    test('custom rules', () {
      final rules = [PasswordRule('6+', (p) => p.length >= 6)];
      expect(passwordMeetsAll('abcdef', rules), isTrue);
    });

    testWidgets('checklist ticks met rules', (tester) async {
      await tester.pumpWidget(
        wrap(const PasswordChecklist(password: 'abcdefgh')),
      );
      // length + lowercase are met; uppercase + number are not.
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
      expect(
        find.bySemanticsLabel('At least 8 characters, met'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('An uppercase letter (A-Z), not met'),
        findsOneWidget,
      );
    });
  });

  group('FormSection', () {
    testWidgets('header, rows, footer and taps', (tester) async {
      var tapped = 0;
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        wrap(
          FormSection(
            header: 'Account',
            footer: 'Footer note',
            children: [
              const FormRowTile(label: 'Plan', value: 'Pro'),
              FormRowTile(
                label: 'Privacy',
                showChevron: true,
                onTap: () => tapped++,
              ),
              TextFieldRow(
                controller: controller,
                label: 'Name',
                placeholder: 'Your name',
              ),
            ],
          ),
        ),
      );
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('Footer note'), findsOneWidget);
      expect(find.byType(ValuePill), findsOneWidget);
      expect(find.byType(Divider), findsNWidgets(2));
      await tester.tap(find.text('Privacy'));
      expect(tapped, 1);
      await tester.enterText(find.byType(TextField), 'Sam');
      expect(controller.text, 'Sam');
    });
  });

  testWidgets('SegmentedControl reports changes but not re-selection', (
    tester,
  ) async {
    final changes = <int>[];
    await tester.pumpWidget(
      wrap(
        SegmentedControl<int>(
          segments: const {1: 'Week', 2: 'Month'},
          selected: 1,
          onChanged: changes.add,
        ),
      ),
    );
    await tester.tap(find.text('Week'));
    await tester.tap(find.text('Month'));
    expect(changes, [2]);
  });

  group('NumberStepper', () {
    testWidgets('steps within bounds', (tester) async {
      final values = <int>[];
      await tester.pumpWidget(
        wrap(
          Center(
            child: NumberStepper(
              value: 1,
              min: 1,
              max: 3,
              onChanged: values.add,
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(CupertinoIcons.minus)); // at min: ignored
      await tester.tap(find.byIcon(CupertinoIcons.plus));
      expect(values, [2]);
    });

    testWidgets('exposes increase/decrease to screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      final values = <int>[];
      await tester.pumpWidget(
        wrap(
          Center(
            child: NumberStepper(
              value: 5,
              step: 5,
              max: 20,
              onChanged: values.add,
            ),
          ),
        ),
      );
      final node = tester.getSemantics(find.byType(NumberStepper));
      expect(node.value, '5');
      node.owner!.performAction(node.id, SemanticsAction.increase);
      expect(values, [10]);
      handle.dispose();
    });
  });

  group('Calendar', () {
    test('monthCells pads to the configured week start', () {
      // 1 Oct 2026 is a Thursday.
      final sunday = monthCells(DateTime(2026, 10));
      expect(sunday.take(4), everyElement(isNull));
      expect(sunday[4], DateTime(2026, 10, 1));
      expect(sunday.whereType<DateTime>(), hasLength(31));

      final monday = monthCells(
        DateTime(2026, 10),
        firstWeekday: DateTime.monday,
      );
      expect(monday.take(3), everyElement(isNull));
      expect(monday[3], DateTime(2026, 10, 1));

      expect(
        monthCells(DateTime(2028, 2)).whereType<DateTime>(),
        hasLength(29),
      );
    });

    test('weekdayHeadings rotate with the week start', () {
      expect(weekdayHeadings(DateTime.sunday).first, 'SUN');
      expect(weekdayHeadings(DateTime.monday).first, 'MON');
      expect(weekdayHeadings(DateTime.monday).last, 'SUN');
    });

    testWidgets('selects enabled days only and pages months', (tester) async {
      final picked = <DateTime>[];
      await tester.pumpWidget(
        wrap(
          SingleChildScrollView(
            child: CalendarGrid(
              selected: DateTime(2026, 10, 14),
              firstDate: DateTime(2026, 10, 10),
              onSelected: picked.add,
            ),
          ),
        ),
      );
      expect(find.text('October 2026'), findsOneWidget);
      await tester.tap(find.text('5')); // before firstDate
      await tester.tap(find.text('20'));
      expect(picked, [DateTime(2026, 10, 20)]);

      await tester.tap(find.byTooltip('Next month'));
      await tester.pump();
      expect(find.text('November 2026'), findsOneWidget);
    });

    testWidgets('DateField expands, picks and collapses', (tester) async {
      DateTime value = DateTime(2026, 10, 14);
      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: DateField(
                label: 'Due',
                value: value,
                onChanged: (d) => setState(() => value = d),
              ),
            ),
          ),
        ),
      );
      expect(find.text('October 14, 2026'), findsOneWidget);
      await tester.tap(find.text('Due'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('21'));
      await tester.pumpAndSettle();
      expect(find.text('October 21, 2026'), findsOneWidget);
    });

    testWidgets('showDatePickerSheet returns the tapped date', (tester) async {
      DateTime? result;
      await tester.pumpWidget(
        launcher((context) async {
          result = await showDatePickerSheet(
            context,
            initialDate: DateTime(2026, 10, 14),
          );
        }),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      expect(result, DateTime(2026, 10, 3));
    });
  });

  group('ConsentCheckbox', () {
    testWidgets('builds the sentence and toggles', (tester) async {
      var value = false;
      var opened = '';
      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (context, setState) => ConsentCheckbox(
              value: value,
              onChanged: (v) => setState(() => value = v),
              links: [
                ConsentLink('Terms', () => opened = 'terms'),
                ConsentLink('Privacy', () => opened = 'privacy'),
                ConsentLink('Cookies', () => opened = 'cookies'),
              ],
            ),
          ),
        ),
      );
      expect(
        find.text(
          'I agree to the Terms, Privacy and Cookies.',
          findRichText: true,
        ),
        findsOneWidget,
      );
      await tester.tap(find.byType(AnimatedContainer));
      await tester.pump();
      expect(value, isTrue);
      expect(opened, isEmpty);
    });

    testWidgets('disabled when onChanged is null', (tester) async {
      await tester.pumpWidget(
        wrap(
          ConsentCheckbox(
            value: false,
            onChanged: null,
            links: [ConsentLink('Terms', () {})],
          ),
        ),
      );
      await tester.tap(find.byType(AnimatedContainer));
      expect(tester.takeException(), isNull);
    });
  });

  group('MarkdownEditingController', () {
    testWidgets('styles markers without changing the text', (tester) async {
      final controller = MarkdownEditingController(
        text: 'a **bold** and *it* `c`',
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(wrap(TextField(controller: controller)));
      final context = tester.element(find.byType(TextField));
      final span = controller.buildTextSpan(
        context: context,
        style: const TextStyle(color: Colors.black),
        withComposing: false,
      );
      expect(span.toPlainText(), controller.text);
      final bold = span.children!.cast<TextSpan>().firstWhere(
        (s) => s.text == 'bold',
      );
      expect(bold.style!.fontWeight, FontWeight.w700);
    });
  });
}
