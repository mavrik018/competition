import 'package:competition_toolkit/09_persistence/json_cache.dart';
import 'package:competition_toolkit/09_persistence/local_id.dart';
import 'package:competition_toolkit/09_persistence/offline_queue.dart';
import 'package:competition_toolkit/09_persistence/prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> _memoryDb() async {
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      singleInstance: false,
      onCreate: (db, _) async {
        await OfflineQueue.createTable(db);
        await JsonCache.createTables(db);
      },
    ),
  );
  addTearDown(db.close);
  return db;
}

void main() {
  setUpAll(sqfliteFfiInit);
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrefsStore', () {
    const done = PrefKey<bool>('done', false);
    const name = PrefKey<String>('name', 'Guest');
    const tags = PrefKey<List<String>>('tags', []);
    const score = PrefKey<double>('score', 0);

    Future<PrefsStore> store(Map<String, Object> values) async {
      SharedPreferences.setMockInitialValues(values);
      return PrefsStore(await SharedPreferences.getInstance());
    }

    test('returns defaults, then stored values', () async {
      final prefs = await store({});
      expect(prefs.get(done), isFalse);
      expect(prefs.get(name), 'Guest');
      await prefs.set(done, true);
      await prefs.set(name, 'Sam');
      await prefs.set(tags, ['a', 'b']);
      await prefs.set(score, 2.5);
      expect(prefs.get(done), isTrue);
      expect(prefs.get(name), 'Sam');
      expect(prefs.get(tags), ['a', 'b']);
      expect(prefs.get(score), 2.5);
      expect(prefs.contains(name), isTrue);
      await prefs.remove(name);
      expect(prefs.get(name), 'Guest');
    });

    test('a value of the wrong type falls back to the default', () async {
      final prefs = await store({'done': 'yes'});
      expect(prefs.get(done), isFalse);
    });

    test('JSON round-trips and corrupt JSON reads as absent', () async {
      final prefs = await store({'broken': '{not json'});
      await prefs.setJson('quiz', {'index': 3});
      expect(prefs.getJson('quiz'), {'index': 3});
      expect(prefs.getJson('broken'), isNull);
      expect(prefs.getJson('missing'), isNull);
    });
  });

  test('generateLocalId is a v4 UUID and unique', () {
    final pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    final ids = {for (var i = 0; i < 500; i++) generateLocalId()};
    expect(ids, hasLength(500));
    expect(ids.every(pattern.hasMatch), isTrue);
  });

  group('OfflineQueue', () {
    late DateTime now;
    late OfflineQueue queue;

    setUp(() async {
      now = DateTime(2026, 10, 14, 9);
      queue = OfflineQueue(await _memoryDb(), clock: () => now);
    });

    test('replays in creation order and removes done ops', () async {
      for (var i = 0; i < 3; i++) {
        await queue.enqueue('add', {'n': i}, userId: 'u1');
      }
      final seen = <int>[];
      final result = await queue.drain(
        userId: 'u1',
        handlers: {
          'add': (payload) async {
            seen.add(payload['n'] as int);
            return OpOutcome.done;
          },
        },
      );
      expect(seen, [0, 1, 2]);
      expect(result.done, 3);
      expect(await queue.pendingCount(userId: 'u1'), 0);
    });

    test('a retry stops the drain and backs off', () async {
      await queue.enqueue('a', {}, userId: 'u1');
      await queue.enqueue('b', {}, userId: 'u1');
      var bRuns = 0;
      final handlers = <String, OpHandler>{
        'a': (_) async => throw StateError('offline'),
        'b': (_) async {
          bRuns++;
          return OpOutcome.done;
        },
      };
      final result = await queue.drain(userId: 'u1', handlers: handlers);
      expect(result.stoppedEarly, isTrue);
      expect(bRuns, 0);

      final op = (await queue.all(userId: 'u1')).first;
      expect(op.attempts, 1);
      expect(op.lastError, contains('offline'));
      expect(op.nextAttemptAt, now.add(const Duration(seconds: 30)));

      // Not due yet: skipped entirely, so b runs.
      await queue.drain(userId: 'u1', handlers: handlers);
      expect(bRuns, 1);
    });

    test('backoff doubles up to 8 minutes', () {
      expect(OfflineQueue.backoff(1), const Duration(seconds: 30));
      expect(OfflineQueue.backoff(2), const Duration(minutes: 1));
      expect(OfflineQueue.backoff(5), const Duration(minutes: 8));
      expect(OfflineQueue.backoff(9), const Duration(minutes: 8));
    });

    test('exhausted ops stay for a manual retry', () async {
      final short = OfflineQueue(
        await _memoryDb(),
        maxAttempts: 1,
        clock: () => now,
      );
      final id = await short.enqueue('x', {}, userId: 'u1');
      final failing = {'x': (_) async => OpOutcome.retry};
      await short.drain(userId: 'u1', handlers: failing);
      now = now.add(const Duration(hours: 1));
      final result = await short.drain(userId: 'u1', handlers: failing);
      expect(result.stoppedEarly, isFalse); // exhausted op was not attempted
      expect(await short.pendingCount(userId: 'u1'), 1);

      await short.retryNow(id);
      final ok = await short.drain(
        userId: 'u1',
        handlers: {'x': (_) async => OpOutcome.done},
      );
      expect(ok.done, 1);
    });

    test('drop removes the op and reports it', () async {
      await queue.enqueue('bad', {'why': 'deleted'}, userId: 'u1');
      final result = await queue.drain(
        userId: 'u1',
        handlers: {'bad': (_) async => OpOutcome.drop},
      );
      expect(result.dropped.single.payload['why'], 'deleted');
      expect(await queue.pendingCount(userId: 'u1'), 0);
    });

    test('ops are scoped per user and unknown types are left alone', () async {
      await queue.enqueue('x', {}, userId: 'u1');
      await queue.enqueue('x', {}, userId: 'u2');
      await queue.enqueue('future_type', {}, userId: 'u1');
      await queue.drain(
        userId: 'u1',
        handlers: {'x': (_) async => OpOutcome.done},
      );
      expect(await queue.pendingCount(userId: 'u1'), 1); // the unknown type
      expect(await queue.pendingCount(userId: 'u2'), 1);
      await queue.clearUser('u2');
      expect(await queue.pendingCount(userId: 'u2'), 0);
    });

    test('a drain already running is not re-entered', () async {
      await queue.enqueue('x', {}, userId: 'u1');
      var runs = 0;
      final handlers = <String, OpHandler>{
        'x': (_) async {
          runs++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return OpOutcome.done;
        },
      };
      final results = await Future.wait([
        queue.drain(userId: 'u1', handlers: handlers),
        queue.drain(userId: 'u1', handlers: handlers),
      ]);
      expect(runs, 1);
      expect(results[1].done, 0);
    });
  });

  group('JsonCache', () {
    late JsonCache cache;
    var now = DateTime(2026, 10, 14, 9);

    setUp(() async {
      cache = JsonCache(await _memoryDb(), clock: () => now);
    });

    test('never-synced is null, synced-empty is an empty list', () async {
      expect(await cache.loadCollection('u1', 'notes'), isNull);
      await cache.saveCollection('u1', 'notes', []);
      expect(await cache.loadCollection('u1', 'notes'), isEmpty);
      expect(await cache.syncedAt('u1', 'notes'), now);
    });

    test('saving replaces the collection and keeps order', () async {
      await cache.saveCollection('u1', 'notes', [
        {'id': 'b', 'title': 'B'},
        {'id': 'a', 'title': 'A'},
      ]);
      now = now.add(const Duration(minutes: 5));
      await cache.saveCollection('u1', 'notes', [
        {'id': 'c', 'title': 'C'},
        {'id': 'b', 'title': 'B2'},
      ]);
      final rows = await cache.loadCollection('u1', 'notes');
      expect(rows!.map((r) => r['title']), ['C', 'B2']);
      expect(await cache.syncedAt('u1', 'notes'), now);
    });

    test('items without an id are keyed by position', () async {
      await cache.saveCollection('u1', 'tips', [
        {'text': 'one'},
        {'text': 'two'},
      ]);
      expect(await cache.loadCollection('u1', 'tips'), hasLength(2));
    });

    test('single items and per-user clearing', () async {
      await cache.saveItem('u1', 'note', '42', {'id': '42', 'body': 'hi'});
      await cache.saveCollection('u2', 'notes', [
        {'id': 'x'},
      ]);
      expect((await cache.loadItem('u1', 'note', '42'))!['body'], 'hi');
      expect(await cache.syncedAt('u1', 'note/42'), isNotNull);
      expect(await cache.loadItem('u1', 'note', 'missing'), isNull);

      await cache.clearUser('u1');
      expect(await cache.loadItem('u1', 'note', '42'), isNull);
      expect(await cache.loadCollection('u2', 'notes'), hasLength(1));
    });
  });
}
