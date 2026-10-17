// End-to-end tests of the three mini-apps: forms (valid and invalid input),
// loading, errors, empty states, persistence across a restart, navigation,
// and module combinations (state + storage + screens + smart features).

import 'package:competition_toolkit/01_design_system/app_palette.dart';
import 'package:competition_toolkit/01_design_system/app_theme.dart';
import 'package:competition_toolkit/09_persistence/repository.dart';
import 'package:competition_toolkit/13_smart_features/voice_input.dart';
import 'package:competition_toolkit_showcase/mini_apps/expense_tracker.dart';
import 'package:competition_toolkit_showcase/mini_apps/shared_list.dart';
import 'package:competition_toolkit_showcase/mini_apps/volunteer_match.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// One ProviderScope above MaterialApp — the same shape as a real app.
Future<void> host(
  WidgetTester tester,
  Widget app, {
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.build(AppPalette.studyBlue, Brightness.light),
        home: app,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder inSheet(Finder matching) =>
    find.descendant(of: find.byType(BottomSheet), matching: matching);

/// Single-choice fields are dropdowns: open the menu, pick the option.
Future<void> chooseInSheet(WidgetTester tester, String option) async {
  await tapVisible(
    tester,
    inSheet(find.byType(DropdownButtonFormField<String>)),
  );
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

class FailingRepository implements Repository<Expense> {
  @override
  Future<List<Expense>> getAll() async => throw StateError('storage broken');
  @override
  Future<Expense?> getById(String id) async => null;
  @override
  Stream<List<Expense>> watchAll() => const Stream.empty();
  @override
  Future<void> save(Expense item) async {}
  @override
  Future<void> delete(String id) async {}
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('Expense tracker', () {
    Future<void> addExpense(WidgetTester tester, String amount) async {
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(inSheet(find.byType(TextField)).first, amount);
      await chooseInSheet(tester, 'Food');
      await tapVisible(tester, inSheet(find.text('Save expense')));
    }

    testWidgets('empty state, invalid input, valid expense, insights, CSV', (
      tester,
    ) async {
      await host(
        tester,
        const ExpenseTrackerApp(),
        overrides: [
          expenseRepositoryProvider.overrideWithValue(
            InMemoryRepository(idOf: (e) => e.id),
          ),
        ],
      );
      expect(find.text('No expenses yet'), findsOneWidget);

      // Invalid: nothing entered, then a negative amount.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tapVisible(tester, inSheet(find.text('Save expense')));
      expect(find.text('Amount is required'), findsOneWidget);
      expect(find.text('Category is required'), findsOneWidget);
      await tester.enterText(inSheet(find.byType(TextField)).first, '-5');
      await tapVisible(tester, inSheet(find.text('Save expense')));
      expect(find.text('Must be at least 0.01'), findsOneWidget);

      // Valid.
      await tester.enterText(inSheet(find.byType(TextField)).first, '12,50');
      await chooseInSheet(tester, 'Food');
      await tapVisible(tester, inSheet(find.text('Save expense')));
      expect(find.text('€12.50 · Food'), findsOneWidget);

      // Navigation to insights; the KPI and export reflect the data.
      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();
      expect(find.text('€12.50'), findsWidgets);
      await tester.tap(find.byTooltip('Export CSV'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Date,Category,Amount,Note'), findsOneWidget);
    });

    testWidgets('expenses persist across an app restart', (tester) async {
      await host(tester, const ExpenseTrackerApp()); // real PrefsRepository
      await addExpense(tester, '9.99');
      expect(find.text('€9.99 · Food'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await host(tester, const ExpenseTrackerApp());
      expect(find.text('€9.99 · Food'), findsOneWidget);
    });

    testWidgets('a storage failure shows an error with retry', (tester) async {
      await host(
        tester,
        const ExpenseTrackerApp(),
        overrides: [
          expenseRepositoryProvider.overrideWithValue(FailingRepository()),
        ],
      );
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('insights tab has an empty state', (tester) async {
      await host(
        tester,
        const ExpenseTrackerApp(),
        overrides: [
          expenseRepositoryProvider.overrideWithValue(
            InMemoryRepository(idOf: (e) => e.id),
          ),
        ],
      );
      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();
      expect(find.text('No data yet'), findsOneWidget);
    });
  });

  group('Volunteer match', () {
    Future<void> signIn(
      WidgetTester tester,
      String email,
      String password,
    ) async {
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        email,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        password,
      );
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Sign in'));
    }

    testWidgets('validation, wrong password, then the full flow', (
      tester,
    ) async {
      await host(tester, const VolunteerMatchApp());

      await signIn(tester, 'not-an-email', 'x');
      expect(find.text('Enter a valid email address'), findsOneWidget);

      // Wrong password: loading, then a readable error.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        FakeVolunteerAuth.demoEmail,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'wrong-pass',
      );
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      await tester.pumpAndSettle();
      expect(find.text('Wrong email or password.'), findsOneWidget);

      await signIn(
        tester,
        FakeVolunteerAuth.demoEmail,
        FakeVolunteerAuth.demoPassword,
      );
      expect(find.text('Best matches'), findsOneWidget);

      // Ranked by the matcher: the best fit is first.
      final titles = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((t) => (t.title! as Text).data)
          .toList();
      expect(titles.first, 'Senior tech help');

      // Detail page (pushed on a phone) and gamification.
      await tester.tap(find.text('Senior tech help'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Match 97%'), findsOneWidget);
      await tapVisible(tester, find.text('Sign up (+40 XP)'));
      expect(find.text('Badge unlocked: First shift'), findsOneWidget);
      expect(find.text('Signed up'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('40'), findsOneWidget); // XP stat
      await tapVisible(tester, find.text('Sign out'));
      expect(find.text('Volunteer match'), findsOneWidget);
    });
  });

  group('Shared shopping list', () {
    testWidgets('typing, partner sync, offline hold and reconnect', (
      tester,
    ) async {
      await host(tester, const SharedListApp());
      expect(find.text('The list is empty'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Eggs');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Eggs'), findsOneWidget);

      await tester.tap(find.textContaining("Partner adds 'Bread'"));
      await tester.pumpAndSettle();
      expect(find.text('Bread'), findsOneWidget);

      // Offline: the partner's change is held back until reconnect.
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.textContaining("You're offline"), findsOneWidget);
      await tester.tap(find.textContaining("Partner adds 'Bread'"));
      await tester.pumpAndSettle();
      expect(find.text('Bread'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('Bread'), findsNWidgets(2));
    });

    testWidgets('voice commands add items; unknown phrases are reported', (
      tester,
    ) async {
      await host(
        tester,
        SharedListApp(
          speech: FakeSpeechInput([
            'buy apples',
            'hello there',
          ], step: const Duration(milliseconds: 10)),
        ),
      );
      await tester.tap(find.byTooltip('Start voice input'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('apples'), findsOneWidget);

      await tester.tap(find.byTooltip('Start voice input'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('Not understood: "hello there"'), findsOneWidget);
    });
  });
}
