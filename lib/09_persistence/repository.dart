/// One CRUD interface for any entity, with an in-memory implementation (for
/// prototypes and tests). `SqfliteRepository` (`sqflite_repository.dart`),
/// `SupabaseRepository` (10) and `OfflineFirstRepository` (13) implement the
/// same interface, so screens and controllers never care where data lives.
///
/// This file depends on nothing but Dart, so `CrudController` and anything
/// else written against `Repository<T>` also works on the web.
///
/// Newly written. Each source app wrote one repository class per table
/// (`NoteRepository`, `PantryRepository`, `TaskRepositoryImpl`…) with the
/// same five methods; this is that shape once, generically.
///
/// ```dart
/// final Repository<Task> tasks = InMemoryRepository(idOf: (t) => t.id);
/// await tasks.save(Task(id: generateLocalId(), title: 'Buy milk'));
/// tasks.watchAll().listen(render);
/// ```
library;

import 'dart:async';

abstract interface class Repository<T> {
  Future<List<T>> getAll();
  Future<T?> getById(String id);

  /// Emits the full list now and after every change made through this
  /// repository.
  Stream<List<T>> watchAll();

  /// Inserts or replaces (upsert) by id.
  Future<void> save(T item);
  Future<void> delete(String id);
}

/// Keeps items in a map. Good for prototypes, demos and tests; data is lost
/// on restart.
class InMemoryRepository<T> implements Repository<T> {
  InMemoryRepository({required this.idOf, Iterable<T> initial = const []}) {
    for (final item in initial) {
      _items[idOf(item)] = item;
    }
  }

  final String Function(T item) idOf;
  final Map<String, T> _items = {};
  final _changes = StreamController<List<T>>.broadcast();

  @override
  Future<List<T>> getAll() async => List.unmodifiable(_items.values);

  @override
  Future<T?> getById(String id) async => _items[id];

  @override
  Stream<List<T>> watchAll() {
    // Subscribe to changes the moment someone listens, so a write made right
    // after `listen` is never missed.
    StreamSubscription<List<T>>? changes;
    late final StreamController<List<T>> controller;
    controller = StreamController<List<T>>(
      onListen: () {
        controller.add(List.unmodifiable(_items.values));
        changes = _changes.stream.listen(controller.add);
      },
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<void> save(T item) async {
    _items[idOf(item)] = item;
    _changes.add(List.unmodifiable(_items.values));
  }

  @override
  Future<void> delete(String id) async {
    _items.remove(id);
    _changes.add(List.unmodifiable(_items.values));
  }

  Future<void> dispose() => _changes.close();
}

/// Helper for `Repository.watchAll` implementations: emits [load]'s
/// result, then every list on [changes]. Subscribes to [changes]
/// immediately; if a change arrives before the first load finishes, the
/// (older) load result is dropped.
Stream<List<T>> watchList<T>(
  StreamController<List<T>> changes,
  Future<List<T>> Function() load,
) {
  StreamSubscription<List<T>>? subscription;
  late final StreamController<List<T>> controller;
  controller = StreamController<List<T>>(
    onListen: () {
      var changedMeanwhile = false;
      subscription = changes.stream.listen((items) {
        changedMeanwhile = true;
        controller.add(items);
      });
      load().then((items) {
        if (!changedMeanwhile && !controller.isClosed) controller.add(items);
      }, onError: controller.addError);
    },
    onCancel: () => subscription?.cancel(),
  );
  return controller.stream;
}
