// Mini-app 1 — Expense tracker.
//
// Puzzle pieces: TabShell (07) · CrudListScreen + DynamicForm in a bottom
// sheet (06, 05, 04) · CrudController + PrefsRepository (08, 09) ·
// dailySeries / analyzeTrend / generateInsights (13) · StatCard,
// SimpleLineChart, DonutChart, StatusBanner (02, 03) · toCsv (12).
//
// Persistence is real: PrefsRepository keeps expenses across restarts on
// every platform, including the web. Tests swap the repository through
// `expenseRepositoryProvider`.

import 'package:competition_toolkit/02_ui_elements/cards.dart';
import 'package:competition_toolkit/02_ui_elements/donut_chart.dart';
import 'package:competition_toolkit/02_ui_elements/line_chart.dart';
import 'package:competition_toolkit/03_feedback/loading_overlay.dart';
import 'package:competition_toolkit/03_feedback/state_views.dart';
import 'package:competition_toolkit/04_dialogs_and_sheets/bottom_sheets.dart';
import 'package:competition_toolkit/05_forms/dynamic_form.dart';
import 'package:competition_toolkit/06_screen_templates/crud_list_screen.dart';
import 'package:competition_toolkit/07_navigation/tab_shell.dart';
import 'package:competition_toolkit/08_state_management/crud_controller.dart';
import 'package:competition_toolkit/08_state_management/list_query.dart';
import 'package:competition_toolkit/09_persistence/local_id.dart';
import 'package:competition_toolkit/09_persistence/prefs_repository.dart';
import 'package:competition_toolkit/09_persistence/repository.dart';
import 'package:competition_toolkit/11_utilities/date_utils.dart';
import 'package:competition_toolkit/12_common_features/data_export.dart';
import 'package:competition_toolkit/13_smart_features/insights.dart';
import 'package:competition_toolkit/13_smart_features/trends.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Model ───────────────────────────────────────────────────────────────────

const expenseCategories = {
  'food': 'Food',
  'transport': 'Transport',
  'fun': 'Fun',
  'bills': 'Bills',
};

@immutable
class Expense {
  const Expense({
    required this.id,
    required this.amount,
    required this.category,
    required this.date,
    this.note,
  });

  final String id;
  final double amount;
  final String category;
  final DateTime date;
  final String? note;

  Map<String, Object?> toJson() => {
    'id': id,
    'amount': amount,
    'category': category,
    'date': date.toIso8601String(),
    'note': note,
  };

  factory Expense.fromJson(Map<String, Object?> json) => Expense(
    id: json['id']! as String,
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    category: (json['category'] as String?) ?? 'fun',
    date: DateTime.tryParse('${json['date']}') ?? DateTime(2000),
    note: json['note'] as String?,
  );
}

// ── State ───────────────────────────────────────────────────────────────────

final expenseRepositoryProvider = Provider<Repository<Expense>>(
  (ref) => PrefsRepository<Expense>(
    key: 'mini_expenses',
    idOf: (e) => e.id,
    toJson: (e) => e.toJson(),
    fromJson: Expense.fromJson,
  ),
);

final expensesProvider =
    AsyncNotifierProvider<CrudController<Expense>, List<Expense>>(
      () => CrudController(
        (ref) => ref.watch(expenseRepositoryProvider),
        idOf: (e) => e.id,
        sort: (a, b) => b.date.compareTo(a.date),
      ),
    );

/// Weekly budget used for the warning banner.
const weeklyBudget = 150.0;

String euros(num v) => '€${v.toStringAsFixed(2)}';

// ── App ─────────────────────────────────────────────────────────────────────

/// Providers come from the app's single ProviderScope (above MaterialApp),
/// so routes this app pushes (sheets, pages) can read them too. Tests
/// override `expenseRepositoryProvider` there.
class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) => TabShell(
    destinations: [
      TabDestination(
        label: 'Expenses',
        icon: Icons.receipt_long_outlined,
        builder: (_) => const _ExpensesScreen(),
      ),
      TabDestination(
        label: 'Insights',
        icon: Icons.insights_outlined,
        builder: (_) => const _InsightsScreen(),
      ),
    ],
  );
}

