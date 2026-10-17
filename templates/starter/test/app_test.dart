// Starter tests: forms (valid + invalid input), empty / error states,
// navigation between tabs, persistence across a restart, and settings.
// Storage is swapped through the provider — the screens never change.

import 'package:{{app_name}}/toolkit/09_persistence/repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:{{app_name}}/app.dart';
import 'package:{{app_name}}/features/items/item.dart';
import 'package:{{app_name}}/features/items/items_providers.dart';

/// A repository whose reads always fail — to test the error state.
class FailingRepository implements Repository<Item> {
  @override
  Future<List<Item>> getAll() async => throw StateError('disk on fire');
  @override
  Future<Item?> getById(String id) async => null;
  @override
  Stream<List<Item>> watchAll() => const Stream.empty();
  @override
  Future<void> save(Item item) async {}
  @override
  Future<void> delete(String id) async {}
}

Future<void> pumpApp(
  WidgetTester tester, {
  Repository<Item>? repository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (repository != null)
          itemRepositoryProvider.overrideWithValue(repository),
      ],
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Finds widgets inside the open bottom sheet (the list behind it has its
/// own search field and an empty-state "Add" button).
Finder inSheet(Finder matching) =>
    find.descendant(of: find.byType(BottomSheet), matching: matching);

Future<void> enterTitle(WidgetTester tester, String title) =>
    tester.enterText(inSheet(find.byType(TextField)).first, title);

/// Taps the form's submit button, scrolling the sheet to it first.
Future<void> submitForm(WidgetTester tester) async {
  final button = inSheet(find.widgetWithText(FilledButton, 'Add'));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> addItem(WidgetTester tester, String title) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  await enterTitle(tester, title);
  await submitForm(tester);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('empty state, invalid input, then a valid item', (tester) async {
    await pumpApp(tester, repository: InMemoryRepository(idOf: (i) => i.id));
    await tester.tap(find.text('Items'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing here yet'), findsOneWidget);

    // Submitting without a title shows the validation error.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await submitForm(tester);
    expect(find.text('Title is required'), findsOneWidget);
    await enterTitle(tester, 'Write report');
    await submitForm(tester);
    expect(find.text('Write report'), findsOneWidget);

    // Navigation: the dashboard reflects the new item.
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('1 open item'), findsOneWidget);
    expect(find.text('Next: Write report'), findsOneWidget);
  });

  testWidgets('marking done updates the dashboard', (tester) async {
    await pumpApp(tester, repository: InMemoryRepository(idOf: (i) => i.id));
    await tester.tap(find.text('Items'));
    await tester.pumpAndSettle();
    await addItem(tester, 'Buy milk');
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('All caught up'), findsOneWidget);
  });

  testWidgets('items persist across an app restart', (tester) async {
    await pumpApp(tester); // the real PrefsRepository
    await tester.tap(find.text('Items'));
    await tester.pumpAndSettle();
    await addItem(tester, 'Survives restart');

    await tester.pumpWidget(const SizedBox()); // drop the whole app
    await pumpApp(tester);
    await tester.tap(find.text('Items'));
    await tester.pumpAndSettle();
    expect(find.text('Survives restart'), findsOneWidget);
  });

  testWidgets('a storage failure shows an error with retry', (tester) async {
    await pumpApp(tester, repository: FailingRepository());
    await tester.tap(find.text('Items'));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('settings switch the theme to dark', (tester) async {
    await pumpApp(tester, repository: InMemoryRepository(idOf: (i) => i.id));
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark').last);
    await tester.pumpAndSettle();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });
}
