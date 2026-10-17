/// List helpers that come up in every app.
///
/// Source: Couple `features/dates/domain/element_ordering.dart` (reorder and
/// re-index an ordered list, kept pure so it is testable without a device)
/// generalised from date elements to any item; [groupBy] and
/// [distinctBy] are newly written.
///
/// ```dart
/// ReorderableListView(
///   onReorder: (oldIndex, newIndex) => setState(() {
///     items = reorder(items, oldIndex, newIndex, fromReorderableListView: true);
///   }),
///   …
/// )
/// ```
library;

/// A copy of [items] with the item at [oldIndex] moved to [newIndex].
///
/// Flutter's `ReorderableListView.onReorder` reports [newIndex] as the
/// position *before* removal, so moving an item down needs one subtracted;
/// pass [fromReorderableListView] to apply that.
List<T> reorder<T>(
  List<T> items,
  int oldIndex,
  int newIndex, {
  bool fromReorderableListView = false,
}) {
  var target = newIndex;
  if (fromReorderableListView && newIndex > oldIndex) target -= 1;
  final copy = List<T>.of(items);
  final item = copy.removeAt(oldIndex);
  copy.insert(target.clamp(0, copy.length), item);
  return copy;
}

/// Groups [items] by [keyOf], keeping first-seen key order and item order.
Map<K, List<T>> groupBy<T, K>(Iterable<T> items, K Function(T item) keyOf) {
  final groups = <K, List<T>>{};
  for (final item in items) {
    (groups[keyOf(item)] ??= []).add(item);
  }
  return groups;
}

/// The first item for each distinct [keyOf], in order.
List<T> distinctBy<T, K>(Iterable<T> items, K Function(T item) keyOf) {
  final seen = <K>{};
  return [
    for (final item in items)
      if (seen.add(keyOf(item))) item,
  ];
}
