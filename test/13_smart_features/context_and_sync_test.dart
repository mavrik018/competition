import 'dart:convert';

import 'package:competition_toolkit/09_persistence/offline_queue.dart';
import 'package:competition_toolkit/09_persistence/repository.dart';
import 'package:competition_toolkit/13_smart_features/accessibility.dart';
import 'package:competition_toolkit/13_smart_features/contextual_actions.dart';
import 'package:competition_toolkit/13_smart_features/offline_first_repository.dart';
import 'package:competition_toolkit/13_smart_features/personalization.dart';
import 'package:competition_toolkit/13_smart_features/realtime_collaboration.dart';
import 'package:competition_toolkit/13_smart_features/voice_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers.dart';

typedef Note = ({String id, String text, DateTime updatedAt});

Map<String, dynamic> noteToJson(Note n) => {
  'id': n.id,
  'text': n.text,
  'updatedAt': n.updatedAt.toIso8601String(),
};

Note noteFromJson(Map<String, dynamic> j) => (
  id: j['id'] as String,
  text: j['text'] as String,
  updatedAt: DateTime.parse(j['updatedAt'] as String),
);

/// A remote repository that can be "offline" (transient errors) or reject
/// items for good (permanent errors).
class FlakyRepository implements Repository<Note> {
  final inner = InMemoryRepository<Note>(idOf: (n) => n.id);
  bool offline = false;
  bool Function(Note note) rejects = (_) => false;

  void _check() {
    if (offline) throw StateError('network down');
  }

  @override
  Future<List<Note>> getAll() async {
    _check();
    return inner.getAll();
  }

  @override
  Future<Note?> getById(String id) async {
    _check();
    return inner.getById(id);
  }

  @override
  Stream<List<Note>> watchAll() => inner.watchAll();

  @override
  Future<void> save(Note item) async {
    _check();
    if (rejects(item)) throw ArgumentError('invalid note');
    await inner.save(item);
  }

  @override
  Future<void> delete(String id) async {
    _check();
    await inner.delete(id);
  }
}

