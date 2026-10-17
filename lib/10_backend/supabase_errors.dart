/// Supabase errors → [AppException] with wording users can act on.
///
/// Source: Cookly `core/error/app_exception.dart` (Postgres codes, PostgREST,
/// Edge Function `reason`s, the gotrue retryable-fetch case) and StudyBuddies
/// `friendlyErrorMessage` (storage size errors). Split out of
/// `app_exception.dart` so that file needs no packages; this one is the only
/// place that knows Supabase's error types.
///
/// `initializeSupabase()` registers [translateSupabaseError], so
/// `AppException.from(e)` maps Supabase errors anywhere in the app.
/// `SupabaseRepository` and `AuthService` call [supabaseFailure] directly.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exception.dart';

/// [error] as an [AppException], using the Supabase rules first and the
/// generic ones otherwise.
AppException supabaseFailure(Object error) =>
    translateSupabaseError(error) ?? AppException.generic(error);

/// The Supabase mapping, or null when [error] is not a Supabase error.
AppException? translateSupabaseError(Object error) {
  // Checked before AuthException (it is a subtype): the request never
  // reached the server, and its message is a raw socket string.
  if (error is AuthRetryableFetchException) {
    return AppException(
      AppException.offlineMessage,
      kind: AppErrorKind.offline,
      cause: error,
    );
  }
  if (error is AuthException) {
    return AppException(
      supabaseAuthMessage(error.message),
      kind: AppErrorKind.auth,
      cause: error,
    );
  }
  if (error is PostgrestException) return _fromPostgrest(error);
  if (error is StorageException) return _fromStorage(error);
  if (error is FunctionException) return _fromFunction(error);
  return null;
}

AppException _fromPostgrest(PostgrestException error) {
  // https://www.postgresql.org/docs/current/errcodes-appendix.html
  final (message, kind) = switch (error.code) {
    '23505' => ('That already exists.', AppErrorKind.validation),
    '23503' => (
      'Something this depends on no longer exists.',
      AppErrorKind.validation,
    ),
    '23514' => ("That value isn't allowed.", AppErrorKind.validation),
    '23502' => ("Something required is missing.", AppErrorKind.validation),
    '42501' => ("You don't have access to that.", AppErrorKind.permission),
    // PostgREST: .single() matched zero or several rows — usually the row
    // was deleted elsewhere moments ago.
    'PGRST116' => ("That's no longer there.", AppErrorKind.validation),
    'PGRST301' || 'PGRST303' => (
      'Your session has expired. Please sign in again.',
      AppErrorKind.auth,
    ),
    _ => (
      'Something went wrong saving that. Please try again.',
      AppErrorKind.server,
    ),
  };
  return AppException(message, kind: kind, cause: error);
}

AppException _fromStorage(StorageException error) {
  final text = error.message.toLowerCase();
  if (text.contains('exceeded') ||
      text.contains('too large') ||
      error.statusCode == '413') {
    return AppException(
      'That file is too large to upload.',
      kind: AppErrorKind.validation,
      cause: error,
    );
  }
  if (error.statusCode == '403') {
    return AppException(
      "You don't have access to that file.",
      kind: AppErrorKind.permission,
      cause: error,
    );
  }
  return AppException(
    'The upload failed. Please try again.',
    kind: AppErrorKind.server,
    cause: error,
  );
}

/// Edge Functions can return `{ "reason": "...", "message": "..." }`.
/// The server's message is preferred: it was written for this situation.
AppException _fromFunction(FunctionException error) {
  final details = error.details;
  final reason = details is Map ? details['reason'] : null;
  final serverMessage = details is Map && details['message'] is String
      ? details['message'] as String
      : null;

  if (reason == 'quota_exhausted' || reason == 'limit_reached') {
    return AppException(
      serverMessage ?? "You've reached your limit for now. Try again later.",
      kind: AppErrorKind.quotaExceeded,
      cause: error,
    );
  }
  if (reason == 'rate_limited' || error.status == 429) {
    return AppException(
      serverMessage ?? "We're busy right now. Try again in a minute.",
      kind: AppErrorKind.rateLimited,
      cause: error,
    );
  }
  if (error.status == 401) {
    return AppException(
      'Your session has expired. Please sign in again.',
      kind: AppErrorKind.auth,
      cause: error,
    );
  }
  return AppException(
    serverMessage ?? 'Something went wrong. Please try again.',
    kind: AppErrorKind.server,
    cause: error,
  );
}

/// Supabase's own auth wording, rewritten for the cases users actually
/// hit. Anything unrecognised passes through — those messages are already
/// written for end users.
String supabaseAuthMessage(String raw) {
  final text = raw.toLowerCase();
  if (text.contains('invalid login credentials')) {
    return "That email and password don't match.";
  }
  if (text.contains('already registered') ||
      text.contains('already been registered')) {
    return "There's already an account with that email.";
  }
  if (text.contains('email not confirmed')) {
    return 'Please confirm your email first — check your inbox.';
  }
  if (text.contains('password') && text.contains('at least')) {
    return 'That password is too short.';
  }
  if (text.contains('rate limit') || text.contains('too many')) {
    return 'Too many attempts. Wait a moment and try again.';
  }
  if (text.contains('expired') ||
      (text.contains('invalid') && text.contains('otp'))) {
    return 'That code is wrong or has expired. Request a new one.';
  }
  return raw;
}
