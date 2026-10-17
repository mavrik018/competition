/// A Pomodoro / focus timer: focus blocks alternating with short breaks and
/// a longer break every few rounds, built on `CountdownController`.
///
/// Source: StudyBuddies `progress/application/focus_timer_notifier.dart` +
/// `focus_screen.dart`. Kept: wall-clock accuracy across app suspension (via
/// `CountdownController`), focus length changes ignored mid-run so the
/// countdown cannot jump under the user, only completed *focus* blocks
/// count as study time, and completion reported through a callback rather
/// than a dialog shown from state code. Added: long breaks and optional
/// auto-start of the next phase.
///
/// ```dart
/// final pomodoro = PomodoroController(
///   onPhaseComplete: (phase, minutes) {
///     if (phase == FocusPhase.focus) progressRepo.logSession(minutes);
///   },
/// );
/// ListenableBuilder(listenable: pomodoro, builder: (_, _) =>
///   RadialGauge(value: pomodoro.timer.progress, size: 220,
///       child: Text(pomodoro.timer.formatted)));
/// ```
library;

import 'package:flutter/foundation.dart';

import '../08_state_management/countdown_controller.dart';

enum FocusPhase { focus, shortBreak, longBreak }

class PomodoroController extends ChangeNotifier {
  PomodoroController({
    int focusMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.roundsBeforeLongBreak = 4,
    this.autoStartNext = false,
    this.onPhaseComplete,
    DateTime Function()? clock,
  }) : _focusMinutes = focusMinutes,
       _clock = clock {
    _timer = _newTimer();
  }

  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int roundsBeforeLongBreak;
  final bool autoStartNext;

  /// Called when a phase runs to zero, with its length in minutes.
  final void Function(FocusPhase phase, int minutes)? onPhaseComplete;
  final DateTime Function()? _clock;

  int _focusMinutes;
  FocusPhase _phase = FocusPhase.focus;
  int _completedFocusRounds = 0;
  late CountdownController _timer;

  FocusPhase get phase => _phase;
  int get focusMinutes => _focusMinutes;
  int get completedFocusRounds => _completedFocusRounds;

  /// The running countdown — read `formatted`, `progress`, `isRunning`.
  CountdownController get timer => _timer;

  int minutesFor(FocusPhase phase) => switch (phase) {
    FocusPhase.focus => _focusMinutes,
    FocusPhase.shortBreak => shortBreakMinutes,
    FocusPhase.longBreak => longBreakMinutes,
  };

  void start() => _timer.start();
  void pause() => _timer.pause();
  void toggle() => _timer.toggle();

  /// Back to the start of the current phase.
  void reset() => _timer.reset();

  /// Ignored while running, so the countdown never jumps mid-session. A
  /// break in progress keeps its length; the new value applies to focus.
  void setFocusMinutes(int minutes) {
    if (_timer.isRunning || minutes <= 0) return;
    _focusMinutes = minutes;
    if (_phase == FocusPhase.focus) _timer.reset(Duration(minutes: minutes));
    notifyListeners();
  }

  /// Jumps to [phase] (stopped, full length).
  void switchTo(FocusPhase phase) {
    _phase = phase;
    _replaceTimer();
  }

  /// Ends the current phase early without counting it.
  void skip() => switchTo(_nextPhase());

  FocusPhase _nextPhase() {
    if (_phase != FocusPhase.focus) return FocusPhase.focus;
    // Called after the focus round was counted.
    return _completedFocusRounds > 0 &&
            _completedFocusRounds % roundsBeforeLongBreak == 0
        ? FocusPhase.longBreak
        : FocusPhase.shortBreak;
  }

  void _onFinished() {
    final finished = _phase;
    if (finished == FocusPhase.focus) _completedFocusRounds++;
    onPhaseComplete?.call(finished, minutesFor(finished));
    _phase = _nextPhase();
    _replaceTimer();
    if (autoStartNext) _timer.start();
  }

  CountdownController _newTimer() => CountdownController(
    duration: Duration(minutes: minutesFor(_phase)),
    onFinished: _onFinished,
    clock: _clock,
  )..addListener(notifyListeners);

  void _replaceTimer() {
    _timer
      ..removeListener(notifyListeners)
      ..dispose();
    _timer = _newTimer();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer
      ..removeListener(notifyListeners)
      ..dispose();
    super.dispose();
  }
}
