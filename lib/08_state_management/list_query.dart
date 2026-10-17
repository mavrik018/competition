/// Search + filter + sort for any in-memory list, as one immutable query
/// value and one pure function.
///
/// Source: TaskFlow `search_provider.dart` (text match over title and
/// description, combined with a filter pill), generalised: the searchable
/// text, the filters and the sort orders are passed in instead of being
/// hard-coded to tasks. Pair with `SearchFilterBar` (06) for the UI.
///
/// ```dart
/// final filters = [
///   FilterOption<Task>('today', 'Today', (t) => isSameDay(t.due, DateTime.now())),
///   FilterOption<Task>('high', 'High priority', (t) => t.priority == 1),
/// ];
/// final sorts = [
///   SortOption<Task>('due', 'Due date', (a, b) => a.due.compareTo(b.due)),
///   SortOption<Task>('title', 'Title', (a, b) => a.title.compareTo(b.title)),
/// ];
/// final visible = applyListQuery(tasks, query,
///     searchableText: (t) => '${t.title} ${t.notes}', filters: filters, sorts: sorts);
/// ```
library;

import 'package:flutter/foundation.dart';

class FilterOption<T> {
  const FilterOption(this.id, this.label, this.test);

  final String id;
  final String label;
  final bool Function(T item) test;
}

class SortOption<T> {
  const SortOption(this.id, this.label, this.compare);

  final String id;
  final String label;
  final int Function(T a, T b) compare;
}

/// How several active filters combine.
enum FilterMode {
  /// Item must pass every active filter (narrowing — the usual choice).
  all,

  /// Item must pass at least one (widening — e.g. several categories).
  any,
}

@immutable
class ListQuery {
  const ListQuery({
    this.text = '',
    this.filterIds = const {},
    this.sortId,
    this.descending = false,
  });

  final String text;
  final Set<String> filterIds;
  final String? sortId;
  final bool descending;

  bool get isEmpty => text.trim().isEmpty && filterIds.isEmpty;

  ListQuery withText(String value) => ListQuery(
    text: value,
    filterIds: filterIds,
    sortId: sortId,
    descending: descending,
  );

  /// Turns [filterId] on if off, off if on.
  ListQuery toggleFilter(String filterId) => ListQuery(
    text: text,
    filterIds: filterIds.contains(filterId)
        ? ({...filterIds}..remove(filterId))
        : {...filterIds, filterId},
    sortId: sortId,
    descending: descending,
  );

  /// Selecting the active sort again flips its direction.
  ListQuery withSort(String id) => ListQuery(
    text: text,
    filterIds: filterIds,
    sortId: id,
    descending: id == sortId ? !descending : false,
  );

  ListQuery cleared() => ListQuery(sortId: sortId, descending: descending);
}

/// Applies [query] to [items] without modifying them.
///
/// Text matching: every word of the query must appear somewhere in
/// [searchableText] (case-insensitive, any order) — so "milk oat" finds
/// "Oat milk 1L". Unknown filter or sort ids are ignored.
List<T> applyListQuery<T>(
  List<T> items,
  ListQuery query, {
  required String Function(T item) searchableText,
  List<FilterOption<T>> filters = const [],
  List<SortOption<T>> sorts = const [],
  FilterMode filterMode = FilterMode.all,
}) {
  final words = normalizeForSearch(
    query.text,
  ).split(' ').where((w) => w.isNotEmpty).toList();
  final active = filters.where((f) => query.filterIds.contains(f.id)).toList();

  final result = items.where((item) {
    if (words.isNotEmpty) {
      final haystack = normalizeForSearch(searchableText(item));
      if (!words.every(haystack.contains)) return false;
    }
    if (active.isEmpty) return true;
    return filterMode == FilterMode.all
        ? active.every((f) => f.test(item))
        : active.any((f) => f.test(item));
  }).toList();

  final sort = sorts.where((s) => s.id == query.sortId).firstOrNull;
  if (sort != null) {
    // List.sort is not stable; index tie-breaks keep equal items in order.
    final indexed = result.indexed.toList()
      ..sort((a, b) {
        final c = sort.compare(a.$2, b.$2);
        final directed = query.descending ? -c : c;
        return directed != 0 ? directed : a.$1.compareTo(b.$1);
      });
    return [for (final entry in indexed) entry.$2];
  }
  return result;
}

/// Lower-case, common accents removed, punctuation turned into spaces.
String normalizeForSearch(String text) {
  const accents = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', //
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
  };
  final buffer = StringBuffer();
  for (final char in text.toLowerCase().split('')) {
    buffer.write(accents[char] ?? char);
  }
  return buffer
      .toString()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim();
}
