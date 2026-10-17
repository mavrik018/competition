/// A Riverpod controller for a list of entities stored in any [Repository]:
/// load, create/update, delete with undo, and reload — with optimistic
/// updates that roll back when the repository throws.
///
/// Newly written. Each source app had a hand-written controller per entity
/// (`PantryController`, `TasksProvider`, `NoteNotifier`…) repeating this
/// logic, some optimistic and some not.
///
/// ```dart
/// final tasksProvider = AsyncNotifierProvider<CrudController<Task>, List<Task>>(
///   () => CrudController(
///     (ref) => ref.watch(taskRepositoryProvider),
///     idOf: (t) => t.id,
///     sort: (a, b) => a.due.compareTo(b.due),
///   ),
/// );
///
/// await ref.read(tasksProvider.notifier).save(task);          // add or edit
/// final removed = await ref.read(tasksProvider.notifier).delete(task.id);
/// // Undo:
/// if (removed != null) await ref.read(tasksProvider.notifier).save(removed);
/// ```
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../09_persistence/repository.dart';

class CrudController<T> extends AsyncNotifier<List<T>> {
  CrudController(this._repositoryOf, {required this.idOf, this.sort});

  final Repository<T> Function(Ref ref) _repositoryOf;
  final String Function(T item) idOf;

  /// Keeps the list ordered after every change. Null keeps repository order.
  final int Function(T a, T b)? sort;

  late Repository<T> _repository;

  @override
  Future<List<T>> build() async {
    _repository = _repositoryOf(ref);
    return _sorted(await _repository.getAll());
  }

  List<T> get _current => state.value ?? const [];

  List<T> _sorted(List<T> items) {
    final copy = List<T>.of(items);
    if (sort != null) copy.sort(sort);
    return copy;
  }

  /// Adds or replaces [item]. The list updates immediately; if saving
  /// fails, the previous list is restored and the error is rethrown so the
  /// screen can show it.
  Future<void> save(T item) async {
    final before = _current;
    final id = idOf(item);
    final exists = before.any((e) => idOf(e) == id);
    state = AsyncData(
      _sorted(
        exists
            ? [for (final e in before) idOf(e) == id ? item : e]
            : [...before, item],
      ),
    );
    try {
      await _repository.save(item);
    } catch (_) {
      if (ref.mounted) state = AsyncData(before);
      rethrow;
    }
  }

  /// Removes the item with [id] and returns it (for an Undo snackbar), or
  /// null if it was not in the list. Rolls back and rethrows on failure.
  Future<T?> delete(String id) async {
    final before = _current;
    final index = before.indexWhere((e) => idOf(e) == id);
    if (index < 0) return null;
    final removed = before[index];
    state = AsyncData([...before]..removeAt(index));
    try {
      await _repository.delete(id);
      return removed;
    } catch (_) {
      if (ref.mounted) state = AsyncData(before);
      rethrow;
    }
  }

  /// Re-reads everything from the repository (pull to refresh). Keeps the
  /// current list visible while loading.
  Future<void> reload() async {
    state = await AsyncValue.guard(
      () async => _sorted(await _repository.getAll()),
    );
  }
}
