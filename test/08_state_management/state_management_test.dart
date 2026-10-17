import 'dart:async';

import 'package:competition_toolkit/08_state_management/action_controller.dart';
import 'package:competition_toolkit/08_state_management/countdown_controller.dart';
import 'package:competition_toolkit/08_state_management/debouncer.dart';
import 'package:competition_toolkit/08_state_management/pagination_controller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _query = NotifierProvider<_Query, String>(_Query.new);
final _debouncedQuery = NotifierProvider<_DebouncedQuery, String>(
  _DebouncedQuery.new,
);

class _Query extends Notifier<String> {
  @override
  String build() => '';
  void set(String value) => state = value;
}

// The pattern documented in debouncer.dart / the folder README.
class _DebouncedQuery extends Notifier<String> {
  @override
  String build() {
    final query = ref.watch(_query);
    final timer = Timer(const Duration(milliseconds: 300), () => state = query);
    ref.onDispose(timer.cancel);
    return stateOrNull ?? query;
  }
}

void main() {
  test('debounced provider pattern holds the old value until quiet', () {
    fakeAsync((async) {
      final c = ProviderContainer();
      final seen = <String>[];
      c.listen(_debouncedQuery, (_, next) => seen.add(next));
      c.read(_query.notifier).set('a');
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 100));
      c.read(_query.notifier).set('ab');
      async.flushMicrotasks();
      expect(c.read(_debouncedQuery), ''); // not every keystroke
      async.elapse(const Duration(milliseconds: 300));
      expect(c.read(_debouncedQuery), 'ab');
      expect(seen, ['ab']);
      c.dispose();
    });
  });

  group('Debouncer', () {
    test('runs only the last call after the delay', () {
      fakeAsync((async) {
        final debouncer = Debouncer(delay: const Duration(milliseconds: 300));
        final runs = <String>[];
        debouncer.run(() => runs.add('a'));
        async.elapse(const Duration(milliseconds: 200));
        debouncer.run(() => runs.add('ab'));
        async.elapse(const Duration(milliseconds: 299));
        expect(runs, isEmpty);
        expect(debouncer.isPending, isTrue);
        async.elapse(const Duration(milliseconds: 1));
        expect(runs, ['ab']);
        expect(debouncer.isPending, isFalse);
      });
    });

    test('cancel drops and flush runs now', () {
      fakeAsync((async) {
        final debouncer = Debouncer();
        var runs = 0;
        debouncer.run(() => runs++);
        debouncer.cancel();
        async.elapse(const Duration(seconds: 1));
        expect(runs, 0);

        debouncer.run(() => runs++);
        debouncer.flush(() => runs += 10);
        async.elapse(const Duration(seconds: 1));
        expect(runs, 10);
        debouncer.dispose();
      });
    });
  });

  group('ActionController', () {
    final action = NotifierProvider<ActionController, AsyncValue<void>>(
      ActionController.new,
    );

    test('success returns true and ends in data', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final ok = await c.read(action.notifier).run(() async {});
      expect(ok, isTrue);
      expect(c.read(action), isA<AsyncData<void>>());
    });

    test('failure returns false and keeps the error', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final ok = await c
          .read(action.notifier)
          .run(() async => throw StateError('nope'));
      expect(ok, isFalse);
      expect(c.read(action).error, isA<StateError>());
      c.read(action.notifier).reset();
      expect(c.read(action).hasError, isFalse);
    });

    test('a second run while busy is ignored', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final gate = Completer<void>();
      var calls = 0;
      final first = c.read(action.notifier).run(() {
        calls++;
        return gate.future;
      });
      expect(c.read(action).isLoading, isTrue);
      final second = await c.read(action.notifier).run(() async => calls++);
      expect(second, isFalse);
      gate.complete();
      expect(await first, isTrue);
      expect(calls, 1);
    });
  });

  group('PaginationController', () {
    // 25 items in pages of 10, cursor = next start index.
    Future<PageResult<int>> fetch(String? cursor, {bool fail = false}) async {
      if (fail) throw StateError('offline');
      final start = int.parse(cursor ?? '0');
      final end = (start + 10).clamp(0, 25);
      return PageResult([
        for (var i = start; i < end; i++) i,
      ], nextCursor: end < 25 ? '$end' : null);
    }

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('loads pages until there are no more', () async {
      final provider =
          NotifierProvider<PaginationController<int>, PaginatedState<int>>(
            () => PaginationController((ref, cursor) => fetch(cursor)),
          );
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(provider).isLoadingFirstPage, isTrue);
      await settle();
      expect(c.read(provider).items, hasLength(10));

      await c.read(provider.notifier).loadMore();
      await c.read(provider.notifier).loadMore();
      final state = c.read(provider);
      expect(state.items, List.generate(25, (i) => i));
      expect(state.hasMore, isFalse);

      await c.read(provider.notifier).loadMore(); // no-op at the end
      expect(c.read(provider).items, hasLength(25));
    });

    test('an error keeps loaded rows and can be retried', () async {
      var failNext = false;
      final provider =
          NotifierProvider<PaginationController<int>, PaginatedState<int>>(
            () => PaginationController(
              (ref, cursor) => fetch(cursor, fail: failNext),
            ),
          );
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(provider);
      await settle();
      failNext = true;
      await c.read(provider.notifier).loadMore();
      expect(c.read(provider).items, hasLength(10));
      expect(c.read(provider).error, isA<StateError>());

      failNext = false;
      await c.read(provider.notifier).loadMore();
      expect(c.read(provider).items, hasLength(20));
      expect(c.read(provider).error, isNull);
    });

    test('refresh starts again from the first page', () async {
      final provider =
          NotifierProvider<PaginationController<int>, PaginatedState<int>>(
            () => PaginationController((ref, cursor) => fetch(cursor)),
          );
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(provider);
      await settle();
      await c.read(provider.notifier).loadMore();
      expect(c.read(provider).items, hasLength(20));
      await c.read(provider.notifier).refresh();
      expect(c.read(provider).items, hasLength(10));
      expect(c.read(provider).isLoadingFirstPage, isFalse);
    });

    test('copyWith can clear nullable fields', () {
      const state = PaginatedState<int>(cursor: '10', error: 'x');
      final cleared = state.copyWith(cursor: null, error: null);
      expect(cleared.cursor, isNull);
      expect(cleared.error, isNull);
      expect(state.copyWith(hasMore: false).cursor, '10');
    });
  });

  group('CountdownController', () {
    test('counts down from a deadline and finishes once', () {
      fakeAsync((async) {
        var finished = 0;
        final timer = CountdownController(
          duration: const Duration(seconds: 3),
          clock: () => async.getClock(DateTime(2026)).now(),
          onFinished: () => finished++,
        );
        expect(timer.formatted, '0:03');
        timer.start();
        async.elapse(const Duration(milliseconds: 1250));
        expect(timer.formatted, '0:02');
        expect(timer.progress, closeTo(1 / 3, 0.1));
        async.elapse(const Duration(seconds: 2));
        expect(timer.isFinished, isTrue);
        expect(timer.isRunning, isFalse);
        expect(timer.formatted, '0:00');
        async.elapse(const Duration(seconds: 5));
        expect(finished, 1);
        timer.dispose();
      });
    });

    test('pause keeps the remaining time; reset restores it', () {
      fakeAsync((async) {
        final timer = CountdownController(
          duration: const Duration(minutes: 1),
          clock: () => async.getClock(DateTime(2026)).now(),
        );
        timer.start();
        async.elapse(const Duration(seconds: 10));
        timer.pause();
        final left = timer.remaining;
        async.elapse(const Duration(minutes: 5));
        expect(timer.remaining, left);
        expect(timer.isActive, isTrue);

        timer.reset(const Duration(seconds: 30));
        expect(timer.remaining, const Duration(seconds: 30));
        expect(timer.isActive, isFalse);
        timer.dispose();
      });
    });

    test('stays correct when ticks stop (app suspended)', () {
      var now = DateTime(2026);
      final timer = CountdownController(
        duration: const Duration(minutes: 25),
        clock: () => now,
        tick: const Duration(hours: 1), // ticks effectively never fire
      );
      timer.start();
      now = now.add(const Duration(minutes: 5)); // five minutes in another app
      timer.resync();
      expect(timer.remaining, const Duration(minutes: 20));
      timer.dispose();
    });
  });
}
