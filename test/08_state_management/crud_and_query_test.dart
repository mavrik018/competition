import 'package:competition_toolkit/08_state_management/crud_controller.dart';
import 'package:competition_toolkit/08_state_management/list_query.dart';
import 'package:competition_toolkit/09_persistence/repository.dart';
import 'package:competition_toolkit/09_persistence/sqflite_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class Task {
  const Task(this.id, this.title, {this.done = false, this.priority = 3});
  final String id;
  final String title;
  final bool done;
  final int priority;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'done': done,
    'priority': priority,
  };
  static Task fromJson(Map<String, Object?> j) => Task(
    j['id']! as String,
    j['title']! as String,
    done: j['done'] == true,
    priority: j['priority']! as int,
  );
}

/// Fails the next save/delete when [failNext] is set.
class FlakyRepository extends InMemoryRepository<Task> {
  FlakyRepository(List<Task> initial)
    : super(idOf: (t) => t.id, initial: initial);
  bool failNext = false;

  @override
  Future<void> save(Task item) {
    if (failNext) {
      failNext = false;
      throw StateError('offline');
    }
    return super.save(item);
  }

  @override
  Future<void> delete(String id) {
    if (failNext) {
      failNext = false;
      throw StateError('offline');
    }
    return super.delete(id);
  }
}

void main() {
  setUpAll(sqfliteFfiInit);

  group('Repositories', () {
    test('InMemoryRepository CRUD and watch', () async {
      final repo = InMemoryRepository<Task>(idOf: (t) => t.id);
      final emissions = <int>[];
      final sub = repo.watchAll().listen(
        (items) => emissions.add(items.length),
      );
      await repo.save(const Task('1', 'a'));
      await repo.save(const Task('1', 'a2')); // upsert
      await repo.save(const Task('2', 'b'));
      await repo.delete('1');
      await Future<void>.delayed(Duration.zero);
      expect(emissions, [0, 1, 1, 2, 1]);
      expect((await repo.getById('2'))!.title, 'b');
      expect(await repo.getById('1'), isNull);
      await sub.cancel();
    });

    test('SqfliteRepository stores JSON rows', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          singleInstance: false,
          onCreate: (db, _) => SqfliteRepository.createTable(db, 'tasks'),
        ),
      );
      addTearDown(db.close);
      final repo = SqfliteRepository<Task>(
        db,
        table: 'tasks',
        idOf: (t) => t.id,
        toJson: (t) => t.toJson(),
        fromJson: Task.fromJson,
      );
      await repo.save(const Task('1', 'Write tests', priority: 1));
      await repo.save(const Task('1', 'Write more tests', priority: 1));
      expect((await repo.getAll()).single.title, 'Write more tests');
      expect((await repo.getById('1'))!.priority, 1);
      final next = repo.watchAll().skip(1).first;
      await repo.delete('1');
      expect(await next, isEmpty);
    });
  });

  group('CrudController', () {
    late FlakyRepository repo;
    late AsyncNotifierProvider<CrudController<Task>, List<Task>> provider;

    setUp(() {
      repo = FlakyRepository([
        const Task('b', 'Bravo'),
        const Task('a', 'Alpha'),
      ]);
      provider = AsyncNotifierProvider<CrudController<Task>, List<Task>>(
        () => CrudController(
          (ref) => repo,
          idOf: (t) => t.id,
          sort: (x, y) => x.title.compareTo(y.title),
        ),
      );
    });

    test('loads sorted, adds and edits', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect((await c.read(provider.future)).map((t) => t.title), [
        'Alpha',
        'Bravo',
      ]);
      await c.read(provider.notifier).save(const Task('c', 'Charlie'));
      await c.read(provider.notifier).save(const Task('a', 'Zulu'));
      expect(c.read(provider).value!.map((t) => t.title), [
        'Bravo',
        'Charlie',
        'Zulu',
      ]);
      expect((await repo.getAll()).length, 3);
    });

    test('delete returns the item for undo', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(provider.future);
      final removed = await c.read(provider.notifier).delete('a');
      expect(removed!.title, 'Alpha');
      expect(c.read(provider).value!.length, 1);
      await c.read(provider.notifier).save(removed); // undo
      expect(c.read(provider).value!.length, 2);
      expect(await c.read(provider.notifier).delete('missing'), isNull);
    });

    test('failed writes roll back and rethrow', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(provider.future);
      repo.failNext = true;
      await expectLater(
        c.read(provider.notifier).save(const Task('x', 'X')),
        throwsStateError,
      );
      expect(c.read(provider).value!.length, 2);
      repo.failNext = true;
      await expectLater(
        c.read(provider.notifier).delete('a'),
        throwsStateError,
      );
      expect(c.read(provider).value!.length, 2);
    });

    test('reload re-reads the repository', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(provider.future);
      await repo.save(const Task('z', 'Added elsewhere'));
      await c.read(provider.notifier).reload();
      expect(c.read(provider).value!.length, 3);
    });
  });

  group('ListQuery', () {
    final tasks = [
      const Task('1', 'Oat milk 1L', priority: 2),
      const Task('2', 'Café meeting', done: true, priority: 1),
      const Task('3', 'Buy milk', priority: 1),
    ];
    final filters = [
      FilterOption<Task>('done', 'Done', (t) => t.done),
      FilterOption<Task>('urgent', 'Urgent', (t) => t.priority == 1),
    ];
    final sorts = [
      SortOption<Task>(
        'priority',
        'Priority',
        (a, b) => a.priority.compareTo(b.priority),
      ),
    ];
    List<String> run(ListQuery q, {FilterMode mode = FilterMode.all}) =>
        applyListQuery(
          tasks,
          q,
          searchableText: (t) => t.title,
          filters: filters,
          sorts: sorts,
          filterMode: mode,
        ).map((t) => t.id).toList();

    test('text matches all words in any order, ignoring case and accents', () {
      expect(run(const ListQuery(text: 'MILK oat')), ['1']);
      expect(run(const ListQuery(text: 'cafe')), ['2']);
      expect(run(const ListQuery(text: 'milk')), ['1', '3']);
    });

    test('filters combine with all/any', () {
      final both = const ListQuery()
          .toggleFilter('done')
          .toggleFilter('urgent');
      expect(run(both), ['2']);
      expect(run(both, mode: FilterMode.any), ['2', '3']);
      expect(both.toggleFilter('done').filterIds, {'urgent'});
    });

    test('sorting is stable and toggles direction', () {
      final sorted = const ListQuery().withSort('priority');
      expect(run(sorted), ['2', '3', '1']);
      expect(run(sorted.withSort('priority')), [
        '1',
        '2',
        '3',
      ]); // descending, ties keep order
      expect(run(const ListQuery(sortId: 'unknown')), ['1', '2', '3']);
    });

    test('helpers', () {
      expect(normalizeForSearch('Crème Brûlée!'), 'creme brulee');
      expect(const ListQuery(text: ' ').isEmpty, isTrue);
      expect(
        const ListQuery(
          text: 'x',
          filterIds: {'a'},
          sortId: 's',
        ).cleared().text,
        '',
      );
    });
  });
}
