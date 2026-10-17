import 'package:competition_toolkit/04_dialogs_and_sheets/alerts.dart';
import 'package:competition_toolkit/04_dialogs_and_sheets/picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  group('showAppConfirm', () {
    Future<bool?> run(WidgetTester tester, String tap) async {
      bool? result;
      await tester.pumpWidget(
        launcher((context) async {
          result = await showAppConfirm(
            context,
            title: 'Delete note?',
            message: 'This cannot be undone.',
            confirmLabel: 'Delete',
            destructive: true,
          );
        }),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('This cannot be undone.'), findsOneWidget);
      await tester.tap(find.text(tap));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('true on confirm', (tester) async {
      expect(await run(tester, 'Delete'), isTrue);
    });

    testWidgets('false on cancel', (tester) async {
      expect(await run(tester, 'Cancel'), isFalse);
    });

    testWidgets('false when dismissed by tapping outside', (tester) async {
      bool? result;
      await tester.pumpWidget(
        launcher((context) async {
          result = await showAppConfirm(context, title: 'Sure?');
        }),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });

  testWidgets('action callbacks run after the alert has closed', (
    tester,
  ) async {
    var alertWasOpen = true;
    await tester.pumpWidget(
      launcher((context) {
        showAppAlert(
          context,
          title: 'Title',
          actions: [
            AlertAction(
              label: 'Go',
              onPressed: () =>
                  alertWasOpen = find.text('Title').evaluate().isNotEmpty,
            ),
          ],
        );
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    expect(find.text('Title'), findsNothing);
    // onPressed ran synchronously right after pop: the route was popped.
    expect(alertWasOpen, isTrue);
  });

  testWidgets('three actions stack vertically', (tester) async {
    await tester.pumpWidget(
      launcher((context) {
        showAppAlert(
          context,
          title: 'Choose',
          actions: const [
            AlertAction(label: 'One'),
            AlertAction(label: 'Two'),
            AlertAction(label: 'Three'),
          ],
        );
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final one = tester.getCenter(find.text('One'));
    final three = tester.getCenter(find.text('Three'));
    expect(one.dx, three.dx);
    expect(three.dy, greaterThan(one.dy));
  });

  group('showTextPrompt', () {
    testWidgets('returns trimmed text on Done', (tester) async {
      String? result;
      await tester.pumpWidget(
        launcher((context) async {
          result = await showTextPrompt(
            context,
            title: 'Minutes',
            suffix: 'min',
          );
        }),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  45 ');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(result, '45');
      // No "controller used after dispose" during the closing animation.
      expect(tester.takeException(), isNull);
    });

    testWidgets('returns null on Cancel', (tester) async {
      String? result = 'unset';
      await tester.pumpWidget(
        launcher((context) async {
          result = await showTextPrompt(
            context,
            title: 'Name',
            initialValue: 'x',
          );
        }),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });
  });

  testWidgets('showAppMessage has a single OK', (tester) async {
    await tester.pumpWidget(
      launcher((context) => showAppMessage(context, title: 'Done!')),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Done!'), findsNothing);
  });

  group('showPickerSheet', () {
    const options = [
      PickerOption(value: 1, label: 'Newest', icon: Icons.schedule),
      PickerOption(value: 2, label: 'Title', subtitle: 'A to Z'),
      PickerOption(value: 3, label: 'Delete all', isDestructive: true),
    ];

    testWidgets('returns the tapped value and ticks the selected one', (
      tester,
    ) async {
      int? result;
      await tester.pumpWidget(
        launcher((context) async {
          result = await showPickerSheet<int>(
            context,
            title: 'Sort by',
            options: options,
            selected: 1,
          );
        }),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Sort by'), findsOneWidget);
      expect(find.text('A to Z'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing); // Material check unused
      await tester.tap(find.text('Title'));
      await tester.pumpAndSettle();
      expect(result, 2);
    });

    testWidgets('Cancel returns null', (tester) async {
      int? result = -1;
      await tester.pumpWidget(
        launcher((context) async {
          result = await showPickerSheet<int>(context, options: options);
        }),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });
  });

  testWidgets('SheetGrabber renders', (tester) async {
    await tester.pumpWidget(wrap(const SheetGrabber()));
    expect(find.byType(SheetGrabber), findsOneWidget);
  });
}