class _ExpensesScreen extends ConsumerWidget {
  const _ExpensesScreen();

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final expense = await showAppBottomSheet<Expense>(
      context,
      title: 'New expense',
      builder: (sheet) => DynamicForm(
        fields: [
          const NumberFieldSpec(
            key: 'amount',
            label: 'Amount',
            required: true,
            min: 0.01,
            max: 100000,
            decimal: true,
            suffix: '€',
          ),
          ChoiceFieldSpec(
            key: 'category',
            label: 'Category',
            required: true,
            options: [
              for (final MapEntry(:key, :value) in expenseCategories.entries)
                FieldOption(key, value),
            ],
          ),
          const TextFieldSpec(key: 'note', label: 'Note'),
        ],
        submitLabel: 'Save expense',
        onSubmit: (v) => Navigator.pop(
          sheet,
          Expense(
            id: generateLocalId(),
            amount: (v['amount']! as num).toDouble(),
            category: v['category']! as String,
            note: v['note'] as String?,
            date: DateTime.now(),
          ),
        ),
      ),
    );
    if (expense != null) {
      await ref.read(expensesProvider.notifier).save(expense);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => CrudListScreen<Expense>(
    title: 'Expenses',
    items: ref.watch(expensesProvider),
    idOf: (e) => e.id,
    titleOf: (e) => '${euros(e.amount)} · ${expenseCategories[e.category]}',
    subtitleOf: (e) => [relativeDayLabel(e.date), ?e.note].join(' · '),
    searchableText: (e) => '${e.note ?? ''} ${expenseCategories[e.category]}',
    filters: [
      for (final MapEntry(:key, :value) in expenseCategories.entries)
        FilterOption(key, value, (e) => e.category == key),
    ],
    sorts: [
      SortOption('date', 'Newest', (a, b) => b.date.compareTo(a.date)),
      SortOption('amount', 'Amount', (a, b) => b.amount.compareTo(a.amount)),
    ],
    emptyIcon: Icons.savings_outlined,
    emptyTitle: 'No expenses yet',
    emptyMessage: 'Tap Add to log your first one.',
    onAdd: () => _add(context, ref),
    onDelete: (e) => ref.read(expensesProvider.notifier).delete(e.id),
    onRestore: (e) => ref.read(expensesProvider.notifier).save(e),
    // Also enables the error state's "Try again" button.
    onRefresh: () => ref.read(expensesProvider.notifier).reload(),
  );
}

class _InsightsScreen extends ConsumerWidget {
  const _InsightsScreen();

  void _export(BuildContext context, List<Expense> expenses) {
    final csv = toCsv([
      ['Date', 'Category', 'Amount', 'Note'],
      for (final e in expenses)
        [
          e.date.toIso8601String().substring(0, 10),
          expenseCategories[e.category],
          e.amount.toStringAsFixed(2),
          e.note ?? '',
        ],
    ]);
    // On a device, pass utf8Bytes(csv, bom: true) to ShareService (12).
    showAppBottomSheet<void>(
      context,
      title: 'expenses.csv',
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          csv,
          style: const TextStyle(fontFamily: 'monospace'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expensesProvider).value ?? const <Expense>[];
    final now = DateTime.now();
    final days = dailySeries(
      expenses,
      dateOf: (e) => e.date,
      valueOf: (e) => e.amount,
      from: now.subtract(const Duration(days: 13)),
      to: now,
    );
    final lastWeek = days.skip(7).fold<double>(0, (s, d) => s + d.value);
    final byCategory = <String, double>{};
    for (final e in expenses) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }
    final insights = generateInsights(
      days,
      config: const InsightConfig(
        metric: 'spending',
        unit: '€',
        higherIsBetter: false,
        minDays: 7,
      ),
      now: now,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        actions: [
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(Icons.download_outlined),
            onPressed: expenses.isEmpty
                ? null
                : () => _export(context, expenses),
          ),
        ],
      ),
      body: expenses.isEmpty
          ? const EmptyView(
              icon: Icons.insights_outlined,
              title: 'No data yet',
              message: 'Insights appear once you log expenses.',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (lastWeek > weeklyBudget)
                  StatusBanner(
                    kind: StatusKind.warning,
                    title: 'Over budget',
                    message:
                        '${euros(lastWeek)} spent in the last 7 days — budget ${euros(weeklyBudget)}.',
                  ),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'Last 7 days',
                        value: euros(lastWeek),
                        icon: Icons.calendar_view_week,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        label: 'Trend',
                        value: analyzeTrend([
                          for (final d in days) d.value,
                        ]).direction.name,
                        icon: Icons.trending_flat,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SimpleLineChart(values: [for (final d in days) d.value]),
                const SizedBox(height: 16),
                DonutChart(
                  segments: [
                    for (final MapEntry(:key, :value) in byCategory.entries)
                      ChartSegment(expenseCategories[key]!, value),
                  ],
                  centerLabel: euros(
                    expenses.fold<double>(0, (s, e) => s + e.amount),
                  ),
                  centerCaption: 'total',
                ),
                const SizedBox(height: 16),
                for (final insight in insights) InsightCard(insight: insight),
              ],
            ),
    );
  }
}
