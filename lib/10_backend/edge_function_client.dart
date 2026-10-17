/// One way to call Supabase Edge Functions that return a standard JSON
/// envelope, so parsing and error handling exist once instead of per feature.
///
/// Envelope (what the functions return):
///
/// ```json
/// { "ok": true,  "data": { ... } }
/// { "ok": false, "error": { "code": "limit_reached", "message": "...", "retryable": false, "details": { ... } } }
/// ```
///
/// Source: StudyBuddies `features/ai/data/ai_edge_client.dart` and
/// `domain/ai_failure.dart`. Kept: fail fast when signed out, treat the
/// envelope as authoritative even on a 2xx, report a parse failure as a
/// readable error instead of a crash, and never send a client-side "plan"
/// hint (the server decides what the caller paid for). Generalised: error
/// codes are strings rather than an AI-specific enum, and the network call
/// is injectable so the parsing is unit-tested.
///
/// ```dart
/// final functions = EdgeFunctionClient.supabase(Supabase.instance.client);
/// final summary = await functions.call(
///   'summarize',
///   body: {'text': note.body},
///   parse: (data) => data['summary'] as String,
/// );
/// ```
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A failed function call, ready to show: [message] is user-safe.
@immutable
class EdgeFunctionFailure implements Exception {
  const EdgeFunctionFailure({
    required this.code,
    required this.message,
    this.retryable = false,
    this.details = const {},
    this.cause,
  });

  /// e.g. `unauthorized`, `invalid_request`, `limit_reached`,
  /// `rate_limited`, `provider_error` — or `transport` / `bad_response`,
  /// produced on the client when there was no valid envelope.
  final String code;
  final String message;
  final bool retryable;
  final Map<String, dynamic> details;
  final Object? cause;

  bool get isLimitReached => code == 'limit_reached';
  bool get isUnauthorized => code == 'unauthorized';

  factory EdgeFunctionFailure.fromEnvelope(
    Map<String, dynamic> error, {
    Object? cause,
  }) => EdgeFunctionFailure(
    code: (error['code'] as String?) ?? 'unknown',
    message:
        (error['message'] as String?) ??
        'Something went wrong. Please try again.',
    retryable: (error['retryable'] as bool?) ?? false,
    details: switch (error['details']) {
      final Map<String, dynamic> map => map,
      _ => const {},
    },
    cause: cause,
  );

  factory EdgeFunctionFailure.transport(Object? cause) => EdgeFunctionFailure(
    code: 'transport',
    message: "Couldn't reach the server. Check your connection and try again.",
    retryable: true,
    cause: cause,
  );

  @override
  String toString() => 'EdgeFunctionFailure($code: $message)';
}

/// Performs the HTTP call and returns the decoded body. Throws
/// [FunctionException] for non-2xx responses, like Supabase does.
typedef FunctionInvoker =
    Future<Object?> Function(String name, Map<String, dynamic> body);

class EdgeFunctionClient {
  EdgeFunctionClient({
    required FunctionInvoker invoke,
    bool Function()? isSignedIn,
  }) : _invoke = invoke,
       _isSignedIn = isSignedIn;

  factory EdgeFunctionClient.supabase(SupabaseClient client) =>
      EdgeFunctionClient(
        invoke: (name, body) async =>
            (await client.functions.invoke(name, body: body)).data,
        isSignedIn: () => client.auth.currentSession != null,
      );

  final FunctionInvoker _invoke;
  final bool Function()? _isSignedIn;

  /// Calls [name] and returns `parse(data)`. Throws [EdgeFunctionFailure] —
  /// never a raw `FunctionException`.
  Future<T> call<T>(
    String name, {
    Map<String, dynamic> body = const {},
    required T Function(Map<String, dynamic> data) parse,
  }) async {
    if (_isSignedIn != null && !_isSignedIn()) {
      throw const EdgeFunctionFailure(
        code: 'unauthorized',
        message: 'Please sign in first.',
      );
    }

    final Object? payload;
    try {
      payload = await _invoke(name, body);
    } on FunctionException catch (error) {
      // Non-2xx: `details` holds the decoded body — our envelope whenever
      // the function itself produced the failure.
      throw failureFromBody(error.details, cause: error);
    } catch (error) {
      throw EdgeFunctionFailure.transport(error);
    }
    return parseEnvelope(payload, parse);
  }

  /// Unwraps a 2xx body. Exposed for tests and for calls made elsewhere.
  static T parseEnvelope<T>(
    Object? payload,
    T Function(Map<String, dynamic> data) parse,
  ) {
    if (payload is! Map<String, dynamic>) {
      throw EdgeFunctionFailure(
        code: 'bad_response',
        message: 'The server sent an unexpected response. Please try again.',
        retryable: true,
        cause: payload,
      );
    }
    // A 2xx can still carry `ok: false`; the envelope is authoritative.
    if (payload['ok'] != true) throw failureFromBody(payload);

    final data = payload['data'];
    if (data is! Map<String, dynamic>) {
      throw const EdgeFunctionFailure(
        code: 'bad_response',
        message: 'The server sent an unexpected response. Please try again.',
        retryable: true,
      );
    }
    try {
      return parse(data);
    } catch (error) {
      // Schema drift on the server should not look like a client crash.
      throw EdgeFunctionFailure(
        code: 'bad_response',
        message: "We couldn't read the server's response. Please try again.",
        retryable: true,
        cause: error,
      );
    }
  }

  /// Builds a failure from an error body, or a transport failure when the
  /// body is not one of our envelopes (a gateway HTML page, an empty body).
  static EdgeFunctionFailure failureFromBody(Object? body, {Object? cause}) {
    if (body is Map<String, dynamic>) {
      final error = body['error'];
      if (error is Map<String, dynamic>) {
        return EdgeFunctionFailure.fromEnvelope(error, cause: cause);
      }
    }
    return EdgeFunctionFailure.transport(cause ?? body);
  }
}
