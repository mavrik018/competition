/// The search box + filter chips + sort menu row that sits above a list,
/// driving a `ListQuery` (08).
///
/// Source: TaskFlow `search_screen.dart` (search field + filter pills) and
/// Cookly's pantry filters, rebuilt on `SearchField`, `AppChip` and
/// `showPickerSheet`. The bar only edits the query; filtering happens in
/// `applyListQuery`, so the logic is testable without widgets.
///
/// ```dart
/// SearchFilterBar<Task>(
///   query: query,
///   onChanged: (q) => setState(() => query = q),
///   filters: filters,
///   sorts: sorts,
/// ),
/// Expanded(child: TaskList(applyListQuery(tasks, query, searchableText: ..., filters: filters, sorts: sorts))),
/// ```
library;

import 'package:flutter/material.dart';

import '../01_design_system/app_tokens.dart';
import '../02_ui_elements/app_chip.dart';
import '../02_ui_elements/search_field.dart';
import '../04_dialogs_and_sheets/picker_sheet.dart';
import '../08_state_management/list_query.dart';

class SearchFilterBar<T> extends StatefulWidget {
  const SearchFilterBar({
    super.key,
    required this.query,
    required this.onChanged,
    this.filters = const [],
    this.sorts = const [],
    this.hintText = 'Search',
  });

  final ListQuery query;
  final ValueChanged<ListQuery> onChanged;
  final List<FilterOption<T>> filters;
  final List<SortOption<T>> sorts;
  final String hintText;

  @override
  State<SearchFilterBar<T>> createState() => _SearchFilterBarState<T>();
}

class _SearchFilterBarState<T> extends State<SearchFilterBar<T>> {
  late final _controller = TextEditingController(text: widget.query.text);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickSort() async {
    final id = await showPickerSheet<String>(
      context,
      title: 'Sort by',
      selected: widget.query.sortId,
      options: [
        for (final sort in widget.sorts)
          PickerOption(
            value: sort.id,
            label: sort.label,
            subtitle: sort.id == widget.query.sortId
                ? (widget.query.descending
                      ? 'Descending — tap to flip'
                      : 'Ascending — tap to flip')
                : null,
          ),
      ],
    );
    if (id != null) widget.onChanged(widget.query.withSort(id));
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.query;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SearchField(
                controller: _controller,
                hintText: widget.hintText,
                onChanged: (text) => widget.onChanged(query.withText(text)),
              ),
            ),
            if (widget.sorts.isNotEmpty)
              IconButton(
                tooltip: 'Sort',
                icon: Icon(
                  query.descending ? Icons.arrow_downward : Icons.sort,
                ),
                onPressed: _pickSort,
              ),
          ],
        ),
        if (widget.filters.isNotEmpty) ...[
          const SizedBox(height: Gap.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: Gap.sm,
              children: [
                for (final filter in widget.filters)
                  AppChip(
                    label: filter.label,
                    selected: query.filterIds.contains(filter.id),
                    onTap: () =>
                        widget.onChanged(query.toggleFilter(filter.id)),
                  ),
                if (query.filterIds.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      _controller.clear();
                      widget.onChanged(query.cleared());
                    },
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
