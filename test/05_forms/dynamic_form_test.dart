import 'package:competition_toolkit/05_forms/dynamic_form.dart';
import 'package:competition_toolkit/05_forms/validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  group('New validators', () {
    test('number', () {
      final v = Validators.number(min: 0, max: 10);
      expect(v('2,5'), isNull);
      expect(v('abc'), 'Enter a number');
      expect(v('11'), 'Must be at most 10');
      expect(v(''), isNull);
    });

    test('phone', () {
      final v = Validators.phone();
      expect(v('+44 20 7946 0958'), isNull);
      expect(v('(555) 123-4567'), isNull);
      expect(v('12345'), isNotNull);
      expect(v('call me'), isNotNull);
    });

    test('url', () {
      final v = Validators.url();
      expect(v('example.com'), isNull);
      expect(v('https://example.com/path?q=1'), isNull);
      expect(v('ftp://example.com'), isNotNull);
      expect(v('localhost'), isNotNull);
    });

    test('pattern matches the whole input', () {
      final v = Validators.pattern(
        RegExp(r'[A-Z]{2}\d{4}'),
        'Use format AB1234',
      );
      expect(v('AB1234'), isNull);
      expect(v('AB12345'), 'Use format AB1234');
    });
  });

  group('FieldSpec.fromJson', () {
    test('parses every type', () {
      final fields = [
        for (final json in [
          {'type': 'text', 'key': 'name', 'required': true, 'kind': 'email'},
          {'type': 'number', 'key': 'age', 'min': 0, 'decimal': false},
          {
            'type': 'choice',
            'key': 'role',
            'options': [
              'a',
              {'value': 'b', 'label': 'Bee'},
            ],
          },
          {'type': 'switch', 'key': 'news'},
          {'type': 'date', 'key': 'start'},
          {'type': 'slider', 'key': 'rating', 'min': 1, 'max': 5},
        ])
          FieldSpec.fromJson(json),
      ];
      expect((fields[0] as TextFieldSpec).kind, TextKind.email);
      expect(fields[0].required, isTrue);
      expect((fields[1] as NumberFieldSpec).decimal, isFalse);
      expect((fields[2] as ChoiceFieldSpec).options.last.label, 'Bee');
      expect(fields[5], isA<SliderFieldSpec>());
      expect(
        () => FieldSpec.fromJson({'type': 'colour', 'key': 'x'}),
        throwsFormatException,
      );
    });
  });

  group('DynamicForm', () {
    Future<Map<String, Object?>?> fill(
      WidgetTester tester, {
      Map<String, Object?> initial = const {},
    }) async {
      Map<String, Object?>? submitted;
      await tester.pumpWidget(
        wrap(
          SingleChildScrollView(
            child: DynamicForm(
              initialValues: initial,
              fields: const [
                TextFieldSpec(key: 'name', label: 'Name', required: true),
                TextFieldSpec(
                  key: 'email',
                  label: 'Email',
                  kind: TextKind.email,
                ),
                NumberFieldSpec(
                  key: 'age',
                  label: 'Age',
                  min: 0,
                  max: 120,
                  decimal: false,
                ),
                ChoiceFieldSpec(
                  key: 'tags',
                  label: 'Tags',
                  multiple: true,
                  required: true,
                  options: [
                    FieldOption('a', 'Alpha'),
                    FieldOption('b', 'Beta'),
                  ],
                ),
                SwitchFieldSpec(key: 'news', label: 'Newsletter'),
                SliderFieldSpec(
                  key: 'rating',
                  label: 'Rating',
                  min: 1,
                  max: 5,
                  divisions: 4,
                ),
              ],
              onSubmit: (values) => submitted = values,
            ),
          ),
        ),
      );
      return submitted;
    }

    testWidgets('blocks submit until required and formatted fields are valid', (
      tester,
    ) async {
      await fill(tester);
      await tester.tap(find.text('Submit'));
      await tester.pump();
      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Tags is required'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'nope',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Age'), '200');
      await tester.tap(find.text('Submit'));
      await tester.pump();
      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(find.text('Must be at most 120'), findsOneWidget);
    });

    testWidgets('submits typed values', (tester) async {
      Map<String, Object?>? submitted;
      await tester.pumpWidget(
        wrap(
          SingleChildScrollView(
            child: DynamicForm(
              fields: const [
                TextFieldSpec(key: 'name', label: 'Name', required: true),
                NumberFieldSpec(key: 'age', label: 'Age'),
                ChoiceFieldSpec(
                  key: 'tags',
                  label: 'Tags',
                  multiple: true,
                  options: [
                    FieldOption('a', 'Alpha'),
                    FieldOption('b', 'Beta'),
                  ],
                ),
                SwitchFieldSpec(key: 'news', label: 'Newsletter'),
                SliderFieldSpec(key: 'rating', label: 'Rating', min: 1, max: 5),
                TextFieldSpec(key: 'notes', label: 'Notes'),
              ],
              onSubmit: (values) => submitted = values,
            ),
          ),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name *'),
        '  Sam ',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Age'), '31');
      await tester.tap(find.text('Beta'));
      await tester.tap(find.text('Newsletter'));
      await tester.pump();
      await tester.ensureVisible(find.text('Submit'));
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(submitted, {
        'name': 'Sam',
        'age': 31,
        'tags': ['b'],
        'news': true,
        'rating': 1.0,
        'notes': null,
      });
    });

    testWidgets('initial values prefill the fields', (tester) async {
      await fill(
        tester,
        initial: {
          'name': 'Ana',
          'age': 40,
          'tags': ['a'],
          'news': true,
        },
      );
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Alpha'))
            .selected,
        isTrue,
      );
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
    });
  });
}
