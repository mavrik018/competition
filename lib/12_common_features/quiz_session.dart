/// The state of a multiple-choice quiz in progress — current question,
/// answers, score — as an immutable value that serialises to JSON, so a quiz
/// can be resumed after the app is closed.
///
/// Source: StudyBuddies `study/application/quiz_session_store.dart`
/// (`SavedQuizSession`: everything needed to put the user back on the exact
/// question they left, with timer position) and the scoring in
/// `quiz_taking_screen.dart` / `quiz_results_screen.dart`. Separated from
/// SharedPreferences and the StudyBuddies `Quiz` model; persist
/// `session.toJson()` with `PrefsStore.setJson` or anywhere else.
///
/// ```dart
/// var session = QuizSession(questions: questions);
/// session = session.answer('Paris');     // records answer for current question
/// final correct = session.isCorrect(session.currentIndex);
/// session = session.next();
/// if (session.isComplete) showResults(session.score, session.total);
///
/// await prefs.setJson('quiz_in_progress', session.toJson());
/// final resumed = QuizSession.fromJson(prefs.getJson('quiz_in_progress')!);
/// ```
library;

import 'dart:math';

import 'package:flutter/foundation.dart';

@immutable
class QuizQuestion {
  const QuizQuestion({
    required this.prompt,
    required this.correctAnswer,
    required this.distractors,
    this.explanation,
  });

  final String prompt;
  final String correctAnswer;
  final List<String> distractors;

  /// Shown after answering — "why this is right".
  final String? explanation;

  /// All options in a stable shuffled order for [seed], so the order does
  /// not change on rebuild or after resuming.
  List<String> options({int seed = 0}) {
    // String.hashCode is not guaranteed to be the same in the next run, and
    // a resumed quiz must show the options in the same order — so hash by
    // hand.
    final promptHash = prompt.codeUnits.fold<int>(
      17,
      (hash, unit) => (hash * 31 + unit) & 0x3fffffff,
    );
    return [correctAnswer, ...distractors]..shuffle(Random(seed ^ promptHash));
  }

  Map<String, dynamic> toJson() => {
    'prompt': prompt,
    'correct_answer': correctAnswer,
    'distractors': distractors,
    if (explanation != null) 'explanation': explanation,
  };

  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
    prompt: json['prompt'] as String,
    correctAnswer: json['correct_answer'] as String,
    distractors: (json['distractors'] as List).cast<String>(),
    explanation: json['explanation'] as String?,
  );
}

@immutable
class QuizSession {
  const QuizSession({
    required this.questions,
    this.currentIndex = 0,
    this.answers = const {},
    this.secondsElapsed = 0,
    this.seed = 0,
  });

  final List<QuizQuestion> questions;
  final int currentIndex;

  /// Question index → chosen option.
  final Map<int, String> answers;
  final int secondsElapsed;

  /// Seeds option shuffling; keep it when resuming.
  final int seed;

  int get total => questions.length;
  bool get isComplete => total == 0 || currentIndex >= total;
  QuizQuestion? get current => isComplete ? null : questions[currentIndex];
  bool get currentAnswered => answers.containsKey(currentIndex);
  int get answeredCount => answers.length;

  int get score => [
    for (final entry in answers.entries)
      if (entry.key < total &&
          questions[entry.key].correctAnswer == entry.value)
        1,
  ].length;

  /// 0.0–1.0 through the quiz.
  double get progress =>
      total == 0 ? 1 : (currentIndex / total).clamp(0.0, 1.0);

  /// Whether question [index] was answered correctly (null if unanswered).
  bool? isCorrect(int index) {
    final chosen = answers[index];
    if (chosen == null) return null;
    return questions[index].correctAnswer == chosen;
  }

  List<String> optionsFor(int index) => questions[index].options(seed: seed);

  /// Records [option] for the current question. Re-answering replaces it.
  QuizSession answer(String option) {
    if (isComplete) return this;
    return _copy(answers: {...answers, currentIndex: option});
  }

  QuizSession next() =>
      isComplete ? this : _copy(currentIndex: currentIndex + 1);

  QuizSession previous() =>
      currentIndex == 0 ? this : _copy(currentIndex: currentIndex - 1);

  QuizSession tick([int seconds = 1]) =>
      _copy(secondsElapsed: secondsElapsed + seconds);

  /// Indexes answered wrongly — for a "review your mistakes" list.
  List<int> get mistakes => [
    for (final entry in answers.entries)
      if (entry.key < total &&
          questions[entry.key].correctAnswer != entry.value)
        entry.key,
  ]..sort();

  QuizSession _copy({
    int? currentIndex,
    Map<int, String>? answers,
    int? secondsElapsed,
  }) => QuizSession(
    questions: questions,
    currentIndex: currentIndex ?? this.currentIndex,
    answers: answers ?? this.answers,
    secondsElapsed: secondsElapsed ?? this.secondsElapsed,
    seed: seed,
  );

  Map<String, dynamic> toJson() => {
    'questions': [for (final q in questions) q.toJson()],
    'current_index': currentIndex,
    // JSON keys must be strings.
    'answers': {for (final e in answers.entries) '${e.key}': e.value},
    'seconds_elapsed': secondsElapsed,
    'seed': seed,
  };

  factory QuizSession.fromJson(Map<String, dynamic> json) => QuizSession(
    questions: [
      for (final q in json['questions'] as List)
        QuizQuestion.fromJson(q as Map<String, dynamic>),
    ],
    currentIndex: (json['current_index'] as num?)?.toInt() ?? 0,
    answers: {
      for (final e
          in (json['answers'] as Map<String, dynamic>? ?? const {}).entries)
        int.parse(e.key): e.value as String,
    },
    secondsElapsed: (json['seconds_elapsed'] as num?)?.toInt() ?? 0,
    seed: (json['seed'] as num?)?.toInt() ?? 0,
  );
}
