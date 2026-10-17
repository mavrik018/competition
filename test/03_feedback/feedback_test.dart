import 'dart:async';

import 'package:competition_toolkit/03_feedback/app_snackbars.dart';
import 'package:competition_toolkit/03_feedback/async_value_view.dart';
import 'package:competition_toolkit/03_feedback/offline_banner.dart';
import 'package:competition_toolkit/03_feedback/state_views.dart';
import 'package:competition_toolkit/03_feedback/step_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  group('Snackbars', () {
    testWidgets('success shows the message with an icon', (tester) async {
      await tester.pumpWidget(launcher((c) => c.showSuccess('Saved')));
      await tester.tap(find.text('open'));
      await tester.pump();
      expect(find.text('Saved'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('error offers Retry that runs the callback', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        launcher(
          (c) => c.showError(
            "Couldn't save.",
            error: StateError('boom'),
            onRetry: () => retried++,
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle(); // let the snackbar finish sliding in
      expect(find.text("Couldn't save."), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, 1);
    });

    testWidgets('a new snackbar replaces the current one', (tester) async {
      var count = 0;
      await tester.pumpWidget(
        launcher((c) => c.showInfo('Message ${++count}')),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Message 1'), findsNothing);
      expect(find.text('Message 2'), findsOneWidget);
    });
  });

  group('State views', () {
    testWidgets('EmptyView shows its action only with a callback', (
      tester,
    ) async {
      var created = 0;
      await tester.pumpWidget(
        wrap(
          EmptyView(
            icon: Icons.note,
            title: 'No notes yet',
            message: 'Create your first one.',
            actionLabel: 'New note',
            onAction: () => created++,
          ),
        ),
      );
      await tester.tap(find.text('New note'));
      expect(created, 1);

      await tester.pumpWidget(
        wrap(
          const EmptyView(icon: Icons.note, title: 'Empty', actionLabel: 'New'),
        ),
      );
      expect(find.text('New'), findsNothing);
    });

    testWidgets('ErrorView retries', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        wrap(ErrorView(message: 'Offline', onRetry: () => retried++)),
      );
      expect(find.text('Something went wrong'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retried, 1);
    });

    testWidgets('LoadingView shows its message', (tester) async {
      await tester.pumpWidget(
        wrap(const LoadingView(message: 'Loading notes')),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading notes'), findsOneWidget);
    });
  });

  group('AsyncValueView', () {
    Widget view(AsyncValue<List<int>> value, {VoidCallback? onRetry}) => wrap(
      AsyncValueView<List<int>>(
        value: value,
        onRetry: onRetry,
        isEmpty: (items) => items.isEmpty,
        empty: const Text('nothing'),
        errorMessage: (e) => 'Failed: $e',
        data: (items) => Text('items: ${items.length}'),
      ),
    );

    testWidgets('maps each state', (tester) async {
      await tester.pumpWidget(view(const AsyncLoading()));
      expect(find.byType(LoadingView), findsOneWidget);

      await tester.pumpWidget(view(const AsyncData([1, 2])));
      expect(find.text('items: 2'), findsOneWidget);

      await tester.pumpWidget(view(const AsyncData([])));
      expect(find.text('nothing'), findsOneWidget);

      var retried = 0;
      await tester.pumpWidget(
        view(const AsyncError('x', StackTrace.empty), onRetry: () => retried++),
      );
      expect(find.text('Failed: x'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retried, 1);
    });

    testWidgets('keeps showing data while a refresh is loading', (
      tester,
    ) async {
      var call = 0;
      final completers = <Completer<List<int>>>[];
      final provider = FutureProvider<List<int>>((ref) {
        call++;
        final completer = Completer<List<int>>();
        completers.add(completer);
        return completer.future;
      });

      await tester.pumpWidget(
        ProviderScope(
          child: wrap(
            Consumer(
              builder: (context, ref, _) => AsyncValueView<List<int>>(
                value: ref.watch(provider),
                data: (items) => Text('items: ${items.length}'),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(LoadingView), findsOneWidget);
      completers.last.complete([1]);
      await tester.pump();
      expect(find.text('items: 1'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.text('items: 1')),
      );
      container.invalidate(provider);
      await tester.pump();
      expect(call, 2);
      expect(find.text('items: 1'), findsOneWidget); // not a spinner
      completers.last.complete([1, 2, 3]);
      await tester.pumpAndSettle();
      expect(find.text('items: 3'), findsOneWidget);
    });
  });

  group('OfflineBanner', () {
    testWidgets('is empty while online', (tester) async {
      await tester.pumpWidget(wrap(const OfflineBanner(isOnline: true)));
      expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);
    });

    testWidgets('says how old cached data is', (tester) async {
      final now = DateTime(2026, 10, 14, 12);
      await tester.pumpWidget(
        wrap(
          OfflineBanner(
            isOnline: false,
            syncedAt: now.subtract(const Duration(minutes: 12)),
            now: now,
          ),
        ),
      );
      expect(
        find.text("You're offline. Showing data saved 12m ago."),
        findsOneWidget,
      );
    });
  });

  group('PendingSyncBanner', () {
    testWidgets('hidden at zero, pluralises, and syncs on tap', (tester) async {
      await tester.pumpWidget(
        wrap(
          PendingSyncBanner(
            pendingCount: 0,
            isOnline: true,
            onSyncNow: () async {},
          ),
        ),
      );
      expect(find.byType(Container), findsNothing);

      final gate = Completer<void>();
      var synced = 0;
      await tester.pumpWidget(
        wrap(
          PendingSyncBanner(
            pendingCount: 3,
            isOnline: true,
            onSyncNow: () {
              synced++;
              return gate.future;
            },
          ),
        ),
      );
      expect(find.text('3 changes waiting to sync'), findsOneWidget);
      await tester.tap(find.text('Sync now'));
      await tester.pump();
      expect(synced, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      gate.complete();
      await tester.pump();
      expect(find.text('Sync now'), findsOneWidget);
    });

    testWidgets('a failed sync leaves the banner up', (tester) async {
      await tester.pumpWidget(
        wrap(
          PendingSyncBanner(
            pendingCount: 1,
            isOnline: true,
            onSyncNow: () async => throw StateError('offline'),
          ),
        ),
      );
      expect(find.text('1 change waiting to sync'), findsOneWidget);
      await tester.tap(find.text('Sync now'));
      await tester.pump();
      expect(find.text('Sync now'), findsOneWidget);
    });

    testWidgets('no sync button while offline', (tester) async {
      await tester.pumpWidget(
        wrap(
          PendingSyncBanner(
            pendingCount: 2,
            isOnline: false,
            onSyncNow: () async {},
          ),
        ),
      );
      expect(find.text('Sync now'), findsNothing);
    });
  });

  group('StepProgressView', () {
    const steps = [
      ProgressStep(key: 'upload', label: 'Uploading'),
      ProgressStep(key: 'read', label: 'Reading'),
      ProgressStep(key: 'write', label: 'Writing'),
    ];

    test('currentStepIndex and formatClock', () {
      expect(currentStepIndex(steps, 'read'), 1);
      expect(currentStepIndex(steps, null), 0);
      expect(currentStepIndex(steps, 'unknown'), 0);
      expect(formatClock(const Duration(seconds: 75)), '01:15');
      expect(formatClock(Duration.zero), '00:00');
    });

    testWidgets('ticks off earlier steps and runs a clock', (tester) async {
      await tester.pumpWidget(
        wrap(
          const StepProgressView(
            steps: steps,
            currentKey: 'write',
            expectation: 'About a minute.',
          ),
        ),
      );
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
      expect(find.text('00:00'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('About a minute.'), findsOneWidget);
      // Dispose cancels the periodic clock timer.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows a determinate bar only for the current step', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const StepProgressView(
            steps: steps,
            currentKey: 'upload',
            progress: 0.4,
            progressLabel: '4 MB of 10 MB',
            showClock: false,
          ),
        ),
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('4 MB of 10 MB'), findsOneWidget);
    });
  });
}
