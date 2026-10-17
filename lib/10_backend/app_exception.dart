/// Turns any failure into one type with a sentence a user can read.
///
/// Source: Cookly `core/error/app_exception.dart` (the most complete of four
/// mappers), with StudyBuddies `friendlyErrorMessage` ("couldn't `<action>`"
/// wording) and TaskFlow `ErrorMapper` (connection keyword matching).
/// Cookly's cooking-themed copy was replaced with neutral wording, and
/// `dart:io` is no longer imported, so this also works on the web.
///
/// Changed for the toolkit: this file has **no package dependencies**, so
/// any app can copy it. Backend-specific wording lives next to the backend
/// and plugs in as a translator: `supabase_errors.dart` handles Postgres
/// codes, PostgREST, Storage, Edge Function `reason`s and auth messages, and
/// `initializeSupabase()` registers it. Without a translator, unknown error
/// types get the generic message.
///
/// Call it once, at the repository boundary or in the UI:
///
/// ```dart
/// try {
///   await repo.save(note);
/// } catch (e, st) {
///   final failure = AppException.from(e);
///   context.showError(failure.message, error: e, stackTrace: st);
///   if (failure.isAuth) goToSignIn();
/// }
/// ```
library;

import 'dart:async';

/// Maps one backend's errors; returns null for errors it does not know.
typedef AppErrorTranslator = AppException? Function(Object error);

enum AppErrorKind {
  /// Credentials, session or sign-up problems.
  auth,

  /// No connection, DNS failure, timeout.
  offline,

  /// Row-level security or a missing permission.
  permission,

  /// The input was refused (duplicate, constraint, too large).
  validation,

  /// Shared capacity limit; clears by itself shortly.
  rateLimited,

  /// The user's own allowance is spent — "come back later or upgrade".
  quotaExceeded,
  server,
  unknown,
}

class AppException implements Exception {
  const AppException(
    this.message, {
    this.kind = AppErrorKind.unknown,
    this.cause,
  });

  /// Safe to show as-is.
  final String message;
  final AppErrorKind kind;

  /// The original error, for logs only.
  final Object? cause;

  bool get isOffline => kind == AppErrorKind.offline;
  bool get isAuth => kind == AppErrorKind.auth;
  bool get isQuotaExceeded => kind == AppErrorKind.quotaExceeded;

  /// Whether retrying the same request could plausibly succeed.
  bool get isRetryable =>
      kind == AppErrorKind.offline ||
      kind == AppErrorKind.rateLimited ||
      kind == AppErrorKind.server ||
      kind == AppErrorKind.unknown;

  static final List<AppErrorTranslator> _translators = [];

  /// Adds a backend's translator, tried before the generic rules. Adding the
  /// same function twice has no effect.
  static void registerTranslator(AppErrorTranslator translator) {
    if (!_translators.contains(translator)) _translators.add(translator);
  }

  /// Removes a translator (for tests).
  static void unregisterTranslator(AppErrorTranslator translator) =>
      _translators.remove(translator);

  static AppException from(Object error) {
    if (error is AppException) return error;
    for (final translate in _translators) {
      final mapped = translate(error);
      if (mapped != null) return mapped;
    }
    return generic(error);
  }

  /// The rules every backend shares: timeouts and connection failures are
  /// "offline", everything else is "something went wrong".
  static AppException generic(Object error) {
    if (error is AppException) return error;
    if (error is TimeoutException) {
      return AppException(
        'That took too long. Please try again.',
        kind: AppErrorKind.offline,
        cause: error,
      );
    }
    if (looksLikeConnectionError(error)) {
      return AppException(
        offlineMessage,
        kind: AppErrorKind.offline,
        cause: error,
      );
    }
    return AppException(
      'Something went wrong. Please try again.',
      cause: error,
    );
  }

  static const offlineMessage =
      "Can't reach the server. Check your connection and try again.";

  /// True for socket / DNS / HTTP client failures, recognised by text so this
  /// file needs no `dart:io` (which would break web builds).
  static bool looksLikeConnectionError(Object error) {
    final text = '${error.runtimeType} $error'.toLowerCase();
    return const [
      'socketexception',
      'clientexception',
      'httpexception',
      'failed host lookup',
      'connection refused',
      'connection reset',
      'connection closed',
      'network is unreachable',
      'xmlhttprequest error',
    ].any(text.contains);
  }

  @override
  String toString() => 'AppException(${kind.name}): $message';
}
