/// A complete list screen for any entity: search/filter/sort, pull to
/// refresh, swipe to delete with Undo, an Add button, and loading / empty /
/// error states.
///
/// Newly written; it replaces the list half of every CRUD feature in the
/// source apps (TaskFlow tasks, Cookly pantry, StudyBuddies courses,
/// Couple wishlist). The screen holds only its search query — data and
/// writes come from the caller, typically a `CrudController` (08).
///
/// ```dart
/// final tasks = ref.watch(tasksProvider);              // AsyncValue<List<Task>>
/// CrudListScreen<Task>(
///   title: 'Tasks',
///   items: tasks,
///   idOf: (t) => t.id,
///   titleOf: (t) => t.title,
///   subtitleOf: (t) => relativeDayLabel(t.due),
///   searchableText: (t) => '${t.title} ${t.notes}',
///   filters: filters, sorts: sorts,
///   onAdd: () => openEditor(null),
///   onTap: openEditor,
///   onDelete: (t) => ref.read(tasksProvider.notifier).delete(t.id),
///   onRestore: (t) => ref.read(tasksProvider.notifier).save(t),
///   onRefresh: () => ref.read(tasksProvider.notifier).reload(),
/// )
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../01_design_system/app_tokens.dart';
import '../02_ui_elements/swipe_action_tile.dart';
import '../03_feedback/async_value_view.dart';
import '../03_feedback/state_views.dart';
import '../08_state_management/list_query.dart';
import 'search_filter_bar.dart';

class CrudListScreen<T> extends StatefulWidget {
  const CrudListScreen({
    super.key,
    required this.title,
    required this.items,
    required this.idOf,
    required this.titleOf,
    this.subtitleOf,
    this.leadingOf,
    this.trailingOf,
    this.searchableText,
    this.filters = const [],
    this.sorts = const [],
    this.onAdd,
    this.onTap,
    this.onDelete,
    this.onRestore,
    this.onRefresh,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
    this.addLabel = 'Add',
    this.errorMessage,
  });

  final String title;
  final AsyncValue<List<T>> items;
  final String Function(T item) idOf;
  final String Function(T item) titleOf;
  final String? Function(T item)? subtitleOf;
  final Widget? Function(T item)? leadingOf;
  final Widget? Function(T item)? trailingOf;

  /// Enables the search bar.
  final String Function(T item)? searchableText;
  final List<FilterOption<T>> filters;
  final List<SortOption<T>> sorts;
  final VoidCallback? onAdd;
  final ValueChanged<T>? onTap;

  /// Enables swipe-to-delete.
  final Future<void> Function(T item)? onDelete;

  /// Enables the Undo action after a delete.
  final Future<void> Function(T item)? onRestore;
  final Future<void> Function()? onRefresh;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptyMessage;
  final String addLabel;
  final String Function(Object error)? errorMessage;

  @override
  State<CrudListScreen<T>> createState() => _CrudListScreenState<T>();
}

class _CrudListScreenState<T> extends State<CrudListScreen<T>> {
  ListQuery _query = const ListQuery();

  Future<void> _delete(T item) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.onDelete!(item);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.errorMessage?.call(error) ??
                "Couldn't delete. Please try again.",
          ),
        ),
      );
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted "${widget.titleOf(item)}"'),
          action: widget.onRestore == null
              ? null
              : SnackBarAction(
                  label: 'Undo',
                  onPressed: () => widget.onRestore!(item),
                ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final hasSearch = widget.searchableText != null;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: widget.onAdd == null
          ? null
          : FloatingActionButton.extended(
              onPressed: widget.onAdd,
              icon: const Icon(Icons.add),
              label: Text(widget.addLabel),
            ),
      body: Column(
        children: [
          if (hasSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.gutter,
                0,
                Gap.gutter,
                Gap.sm,
              ),
              child: SearchFilterBar<T>(
                query: _query,
                onChanged: (q) => setState(() => _query = q),
                filters: widget.filters,
                sorts: widget.sorts,
              ),
            ),
          Expanded(
            child: AsyncValueView<List<T>>(
              value: widget.items,
              onRetry: widget.onRefresh,
              errorMessage: widget.errorMessage,
              data: (all) {
                final visible = hasSearch
                    ? applyListQuery(
                        all,
                        _query,
                        searchableText: widget.searchableText!,
                        filters: widget.filters,
                        sorts: widget.sorts,
                      )
                    : all;
                if (visible.isEmpty) {
                  return _query.isEmpty
                      ? EmptyView(
                          icon: widget.emptyIcon,
                          title: widget.emptyTitle,
                          message: widget.emptyMessage,
                          actionLabel: widget.onAdd == null
                              ? null
                              : widget.addLabel,
                          onAction: widget.onAdd,
                        )
                      : const EmptyView(
                          icon: Icons.search_off,
                          title: 'No matches',
                          message: 'Try other words or filters.',
                        );
                }
                final list = ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(
                    bottom: 96,
                  ), // clear of the FAB
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const Divider(indent: Gap.gutter),
                  itemBuilder: (context, i) => _tile(visible[i]),
                );
                return widget.onRefresh == null
                    ? list
                    : RefreshIndicator(
                        onRefresh: widget.onRefresh!,
                        child: list,
                      );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(T item) {
    final subtitle = widget.subtitleOf?.call(item);
    final tile = ListTile(
      leading: widget.leadingOf?.call(item),
      title: Text(widget.titleOf(item)),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: widget.trailingOf?.call(item),
      onTap: widget.onTap == null ? null : () => widget.onTap!(item),
      tileColor: Theme.of(context).colorScheme.surface,
    );
    if (widget.onDelete == null) return tile;
    return SwipeActionTile(
      key: ValueKey(widget.idOf(item)),
      borderRadius: 0,
      endAction: SwipeAction(
        icon: Icons.delete_outline,
        color: Theme.of(context).colorScheme.error,
        label: 'Delete',
        dismisses: true,
        onTriggered: () => _delete(item),
      ),
      child: tile,
    );
  }
}
