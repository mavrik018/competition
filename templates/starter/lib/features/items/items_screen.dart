// The CRUD screen: search, filters, sorts, add/edit form, swipe-delete with
// Undo, and empty/loading/error states — all from CrudListScreen (06).

import 'package:{{app_name}}/toolkit/03_feedback/app_snackbars.dart';
import 'package:{{app_name}}/toolkit/06_screen_templates/crud_list_screen.dart';
import 'package:{{app_name}}/toolkit/08_state_management/list_query.dart';
import 'package:{{app_name}}/toolkit/10_backend/app_exception.dart';
import 'package:{{app_name}}/toolkit/11_utilities/date_utils.dart';
import 'package:{{app_name}}/toolkit/13_smart_features/priority_scoring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'item.dart';
import 'item_form.dart';
import 'items_providers.dart';

class ItemsScreen extends ConsumerWidget {
  const ItemsScreen({super.key});

  Future<void> _save(BuildContext context, WidgetRef ref, Item item) async {
    try {
      await ref.read(itemsProvider.notifier).save(item);
    } catch (e) {
      if (context.mounted) context.showError(AppException.from(e).message);
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, [Item? item]) async {
    final result = await showItemForm(context, existing: item);
    if (result != null && context.mounted) await _save(context, ref, result);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    return CrudListScreen<Item>(
      title: 'Items',
      items: ref.watch(itemsProvider),
      idOf: (i) => i.id,
      titleOf: (i) => i.title,
      subtitleOf: (i) {
        final p = scorePriority(i.priorityInput, now: now);
        final due = i.due == null
            ? null
            : 'Due ${relativeDayLabel(i.due!, now: now)}';
        return [?due, if (!i.done) '${p.band.name} priority'].join(' · ');
      },
      leadingOf: (i) => Checkbox(
        value: i.done,
        semanticLabel: i.done
            ? 'Mark ${i.title} as not done'
            : 'Mark ${i.title} as done',
        onChanged: (v) => _save(context, ref, i.copyWith(done: v ?? false)),
      ),
      searchableText: (i) => '${i.title} ${i.notes ?? ''}',
      filters: [
        FilterOption('open', 'Open', (i) => !i.done),
        FilterOption('done', 'Done', (i) => i.done),
        FilterOption(
          'urgent',
          'Urgent',
          (i) =>
              !i.done &&
              scorePriority(i.priorityInput, now: now).band.index <=
                  PriorityBand.high.index,
        ),
      ],
      sorts: [
        const SortOption('priority', 'Priority', compareItems),
        SortOption(
          'title',
          'Title',
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        ),
        SortOption(
          'due',
          'Due date',
          (a, b) =>
              (a.due ?? DateTime(9999)).compareTo(b.due ?? DateTime(9999)),
        ),
      ],
      emptyIcon: Icons.checklist,
      emptyTitle: 'Nothing here yet',
      emptyMessage: 'Tap + to add your first item.',
      onAdd: () => _edit(context, ref),
      onTap: (i) => _edit(context, ref, i),
      onDelete: (i) => ref.read(itemsProvider.notifier).delete(i.id),
      onRestore: (i) => ref.read(itemsProvider.notifier).save(i),
      onRefresh: () => ref.read(itemsProvider.notifier).reload(),
    );
  }
}