/// Lets queued broadcast-stream events through.
Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('contextual actions', () {
    final monday8am = DateTime(2026, 3, 9, 8);
    final engine = ContextualActionEngine([
      ContextualAction.fromJson({
        'id': 'restock',
        'label': 'Restock milk',
        'icon': 'cart',
        'when': {'field': 'lowStockCount', 'op': '>', 'value': 0},
      }),
      ContextualAction.fromJson({
        'id': 'focus',
        'label': 'Start focus session',
        'icon': 'timer',
        'priority': 5,
        'when': {'field': 'partOfDay', 'op': '==', 'value': 'morning'},
      }),
      ContextualAction.fromJson({
        'id': 'brunch',
        'label': 'Plan brunch',
        'when': {'field': 'isWeekend', 'op': '==', 'value': true},
      }),
    ]);

    test('contextFacts describes the moment', () {
      final facts = contextFacts(monday8am, {'lowStockCount': 2});
      expect(facts['partOfDay'], 'morning');
      expect(facts['isWeekend'], isFalse);
      expect(facts['weekday'], 1);
      expect(facts['lowStockCount'], 2);
      expect(contextFacts(DateTime(2026, 3, 14, 23))['partOfDay'], 'night');
    });

    test('suggests matching actions by priority and respects dismissals', () {
      final facts = contextFacts(monday8am, {'lowStockCount': 2});
      expect(
        [for (final a in engine.suggest(facts, now: monday8am)) a.id],
        ['focus', 'restock'],
      );
      expect(engine.actions[1].icon, Icons.timer_outlined);

      engine.dismiss('focus', at: monday8am);
      expect(
        [for (final a in engine.suggest(facts, now: monday8am)) a.id],
        ['restock'],
      );
      final later = monday8am.add(const Duration(hours: 13));
      expect(
        engine.suggest(facts, now: later).map((a) => a.id),
        contains('focus'),
      );
    });

    testWidgets('ContextualActionBar selects and hides', (tester) async {
      String? selected;
      String? hidden;
      await tester.pumpWidget(
        wrap(
          ContextualActionBar(
            actions: engine.actions.take(2).toList(),
            onSelected: (a) => selected = a.id,
            onDismissed: (a) => hidden = a.id,
          ),
        ),
      );
      await tester.tap(find.text('Start focus session'));
      expect(selected, 'focus');
      await tester.tap(find.byTooltip('Hide "Restock milk"'));
      expect(hidden, 'restock');

      await tester.pumpWidget(
        wrap(ContextualActionBar(actions: const [], onSelected: (_) {})),
      );
      expect(find.byType(InputChip), findsNothing);
    });
  });

  group('PreferenceProfile', () {
    final t0 = DateTime(2026, 3, 1);
    final twoWeeksLater = t0.add(const Duration(days: 14));

    test('scores decay by half-life and rank keys', () {
      final profile = PreferenceProfile()
        ..record('italian', weight: InteractionWeight.favourite, at: t0)
        ..record('thai', at: twoWeeksLater)
        ..record('fish', weight: InteractionWeight.skip, at: twoWeeksLater);
      expect(
        profile.affinity('italian', now: twoWeeksLater),
        closeTo(1.5, 1e-9),
      );
      expect(profile.affinity('unknown'), 0);
      expect(
        [for (final e in profile.topKeys(now: twoWeeksLater)) e.key],
        ['italian', 'thai'],
      );
    });

    test('orders items by affinity, keeping order for ties', () {
      final profile = PreferenceProfile()
        ..record('italian', weight: 3, at: t0)
        ..record('thai', at: t0);
      final items = [
        ('a', ['thai']),
        ('b', ['italian']),
        ('c', <String>[]),
        ('d', ['italian']),
      ];
      final ordered = profile.orderByAffinity(items, (i) => i.$2, now: t0);
      expect([for (final i in ordered) i.$1], ['b', 'd', 'a', 'c']);
    });

    test('preferred hour needs enough samples', () {
      final profile = PreferenceProfile();
      for (final h in [19, 19, 19, 8]) {
        profile.recordActiveAt(DateTime(2026, 3, 1, h));
      }
      expect(profile.preferredHour(), isNull);
      profile.recordActiveAt(DateTime(2026, 3, 2, 8));
      expect(profile.preferredHour(), 19);
    });

    test('JSON round trip, tolerant parsing and reset', () {
      final profile = PreferenceProfile(halfLife: const Duration(days: 7))
        ..record('tag', weight: 2, at: t0)
        ..recordActiveAt(DateTime(2026, 3, 1, 7));
      final copy = PreferenceProfile.fromJson(
        jsonDecode(jsonEncode(profile.toJson())) as Map<String, dynamic>,
      );
      expect(copy.halfLife, const Duration(days: 7));
      expect(copy.affinity('tag', now: t0), 2);
      expect(copy.toJson()['activeHours'], profile.toJson()['activeHours']);

      final broken = PreferenceProfile.fromJson({
        'scores': {
          'x': 'nonsense',
          'y': {'score': 1, 'at': 'not a date'},
        },
        'activeHours': [1, 2],
      });
      expect(broken.topKeys(), isEmpty);

      copy.reset();
      expect(copy.affinity('tag', now: t0), 0);
    });
  });

  group('accessibility', () {
    test('contrast maths', () {
      expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 1e-6));
      expect(contrastRatio(Colors.red, Colors.red), closeTo(1, 1e-9));
      expect(meetsWcag(Colors.grey, Colors.white), isFalse);
      expect(meetsWcag(Colors.grey, Colors.white, largeText: true), isFalse);
      const grey767676 = Color(0xFF767676); // the classic 4.54:1 grey
      expect(meetsWcag(grey767676, Colors.white), isTrue);
      expect(
        meetsWcag(grey767676, Colors.white, level: WcagLevel.aaa),
        isFalse,
      );
      expect(readableOn(Colors.yellow), Colors.black);
      expect(readableOn(Colors.indigo), Colors.white);
    });

    test('preferences JSON round trip', () {
      const prefs = AccessibilityPreferences(textScale: 1.3, boldText: true);
      expect(AccessibilityPreferences.fromJson(prefs.toJson()), prefs);
      expect(prefs.copyWith(reduceMotion: true).reduceMotion, isTrue);
    });

    testWidgets('AccessibilityScope overrides MediaQuery and theme', (
      tester,
    ) async {
      late BuildContext inner;
      late ColorScheme outer;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) {
              outer = Theme.of(context).colorScheme;
              return AccessibilityScope(
                preferences: const AccessibilityPreferences(
                  textScale: 1.5,
                  boldText: true,
                  reduceMotion: true,
                  highContrast: true,
                ),
                child: Builder(
                  builder: (context) {
                    inner = context;
                    return const Text('hi');
                  },
                ),
              );
            },
          ),
        ),
      );
      expect(MediaQuery.textScalerOf(inner).scale(10), closeTo(15, 1e-9));
      expect(MediaQuery.boldTextOf(inner), isTrue);
      expect(MediaQuery.disableAnimationsOf(inner), isTrue);
      expect(MediaQuery.highContrastOf(inner), isTrue);
      expect(Theme.of(inner).colorScheme, highContrastScheme(outer));
    });

    testWidgets('AccessibleTapTarget is 48x48 and labelled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(
          Center(
            child: AccessibleTapTarget(
              label: 'Close',
              onTap: () => taps++,
              child: const Icon(Icons.close, size: 16),
            ),
          ),
        ),
      );
      final size = tester.getSize(find.byType(AccessibleTapTarget));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(find.bySemanticsLabel('Close'), findsOneWidget);
      await tester.tap(find.byType(AccessibleTapTarget));
      expect(taps, 1);
    });

    testWidgets('announce sends an accessibility event', (tester) async {
      final sent = <Object?>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, (
            message,
          ) async {
            sent.add(message);
            return null;
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility,
              null,
            ),
      );
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => announce(context, '3 results found'),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      final event = sent.whereType<Map<Object?, Object?>>().singleWhere(
        (e) => e['type'] == 'announce',
      );
      expect(event['type'], 'announce');
      expect((event['data'] as Map)['message'], '3 results found');
    });
  });

  group('voice input', () {
    final now = DateTime(2026, 3, 9, 10); // Monday 10:00

    test('parseNaturalTime understands common phrases', () {
      void check(String text, DateTime? at, String rest, {bool? hasTime}) {
        final result = parseNaturalTime(text, now: now);
        expect(result.at, at, reason: text);
        expect(result.rest, rest, reason: text);
        if (hasTime != null) expect(result.hasTime, hasTime, reason: text);
      }

      check('call mum tomorrow at 5pm', DateTime(2026, 3, 10, 17), 'call mum');
      check('buy milk in 20 minutes', DateTime(2026, 3, 9, 10, 20), 'buy milk');
      check('in half an hour stretch', DateTime(2026, 3, 9, 10, 30), 'stretch');
      check('ping in an hour', DateTime(2026, 3, 9, 11), 'ping');
      check('water plants at 8', DateTime(2026, 3, 10, 8), 'water plants');
      check('gym at 6', DateTime(2026, 3, 9, 18), 'gym');
      check('pay rent at 9:15 pm', DateTime(2026, 3, 9, 21, 15), 'pay rent');
      check(
        'dentist on Friday',
        DateTime(2026, 3, 13, 9),
        'dentist',
        hasTime: false,
      );
      check(
        'meeting next monday at 10:30',
        DateTime(2026, 3, 16, 10, 30),
        'meeting',
      );
      check('party tonight', DateTime(2026, 3, 9, 20), 'party', hasTime: true);
      check('read in the evening', DateTime(2026, 3, 9, 18), 'read');
      check('lunch at noon', DateTime(2026, 3, 9, 12), 'lunch');
      check('no time here', null, 'no time here', hasTime: false);
    });

    const parser = VoiceCommandParser([
      VoiceIntent('add_task', ['remind me to {title}', 'add {title}']),
      VoiceIntent('timer', ['set a timer for {minutes} minutes']),
      VoiceIntent('search', ['search for {query}']),
    ]);

    test('VoiceCommandParser extracts intent, slots and time', () {
      final remind = parser.parse(
        'Remind me to call mum tomorrow at 5pm.',
        now: now,
      )!;
      expect(remind.intent, 'add_task');
      expect(remind.slots, {'title': 'call mum'});
      expect(remind.at, DateTime(2026, 3, 10, 17));

      final timer = parser.parse('set a timer for 10 minutes', now: now)!;
      expect(
        (timer.intent, timer.slots['minutes'], timer.at),
        ('timer', '10', null),
      );
      expect(parser.parse('Add Eggs', now: now)!.slots['title'], 'Eggs');
      expect(
        parser.parse('search for pasta recipes', now: now)!.slots['query'],
        'pasta recipes',
      );
      expect(parser.parse("what's the weather", now: now), isNull);
    });

    testWidgets('VoiceInputButton streams partial then final words', (
      tester,
    ) async {
      final partials = <String>[];
      String? result;
      final speech = FakeSpeechInput(['add oat milk']);
      await tester.pumpWidget(
        wrap(
          VoiceInputButton(
            speech: speech,
            onPartial: partials.add,
            onResult: (text) => result = text,
          ),
        ),
      );
      await tester.tap(find.byTooltip('Start voice input'));
      await tester.pump();
      expect(find.byTooltip('Stop voice input'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 60));
      expect(partials, ['add', 'add oat']);
      expect(result, 'add oat milk');
      expect(find.byTooltip('Start voice input'), findsOneWidget);
    });

    testWidgets('stopping early gives no result', (tester) async {
      String? result;
      await tester.pumpWidget(
        wrap(
          VoiceInputButton(
            speech: FakeSpeechInput(['one two three']),
            onResult: (text) => result = text,
          ),
        ),
      );
      await tester.tap(find.byTooltip('Start voice input'));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.byTooltip('Stop voice input'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(result, isNull);
    });

    testWidgets('unavailable speech shows an error', (tester) async {
      await tester.pumpWidget(
        wrap(
          VoiceInputButton(
            speech: FakeSpeechInput(const [], available: false),
            onResult: (_) {},
          ),
        ),
      );
      await tester.tap(find.byTooltip('Start voice input'));
      await tester.pump();
      expect(
        find.textContaining('Voice input is not available'),
        findsOneWidget,
      );
    });
  });

  group('OfflineFirstRepository', () {
    setUpAll(sqfliteFfiInit);

    late Database db;
    late FlakyRepository remote;
    late InMemoryRepository<Note> local;
    late OfflineFirstRepository<Note> repo;
    var online = false;
    var clock = DateTime(2026, 3, 1, 9);
    final t1 = DateTime(2026, 3, 1);
    final t2 = DateTime(2026, 3, 2);

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          singleInstance: false,
          onCreate: (db, _) => OfflineQueue.createTable(db),
        ),
      );
      online = false;
      clock = DateTime(2026, 3, 1, 9);
      remote = FlakyRepository();
      local = InMemoryRepository<Note>(idOf: (n) => n.id);
      repo = OfflineFirstRepository<Note>(
        name: 'notes',
        local: local,
        remote: remote,
        queue: OfflineQueue(db, clock: () => clock),
        idOf: (n) => n.id,
        updatedAtOf: (n) => n.updatedAt,
        toJson: noteToJson,
        fromJson: noteFromJson,
        isOnline: () => online,
        isPermanentError: (e) => e is ArgumentError,
      );
    });
    tearDown(() async {
      await repo.sync().catchError((_) => const SyncReport());
      await db.close();
    });

    test('writes offline, pushes when back online', () async {
      await repo.save((id: 'n1', text: 'offline', updatedAt: t1));
      expect(await repo.getById('n1'), isNotNull);
      final offlineReport = await repo.sync();
      expect(offlineReport.skippedOffline, isTrue);
      expect(offlineReport.pending, 1);
      expect(await remote.inner.getAll(), isEmpty);

      online = true;
      final report = await repo.sync();
      expect(report.pushed, 1);
      expect(report.pending, 0);
      expect((await remote.inner.getById('n1'))!.text, 'offline');
    });

    test('deletes are queued too', () async {
      online = true;
      await remote.inner.save((id: 'n1', text: 'x', updatedAt: t1));
      await repo.sync();
      online = false;
      await repo.delete('n1');
      online = true;
      await repo.sync();
      expect(await remote.inner.getById('n1'), isNull);
      expect(await local.getById('n1'), isNull);
    });

    test('pull merges by last-write-wins', () async {
      await local.save((id: 'old', text: 'local old', updatedAt: t1));
      await local.save((id: 'new', text: 'local new', updatedAt: t2));
      await remote.inner.save((id: 'old', text: 'server', updatedAt: t2));
      await remote.inner.save((id: 'new', text: 'server old', updatedAt: t1));
      await remote.inner.save((id: 'extra', text: 'from web', updatedAt: t1));
      online = true;
      final report = await repo.sync();
      expect(report.pulled, 2);
      expect((await local.getById('old'))!.text, 'server');
      expect((await local.getById('new'))!.text, 'local new');
      expect((await local.getById('extra'))!.text, 'from web');
    });

    test(
      'unsent edits survive a pull; newer server copy wins the push',
      () async {
        online = true;
        remote.offline = true; // reachable network, failing server
        await repo.save((id: 'n1', text: 'mine', updatedAt: t1));
        await repo.sync();
        expect(await repo.pendingCount(), 1);

        // Meanwhile someone else saved a newer version on the server.
        remote.offline = false;
        await remote.inner.save((id: 'n1', text: 'theirs', updatedAt: t2));
        clock = clock.add(const Duration(minutes: 1)); // past the retry backoff
        final report = await repo.sync();
        expect(report.dropped, hasLength(1)); // our older edit lost
        expect((await local.getById('n1'))!.text, 'theirs');
      },
    );

    test('permanent errors are dropped and reported', () async {
      remote.rejects = (n) => n.text.isEmpty;
      await repo.save((id: 'bad', text: '', updatedAt: t1));
      online = true;
      final report = await repo.sync();
      expect(await repo.pendingCount(), 0);
      expect(report.dropped.single.payload['id'], 'bad');
      expect(await remote.inner.getById('bad'), isNull);
    });

    test('pruneMissing removes items deleted elsewhere', () async {
      final pruning = OfflineFirstRepository<Note>(
        name: 'notes',
        local: local,
        remote: remote,
        queue: OfflineQueue(db, clock: () => clock),
        idOf: (n) => n.id,
        updatedAtOf: (n) => n.updatedAt,
        toJson: noteToJson,
        fromJson: noteFromJson,
        isOnline: () => true,
        pruneMissing: true,
      );
      await local.save((id: 'gone', text: 'x', updatedAt: t1));
      final report = await pruning.sync();
      expect(report.removed, 1);
      expect(await local.getAll(), isEmpty);
    });
  });

  group('real-time collaboration', () {
    CollabOp op(String key, int counter, String replica, [Object? value]) =>
        CollabOp(key: key, value: value, stamp: CollabStamp(counter, replica));

    test('stamps order by counter, then replica id', () {
      expect(const CollabStamp(2, 'a') > const CollabStamp(1, 'z'), isTrue);
      expect(const CollabStamp(1, 'b') > const CollabStamp(1, 'a'), isTrue);
      final json = op('k', 3, 'r', {'x': 1}).toJson();
      final back = CollabOp.fromJson(json);
      expect(back.key, 'k');
      expect(back.stamp, const CollabStamp(3, 'r'));
      expect(back.value, {'x': 1});
    });

    test('LwwMap gives the same result in any order, any number of times', () {
      final ops = [
        op('title', 1, 'a', 'A'),
        op('title', 1, 'b', 'B'),
        op('count', 1, 'c', 1),
        const CollabOp(key: 'count', stamp: CollabStamp(2, 'a'), deleted: true),
        op('done', 3, 'a', true),
      ];
      final forward = LwwMap();
      ops.forEach(forward.apply);
      final backward = LwwMap();
      for (final o in [...ops.reversed, ...ops]) {
        backward.apply(o);
      }
      expect(forward.values, {'title': 'B', 'done': true});
      expect(backward.values, forward.values);
      expect(forward.apply(op('count', 1, 'z', 99)), isFalse); // tombstone wins
    });

    test('replicas converge despite reordering and duplicates', () async {
      final hub = InMemoryCollabHub();
      final docs = [
        for (final id in ['a', 'b', 'c'])
          CollaborativeDocument(replicaId: id, transport: hub.transport()),
      ];
      for (final d in docs) {
        await d.connect();
      }
      await settle();

      hub.holdMessages = true;
      await docs[0].set('title', 'A');
      await docs[1].set('title', 'B');
      await docs[2].set('count', 1);
      await docs[0].remove('count');
      expect(hub.heldCount, 8);
      hub.deliverHeld(reverse: true, duplicate: true);
      await settle();

      for (final d in docs) {
        expect(d.values, {'title': 'B'}, reason: d.replicaId);
      }
      for (final d in docs) {
        await d.dispose();
      }
    });

    test('late joiners catch up; Lamport clock moves forward', () async {
      final hub = InMemoryCollabHub();
      final a = CollaborativeDocument(
        replicaId: 'a',
        transport: hub.transport(),
      );
      await a.connect();
      await a.set('x', 1);
      await a.set('x', 2);
      await a.set('y', 'hello');

      final b = CollaborativeDocument(
        replicaId: 'b',
        transport: hub.transport(),
      );
      final seen = <Map<String, Object?>>[];
      b.changes.listen(seen.add);
      await b.connect();
      await settle();
      expect(b.values, {'x': 2, 'y': 'hello'});
      expect(seen.last, b.values);

      await b.set('x', 3); // counter must be > 3 to beat a's writes
      await settle();
      expect(a['x'], 3);
      expect(b.exportState().firstWhere((o) => o['key'] == 'x')['counter'], 4);

      await a.dispose();
      await b.dispose();
    });

    test('export/import restores state and keeps deletions', () async {
      final hub = InMemoryCollabHub();
      final a = CollaborativeDocument(
        replicaId: 'a',
        transport: hub.transport(),
      );
      await a.connect();
      await a.set('k', 'v');
      await a.remove('k');
      await a.set('m', 1);
      final saved = jsonDecode(jsonEncode(a.exportState())) as List;

      final restored = CollaborativeDocument(
        replicaId: 'a2',
        transport: hub.transport(),
      )..importState(saved);
      restored.importState([op('k', 1, 'old', 'zombie').toJson()]);
      expect(restored.values, {'m': 1});
      await a.dispose();
      await restored.dispose();
    });
  });
}
