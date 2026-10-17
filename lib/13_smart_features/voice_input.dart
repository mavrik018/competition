/// Voice input: speech-to-text behind a small interface (device engine +
/// a fake for tests and demos), a rule-based command parser ("remind me to
/// call mum tomorrow at 5pm" → intent + slots + time), and a mic button.
///
/// **Two parts, two natures.**
/// * Turning audio into words uses the platform's speech recogniser via
///   `speech_to_text` (Google on Android, Apple on iOS). That *is* machine
///   learning, but it runs in the OS — you send no data yourself and need
///   no API key. Some devices recognise offline, many need the network.
/// * Understanding the words ([VoiceCommandParser], [parseNaturalTime]) is
///   **rule-based**: patterns you write, matched in order. Predictable and
///   offline, but it only understands phrasings you anticipated — keep a
///   fallback (e.g. treat unmatched text as a search or a new item title).
///
/// Suits: hands-busy apps (cooking, workshop, driving-adjacent, fitness),
/// accessibility, quick capture of tasks/expenses/notes, search.
///
/// ```dart
/// const parser = VoiceCommandParser([
///   VoiceIntent('add_task', ['remind me to {title}', 'add {title}']),
///   VoiceIntent('timer', ['set a timer for {minutes} minutes', 'timer {minutes} minutes']),
///   VoiceIntent('search', ['search for {query}', 'find {query}']),
/// ]);
///
/// VoiceInputButton(
///   speech: ref.read(speechInputProvider),
///   onResult: (text) {
///     final command = parser.parse(text, now: DateTime.now());
///     if (command?.intent == 'add_task') addTask(command!.slots['title']!, due: command.at);
///   },
/// );
/// ```
///
/// **Platform setup** (device engine only): Android — `RECORD_AUDIO`
/// permission and a `<queries>` entry for `android.speech.RecognitionService`;
/// iOS — `NSMicrophoneUsageDescription` and
/// `NSSpeechRecognitionUsageDescription` in Info.plist. See the README.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../03_feedback/app_snackbars.dart';

// ── Speech engine seam ──────────────────────────────────────────────────────

typedef SpeechResultCallback = void Function(String words, bool isFinal);

abstract interface class SpeechInput {
  /// Prepares the recogniser (and asks for microphone permission the first
  /// time). False when speech is unavailable or permission was denied.
  Future<bool> initialize();

  bool get isListening;

  /// Streams partial results, then one with `isFinal: true`.
  Future<void> listen({
    required SpeechResultCallback onResult,
    String? localeId,
    Duration listenFor = const Duration(seconds: 30),
  });

  Future<void> stop();
}

/// The real recogniser via `speech_to_text`. Device-only: not exercised by
/// unit tests (there is no microphone in `flutter test`).
class DeviceSpeechInput implements SpeechInput {
  DeviceSpeechInput([SpeechToText? speech])
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  Future<bool>? _ready;

