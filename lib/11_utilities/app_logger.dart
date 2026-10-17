/// One logging entry point with levels and tags, routed through
/// `dart:developer` so entries show in DevTools with severity and errors.
///
/// Source: Couple `core/utils/logger.dart`. Its rule is kept and worth
/// repeating: log that something happened, never the user's content (note
/// text, messages, transcripts, tokens). Debug entries are dropped in release
/// builds; everything else is kept for crash-report breadcrumbs. The
/// app-config dependency was replaced by Flutter's `kReleaseMode`.
///
/// ```dart
/// AppLogger.info('Note saved', tag: 'notes');
/// AppLogger.error('Sync failed', tag: 'sync', error: e, stackTrace: st);
/// ```
library;

import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

enum LogLevel {
  debug(500),
  info(800),
  warning(900),
  error(1000);

  const LogLevel(this.severity);

  /// `dart:developer` / `package:logging` severity values.
  final int severity;
}

abstract final class AppLogger {
  /// Defaults to [kReleaseMode]; tests can flip it.
  static bool suppressDebug = kReleaseMode;

  /// Optional extra destination (e.g. a crash reporter's breadcrumbs).
  static void Function(LogLevel level, String message, String tag)? sink;

  static void debug(String message, {String tag = 'app'}) =>
      log(LogLevel.debug, message, tag: tag);

  static void info(String message, {String tag = 'app'}) =>
      log(LogLevel.info, message, tag: tag);

  static void warning(String message, {String tag = 'app'}) =>
      log(LogLevel.warning, message, tag: tag);

  static void error(
    String message, {
    String tag = 'app',
    Object? error,
    StackTrace? stackTrace,
  }) => log(
    LogLevel.error,
    message,
    tag: tag,
    error: error,
    stackTrace: stackTrace,
  );

  static void log(
    LogLevel level,
    String message, {
    String tag = 'app',
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level == LogLevel.debug && suppressDebug) return;
    developer.log(
      message,
      name: tag,
      level: level.severity,
      error: error,
      stackTrace: stackTrace,
    );
    sink?.call(level, message, tag);
  }
}
