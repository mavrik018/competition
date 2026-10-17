/// A pausable countdown that stays accurate when the app is backgrounded.
///
/// Source: StudyBuddies `focus_timer_notifier.dart`. Its central idea is kept:
/// the remaining time is derived from a wall-clock *deadline* rather than by
/// subtracting one per tick, because ticks drift and stop entirely while the
/// OS suspends the app. A timer started before a five-minute trip to another
/// app comes back showing the right number. Generalised from the Pomodoro
/// screen to any countdown, and turned into a [ChangeNotifier] so it works
/// with `ListenableBuilder`, Provider or Riverpod alike.
///
/// ```dart
/// final timer = CountdownController(
///   duration: const Duration(minutes: 25),
///   onFinished: () => showDone(),
/// );
///
/// ListenableBuilder(
///   listenable: timer,
///   builder: (_, _) => Text(timer.formatted), // "24:59"
/// );
/// timer.start();
/// ```
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

class CountdownController extends ChangeNotifier {
  CountdownController({
    required Duration duration,
    this.onFinished,
    DateTime Function()? clock,
    this.tick = const Duration(milliseconds: 250),
  }) : _total = duration,
       _remaining = duration,
       _now = clock ?? DateTime.now;

  final VoidCallback? onFinished;

  /// How often the remaining time is recomputed. Shorter than a second so
  /// the display never skips a number.
  final Duration tick;
  final DateTime Function() _now;

  Duration _total;
  Duration _remaining;
  DateTime? _deadline;
  Timer? _ticker;

  Duration get total => _total;
  Duration get remaining => _remaining;
  bool get isRunning => _deadline != null;
  bool get isFinished => _remaining == Duration.zero;

  /// True once started and not reset — worth showing a "timer running"
  /// banner for.
  bool get isActive => isRunning || (_remaining != _total && !isFinished);

  /// 0.0 at the start, 1.0 when finished.
  double get progress => _total.inMilliseconds == 0
      ? 1
      : 1 - _remaining.inMilliseconds / _total.inMilliseconds;

  /// `mm:ss`, rounding up so "0:00" only shows once it has actually ended.
  String get formatted {
    final seconds = (_remaining.inMilliseconds / 1000).ceil();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  void start() {
    if (isRunning || isFinished) return;
    _deadline = _now().add(_remaining);
    _ticker = Timer.periodic(tick, (_) => _update());
    notifyListeners();
  }

  void pause() {
    if (!isRunning) return;
    _update();
    _stopTicking();
    notifyListeners();
  }

  void toggle() => isRunning ? pause() : start();

  /// Back to the full duration, stopped. Optionally with a new [duration].
  void reset([Duration? duration]) {
    _stopTicking();
    if (duration != null) _total = duration;
    _remaining = _total;
    notifyListeners();
  }

  /// Recomputes from the deadline immediately — call it from an
  /// `AppLifecycleListener.onResume` so the display is right on the very
  /// first frame after returning, not up to one [tick] later.
  void resync() {
    if (isRunning) _update();
  }

  void _update() {
    final deadline = _deadline;
    if (deadline == null) return;
    final left = deadline.difference(_now());
    if (left > Duration.zero) {
      _remaining = left;
      notifyListeners();
      return;
    }
    _remaining = Duration.zero;
    _stopTicking();
    notifyListeners();
    onFinished?.call();
  }

  void _stopTicking() {
    _ticker?.cancel();
    _ticker = null;
    _deadline = null;
  }

  @override
  void dispose() {
    _stopTicking();
    super.dispose();
  }
}