  @override
  Future<bool> initialize() => _ready ??= _speech.initialize(
    onError: (error) => debugPrint('Speech error: ${error.errorMsg}'),
  );

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<void> listen({
    required SpeechResultCallback onResult,
    String? localeId,
    Duration listenFor = const Duration(seconds: 30),
  }) async {
    if (!await initialize()) {
      throw StateError('Speech recognition is not available');
    }
    await _speech.listen(
      onResult: (r) => onResult(r.recognizedWords, r.finalResult),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenFor: listenFor,
        pauseFor: const Duration(seconds: 3),
        localeId: localeId,
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();
}

/// A test/demo double that "hears" scripted [phrases], one per [listen],
/// word by word every [step]. **Not production functionality** — no
/// microphone or recogniser is used.
class FakeSpeechInput implements SpeechInput {
  FakeSpeechInput(
    this.phrases, {
    this.available = true,
    this.step = const Duration(milliseconds: 60),
  });

  final List<String> phrases;
  final bool available;
  final Duration step;
  int _next = 0;
  bool _listening = false;
  int _session = 0;

  @override
  Future<bool> initialize() async => available;

  @override
  bool get isListening => _listening;

  @override
  Future<void> listen({
    required SpeechResultCallback onResult,
    String? localeId,
    Duration listenFor = const Duration(seconds: 30),
  }) async {
    if (!available) throw StateError('Speech recognition is not available');
    if (phrases.isEmpty) return;
    final phrase = phrases[_next++ % phrases.length];
    final session = ++_session;
    _listening = true;
    final words = phrase.split(' ');
    for (var i = 1; i <= words.length; i++) {
      await Future<void>.delayed(step);
      if (session != _session || !_listening) return; // stopped
      final isFinal = i == words.length;
      if (isFinal) _listening = false;
      onResult(words.take(i).join(' '), isFinal);
    }
  }

  @override
  Future<void> stop() async {
    _listening = false;
    _session++;
  }
}

final speechInputProvider = Provider<SpeechInput>((ref) => DeviceSpeechInput());

// ── Rule-based understanding ────────────────────────────────────────────────

/// One thing the user can say, with phrasings like `'remind me to {title}'`.
/// `{name}` captures words into a slot; everything else must match
/// (case-insensitive, ignoring end punctuation).
class VoiceIntent {
  const VoiceIntent(this.name, this.patterns);

  final String name;
  final List<String> patterns;
}

class VoiceCommand {
  const VoiceCommand({
    required this.intent,
    required this.slots,
    required this.text,
    this.at,
    this.hasTime = false,
  });

  final String intent;
  final Map<String, String> slots;

  /// The words that were matched (with the time phrase removed).
  final String text;

  /// When, if the user said a time or day ("tomorrow at 5pm").
  final DateTime? at;

  /// False when only a day was said — [at] is then 09:00 that day.
  final bool hasTime;
}

class VoiceCommandParser {
  const VoiceCommandParser(this.intents);

  /// Tried in order — put specific phrasings before catch-alls.
  final List<VoiceIntent> intents;

  /// The first intent whose pattern matches, or null (keep a fallback).
  VoiceCommand? parse(String spoken, {required DateTime now}) {
    final time = parseNaturalTime(_clean(spoken), now: now);
    for (final intent in intents) {
      for (final pattern in intent.patterns) {
        final match = _toRegExp(pattern).firstMatch(time.rest);
        if (match == null) continue;
        return VoiceCommand(
          intent: intent.name,
          slots: {
            for (final name in match.groupNames)
              name: match.namedGroup(name)!.trim(),
          },
          text: time.rest,
          at: time.at,
          hasTime: time.hasTime,
        );
      }
    }
    return null;
  }

  static String _clean(String text) =>
      text.trim().replaceAll(RegExp(r'[.!?,]+$'), '');

  static RegExp _toRegExp(String pattern) {
    final source = pattern.splitMapJoin(
      RegExp(r'\{(\w+)\}'),
      onMatch: (m) => '(?<${m[1]}>.+?)',
      onNonMatch: (text) => RegExp.escape(text).replaceAll(' ', r'\s+'),
    );
    return RegExp('^$source\$', caseSensitive: false);
  }
}

const _numberWords = {
  'a': 1, 'an': 1, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, //
  'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'fifteen': 15,
  'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50,
};
const _weekdays = [
  'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', //
  'sunday',
];

/// Finds a time phrase in [text] and returns when it means plus the text
/// without it. Understands: "in 20 minutes", "in an hour", "in half an
/// hour", "in 3 days", "today", "tonight", "tomorrow", "the day after
/// tomorrow", "(on|next) friday", "at 5", "at 5pm", "5:30 pm", "at 17:30",
/// "noon", "midnight", "in the morning/afternoon/evening".
///
/// Rules: a bare "at 1"…"at 7" means PM; a time with no day that has
/// already passed today means tomorrow; a day with no time is 09:00 with
/// `hasTime: false`. English only.
({DateTime? at, bool hasTime, String rest}) parseNaturalTime(
  String text, {
  required DateTime now,
}) {
  var rest = text;
  RegExpMatch? cut(String pattern) {
    final match = RegExp(pattern, caseSensitive: false).firstMatch(rest);
    if (match != null) rest = rest.replaceRange(match.start, match.end, ' ');
    return match;
  }

  String tidy(String s) => s
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'\s+(at|on|by|for)$', caseSensitive: false), '')
      .trim();

  // 1. Relative offsets win over everything else.
  if (cut(r'\bin half an? hour\b') != null) {
    return (
      at: now.add(const Duration(minutes: 30)),
      hasTime: true,
      rest: tidy(rest),
    );
  }
  final relative = cut(r'\bin (\d+|[a-z]+) (minute|min|hour|hr|day|week)s?\b');
  if (relative != null) {
    final amount =
        int.tryParse(relative[1]!) ?? _numberWords[relative[1]!.toLowerCase()];
    if (amount != null) {
      final unit = relative[2]!.toLowerCase();
      final offset = switch (unit) {
        'minute' || 'min' => Duration(minutes: amount),
        'hour' || 'hr' => Duration(hours: amount),
        'day' => Duration(days: amount),
        _ => Duration(days: 7 * amount),
      };
      return (
        at: now.add(offset),
        hasTime: unit != 'day' && unit != 'week',
        rest: tidy(rest),
      );
    }
    rest = text; // "in the morning" etc. — not an offset, undo the cut
  }

