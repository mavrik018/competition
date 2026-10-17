import 'package:competition_toolkit/12_common_features/permission_helper.dart';
import 'package:competition_toolkit/12_common_features/pomodoro_controller.dart';
import 'package:competition_toolkit/12_common_features/quiz_session.dart';
import 'package:competition_toolkit/12_common_features/reminder_scheduler.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  test('outcomeFor maps every platform status', () {
    expect(outcomeFor(PermissionStatus.granted), PermissionOutcome.granted);
    expect(outcomeFor(PermissionStatus.limited), PermissionOutcome.granted);
    expect(outcomeFor(PermissionStatus.provisional), PermissionOutcome.granted);
    expect(outcomeFor(PermissionStatus.denied), PermissionOutcome.denied);
    expect(
      outcomeFor(PermissionStatus.permanentlyDenied),
      PermissionOutcome.blocked,
    );
    expect(outcomeFor(PermissionStatus.restricted), PermissionOutcome.blocked);
  });

  group('Reminder ids and times', () {
    test('notificationIdFor is stable, 31-bit and spreads keys', () {
      // Fixed FNV-1a value: must never change between releases, or
      // reminders scheduled by an older build could not be cancelled.
      expect(notificationIdFor('task-1'), notificationIdFor('task-1'));
      expect(notificationIdFor(''), 0x811c9dc5 & 0x7fffffff);
      final ids = {for (var i = 0; i < 2000; i++) notificationIdFor('id-$i')};
      expect(ids.length, greaterThan(1995));
      expect(ids.every((id) => id >= 0 && id <= 0x7fffffff), isTrue);
    });

    test('toZoned keeps the wall-clock time in the target zone', () {
      tz_data.initializeTimeZones();
      final london = tz.getLocation('Europe/London');
      final summer = toZoned(DateTime(2026, 7, 1, 9, 30), london);
      final winter = toZoned(DateTime(2026, 12, 1, 9, 30), london);
      expect([summer.hour, summer.minute], [9, 30]);
      expect([winter.hour, winter.minute], [9, 30]);
      expect(summer.timeZoneOffset, const Duration(hours: 1)); // BST
      expect(winter.timeZoneOffset, Duration.zero);
    });
  });

  group('PomodoroController', () {
    test('focus → short break → … → long break, counting focus only', () {
      fakeAsync((async) {
        final completed = <FocusPhase>[];
        final pomodoro = PomodoroController(
          focusMinutes: 1,
          shortBreakMinutes: 1,
          longBreakMinutes: 2,
          roundsBeforeLongBreak: 2,
          autoStartNext: true,
          clock: () => async.getClock(DateTime(2026)).now(),
          onPhaseComplete: (phase, _) => completed.add(phase),
        );
        pomodoro.start();
        async.elapse(const Duration(minutes: 1, seconds: 1));
        expect(pomodoro.phase, FocusPhase.shortBreak);
        expect(pomodoro.completedFocusRounds, 1);
        async.elapse(const Duration(minutes: 1, seconds: 1));
        expect(pomodoro.phase, FocusPhase.focus);
        async.elapse(const Duration(minutes: 1, seconds: 1));
        expect(pomodoro.phase, FocusPhase.longBreak);
        expect(completed, [
          FocusPhase.focus,
          FocusPhase.shortBreak,
          FocusPhase.focus,
        ]);
        pomodoro.dispose();
      });
    });

    test('focus length changes are ignored while running', () {
      fakeAsync((async) {
        final pomodoro = PomodoroController(
          clock: () => async.getClock(DateTime(2026)).now(),
        );
        pomodoro.setFocusMinutes(50);
        expect(pomodoro.timer.total, const Duration(minutes: 50));
        pomodoro.start();
        pomodoro.setFocusMinutes(10);
        expect(pomodoro.focusMinutes, 50);
        pomodoro.pause();
        pomodoro.skip();
        expect(pomodoro.phase, FocusPhase.shortBreak);
        expect(pomodoro.completedFocusRounds, 0); // skipping does not count
        pomodoro.dispose();
      });
    });

    test('without auto-start the next phase waits', () {
      fakeAsync((async) {
        final pomodoro = PomodoroController(
          focusMinutes: 1,
          clock: () => async.getClock(DateTime(2026)).now(),
        );
        var notifications = 0;
        pomodoro.addListener(() => notifications++);
        pomodoro.start();
        async.elapse(const Duration(minutes: 2));
        expect(pomodoro.phase, FocusPhase.shortBreak);
        expect(pomodoro.timer.isRunning, isFalse);
        expect(notifications, greaterThan(0));
        pomodoro.dispose();
      });
    });
  });

  group('QuizSession', () {
    const questions = [
      QuizQuestion(
        prompt: 'Capital of France?',
        correctAnswer: 'Paris',
        distractors: ['Lyon', 'Nice'],
      ),
      QuizQuestion(
        prompt: '2 + 2?',
        correctAnswer: '4',
        distractors: ['3', '5'],
        explanation: 'Basic sums.',
      ),
    ];

    test('answers, scores and finishes', () {
      var session = const QuizSession(questions: questions);
      expect(session.current!.prompt, 'Capital of France?');
      session = session.answer('Lyon').answer('Paris'); // re-answer replaces
      expect(session.isCorrect(0), isTrue);
      session = session.next().answer('5');
      expect(session.isCorrect(1), isFalse);
      expect(session.isCorrect(5), isNull);
      session = session.next();
      expect(session.isComplete, isTrue);
      expect(session.current, isNull);
      expect(session.score, 1);
      expect(session.mistakes, [1]);
      expect(session.progress, 1);
      expect(session.answer('x'), same(session));
      expect(session.next(), same(session));
    });

    test('options are shuffled stably and include the answer', () {
      final a = questions.first.options(seed: 3);
      final b = questions.first.options(seed: 3);
      expect(a, b);
      expect(a.toSet(), {'Paris', 'Lyon', 'Nice'});
    });

    test('JSON round-trip resumes on the same question and options', () {
      final session = const QuizSession(
        questions: questions,
        seed: 7,
      ).answer('Paris').next().tick(42);
      final resumed = QuizSession.fromJson(session.toJson());
      expect(resumed.currentIndex, 1);
      expect(resumed.answers, {0: 'Paris'});
      expect(resumed.secondsElapsed, 42);
      expect(resumed.optionsFor(1), session.optionsFor(1));
      expect(resumed.questions[1].explanation, 'Basic sums.');
    });

    test('an empty quiz is complete', () {
      const empty = QuizSession(questions: []);
      expect(empty.isComplete, isTrue);
      expect(empty.score, 0);
    });
  });
}
