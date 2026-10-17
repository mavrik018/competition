import 'dart:async';

import 'package:competition_toolkit/03_feedback/loading_overlay.dart';
import 'package:competition_toolkit/04_dialogs_and_sheets/bottom_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  group('runWithLoading', () {
    testWidgets('shows progress while running and returns the result', (
      tester,
    ) async {
      final gate = Completer<int>();
      int? result;
      await tester.pumpWidget(
        launcher((context) async {
          result = await runWithLoading(
            context,
            () => gate.future,
            message: 'Paying…',
          );
        }),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      expect(find.text('Paying…'), findsOneWidget);
      gate.complete(7);
      await tester.pumpAndSettle();
      expect(result, 7);
      expect(find.text('Paying…'), findsNothing);
    });

    testWidgets('closes the dialog when the task throws', (tester) async {
      Object? caught;
      await tester.pumpWidget(
        launcher((context) async {
          try {
            await runWithLoading<void>(
              context,
              () async => throw StateError('declined'),
            );
          } catch (e) {
            caught = e;
          }
        }),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(caught, isA<StateError>());
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  testWidgets('LoadingOverlay blocks the child while loading', (tester) async {
    var taps = 0;
    Widget build(bool loading) => wrap(
      LoadingOverlay(
        isLoading: loading,
        message: 'Saving',
        child: Center(
          child: TextButton(onPressed: () => taps++, child: const Text('tap')),
        ),
      ),
    );
    await tester.pumpWidget(build(true));
    await tester.tap(find.text('tap'), warnIfMissed: false);
    expect(taps, 0);
    expect(find.text('Saving'), findsOneWidget);
    await tester.pumpWidget(build(false));
    await tester.tap(find.text('tap'));
    expect(taps, 1);
  });

  testWidgets('StatusBanner shows kind icon, action and dismiss', (
    tester,
  ) async {
    var acted = 0;
    var dismissed = 0;
    await tester.pumpWidget(
      wrap(
        StatusBanner(
          kind: StatusKind.warning,
          title: 'Trial',
          message: 'Ends in 3 days',
          actionLabel: 'Upgrade',
          onAction: () => acted++,
          onDismiss: () => dismissed++,
        ),
      ),
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    await tester.tap(find.text('Upgrade'));
    await tester.tap(find.byTooltip('Dismiss'));
    expect([acted, dismissed], [1, 1]);
  });

  testWidgets('showAppBottomSheet shows title, content and actions', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      launcher((context) async {
        result = await showAppBottomSheet<String>(
          context,
          title: 'Filters',
          builder: (_) => const Text('content'),
          actions: (sheet) => [
            TextButton(
              onPressed: () => Navigator.pop(sheet, 'applied'),
              child: const Text('Apply'),
            ),
          ],
        );
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('content'), findsOneWidget);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(result, 'applied');
  });
}
