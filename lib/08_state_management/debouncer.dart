/// Runs an action only after calls have stopped for [Debouncer.delay] — for
/// search-as-you-type, autosave, and resize handlers.
///
/// Source: TaskFlow `core/utils/debounce.dart` and the debounced search
/// provider in `search_provider.dart`. Kept as a plain class (no Riverpod),
/// so it works in a `State`, a controller or a notifier.
///
/// ```dart
/// final _debouncer = Debouncer(delay: const Duration(milliseconds: 300));
///
/// TextField(onChanged: (q) => _debouncer.run(() => ref.read(searchProvider.notifier).search(q)));
///
/// @override
/// void dispose() {
///   _debouncer.dispose();
///   super.dispose();
/// }
/// ```
///
/// The Riverpod version, when the raw query already lives in a provider.
/// TaskFlow's original returned the raw query from `build()`, so every
/// keystroke went straight through and nothing was debounced; returning the
/// previous value is what makes the delay real:
///
/// ```dart
/// class DebouncedQuery extends Notifier<String> {
///   @override
///   String build() {
///     final query = ref.watch(queryProvider);
///     final timer = Timer(const Duration(milliseconds: 300), () => state = query);
///     ref.onDispose(timer.cancel);
///     return stateOrNull ?? query; // keep the old value until the timer fires
///   }
/// }
/// ```
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

class Debouncer {
  Debouncer({this.delay = const Duration(milliseconds: 300)});

  final Duration delay;
  Timer? _timer;

  /// Schedules [action], cancelling any action still waiting.
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Whether an action is waiting to run.
  bool get isPending => _timer?.isActive ?? false;

  /// Drops the waiting action without running it.
  void cancel() => _timer?.cancel();

  /// Runs the waiting action now (e.g. save on leaving a screen).
  void flush(VoidCallback action) {
    if (!isPending) return;
    _timer?.cancel();
    action();
  }

  void dispose() => _timer?.cancel();
}
