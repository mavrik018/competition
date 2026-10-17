import 'dart:async';

import 'package:competition_toolkit_showcase/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Future<void> _openApp(WidgetTester tester) async {
  // A phone-sized screen, so overflows at small widths fail the test.
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: ShowcaseApp()));
}

Future<void> _open(WidgetTester tester, Demo demo) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  unawaited(
    navigator.push(MaterialPageRoute<void>(builder: (_) => DemoPage(demo))),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('every demo opens and closes without errors', (tester) async {
    await _openApp(tester);
    expect(find.text('Competition Toolkit'), findsOneWidget);

    for (final demo in allDemos) {
      await _open(tester, demo);
      expect(tester.takeException(), isNull, reason: demo.title);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull, reason: '${demo.title} (close)');
    }
  });

  testWidgets('AI demo labels AI output and fallbacks honestly', (
    tester,
  ) async {
    await _openApp(tester);
    await _open(tester, allDemos.firstWhere((d) => d.title == 'AI assistant'));
    await tester.tap(find.text('Run').first);
    await tester.pumpAndSettle();
    expect(find.text('AI'), findsOneWidget);

    await tester.tap(find.text('AI service available'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Run').first);
    await tester.pumpAndSettle();
    expect(find.text('Rule-based fallback'), findsOneWidget);
  });

  testWidgets('collaboration demo syncs both replicas', (tester) async {
    await _openApp(tester);
    await _open(
      tester,
      allDemos.firstWhere((d) => d.title == 'Real-time collaboration'),
    );
    await tester.enterText(find.byType(TextField).first, 'Milk');
    await tester.tap(find.byTooltip('Add on phone-a'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip('Add on phone-b'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Milk'), findsNWidgets(2));
  });

  testWidgets('voice demo parses the scripted phrase', (tester) async {
    await _openApp(tester);
    await _open(
      tester,
      allDemos.firstWhere((d) => d.title == 'Voice commands'),
    );
    await tester.tap(find.byTooltip('Start voice input'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(find.textContaining('intent: add_task'), findsOneWidget);
    expect(find.textContaining('call mum'), findsWidgets);
  });
}