  // 2. The day.
  final today = DateTime(now.year, now.month, now.day);
  DateTime? day;
  int? defaultHour;
  if (cut(r'\b(the )?day after tomorrow\b') != null) {
    day = today.add(const Duration(days: 2));
  } else if (cut(r'\btomorrow\b') != null) {
    day = today.add(const Duration(days: 1));
  } else if (cut(r'\btonight\b') != null) {
    day = today;
    defaultHour = 20;
  } else if (cut(r'\btoday\b') != null) {
    day = today;
  } else if (cut('\\b(next |on |this )?(${_weekdays.join('|')})\\b')
      case final m?) {
    final target = _weekdays.indexOf(m[2]!.toLowerCase()) + 1;
    var ahead = (target - now.weekday) % 7;
    if (ahead == 0 && (m[1]?.trim().toLowerCase() == 'next')) ahead = 7;
    day = today.add(Duration(days: ahead));
  }

  // 3. The time.
  int? hour;
  var minute = 0;
  if (cut(r'\b(at )?noon\b') != null) {
    hour = 12;
  } else if (cut(r'\b(at )?midnight\b') != null) {
    hour = 0;
  } else if (cut(r'\b(at )?(\d{1,2})(?::(\d{2}))? ?([ap])\.?m\.?(?=\s|$)')
      case final m?) {
    hour = int.parse(m[2]!) % 12 + (m[4]!.toLowerCase() == 'p' ? 12 : 0);
    minute = int.tryParse(m[3] ?? '') ?? 0;
  } else if (cut(r'\bat (\d{1,2})(?::(\d{2}))?\b') case final m?) {
    hour = int.parse(m[1]!);
    minute = int.tryParse(m[2] ?? '') ?? 0;
    if (hour >= 1 && hour <= 7 && m[2] == null) hour += 12;
  }
  if (cut(r'\b(in the |this )?(morning|afternoon|evening)\b') case final m?) {
    defaultHour = switch (m[2]!.toLowerCase()) {
      'morning' => 9,
      'afternoon' => 14,
      _ => 18,
    };
  }
  if (hour != null && (hour > 23 || minute > 59)) hour = null;

  if (day == null && hour == null && defaultHour == null) {
    return (at: null, hasTime: false, rest: tidy(text));
  }
  final base = day ?? today;
  var at = DateTime(
    base.year,
    base.month,
    base.day,
    hour ?? defaultHour ?? 9,
    hour == null ? 0 : minute,
  );
  if (day == null && at.isBefore(now)) at = at.add(const Duration(days: 1));
  return (
    at: at,
    hasTime: hour != null || defaultHour != null,
    rest: tidy(rest),
  );
}

// ── Mic button ──────────────────────────────────────────────────────────────

/// Tap to listen, tap again to stop. Shows partial words via [onPartial]
/// and delivers the final text to [onResult]. When speech is unavailable
/// it shows a snackbar instead (keep a keyboard path for those users).
class VoiceInputButton extends StatefulWidget {
  const VoiceInputButton({
    super.key,
    required this.speech,
    required this.onResult,
    this.onPartial,
    this.localeId,
  });

  final SpeechInput speech;
  final ValueChanged<String> onResult;
  final ValueChanged<String>? onPartial;
  final String? localeId;

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton> {
  bool _listening = false;

  Future<void> _toggle() async {
    if (_listening) {
      await widget.speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (!await widget.speech.initialize()) {
      if (mounted) {
        context.showError(
          'Voice input is not available. Check the microphone permission.',
        );
      }
      return;
    }
    setState(() => _listening = true);
    try {
      await widget.speech.listen(
        localeId: widget.localeId,
        onResult: (words, isFinal) {
          if (!mounted) return;
          if (isFinal) {
            setState(() => _listening = false);
            if (words.trim().isNotEmpty) widget.onResult(words.trim());
          } else {
            widget.onPartial?.call(words);
          }
        },
      );
    } catch (e) {
      if (mounted) setState(() => _listening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: _listening ? 'Stop voice input' : 'Start voice input',
      isSelected: _listening,
      style: _listening
          ? IconButton.styleFrom(
              backgroundColor: scheme.errorContainer,
              foregroundColor: scheme.onErrorContainer,
            )
          : null,
      icon: const Icon(Icons.mic_none),
      selectedIcon: const Icon(Icons.mic),
      onPressed: _toggle,
    );
  }
}
