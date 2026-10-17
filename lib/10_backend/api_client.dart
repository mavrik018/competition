/// A small JSON-over-HTTP client for any REST API: base URL, auth header,
/// query parameters, timeouts, safe retries with backoff, and typed errors.
///
/// Newly written. The source apps only talked to Supabase; competition
/// problems often come with their own API (weather, transit, open data, a
/// provided backend). This wraps `package:http` with the parts everyone
/// re-implements badly: joining URLs, decoding errors, and not retrying
/// requests that are unsafe to repeat.
///
/// ```dart
/// final api = ApiClient(
///   baseUrl: 'https://api.example.com/v1',
///   authToken: () async => session?.accessToken,     // optional
/// );
/// final json = await api.get('/stations', query: {'near': '51.5,-0.12', 'limit': 10});
/// final stations = [for (final s in json as List) Station.fromJson(s)];
///
/// try {
///   await api.post('/reports', body: report.toJson());
/// } on ApiException catch (e) {
///   context.showError(e.message);                     // already user-safe
/// }
/// ```
///
/// Testing: pass `client: MockClient((request) async => http.Response('[]', 200))`
/// from `package:http/testing.dart` — no network needed.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

enum ApiErrorKind {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  validation,
  rateLimited,
  server,
  badResponse,
}

class ApiException implements Exception {
  const ApiException(this.kind, this.message, {this.statusCode, this.body});

  final ApiErrorKind kind;

  /// Safe to show the user.
  final String message;
  final int? statusCode;

  /// Decoded response body, for debugging or field-level validation errors.
  final Object? body;

  bool get isRetryable =>
      kind == ApiErrorKind.network ||
      kind == ApiErrorKind.timeout ||
      kind == ApiErrorKind.rateLimited ||
      kind == ApiErrorKind.server;

  @override
  String toString() =>
      'ApiException(${kind.name}${statusCode == null ? '' : ' $statusCode'}): $message';
}

class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? client,
    this.authToken,
    this.headers = const {},
    this.timeout = const Duration(seconds: 15),
    this.maxRetries = 2,
    Future<void> Function(Duration delay)? wait,
  }) : _client = client ?? http.Client(),
       _wait = wait ?? Future<void>.delayed;

  final String baseUrl;
  final http.Client _client;

  /// Returns a bearer token, or null for unauthenticated calls.
  final Future<String?> Function()? authToken;
  final Map<String, String> headers;
  final Duration timeout;

  /// Extra attempts for retryable failures on idempotent requests.
  final int maxRetries;
  final Future<void> Function(Duration delay) _wait;

  Future<Object?> get(String path, {Map<String, Object?>? query}) =>
      _send('GET', path, query: query);

  /// POST is not retried by default: repeating it can create duplicates.
  /// Set [retry] only for endpoints that are idempotent (e.g. use an
  /// idempotency key).
  Future<Object?> post(
    String path, {
    Object? body,
    Map<String, Object?>? query,
    bool retry = false,
  }) => _send('POST', path, body: body, query: query, retry: retry);

  Future<Object?> put(
    String path, {
    Object? body,
    Map<String, Object?>? query,
  }) => _send('PUT', path, body: body, query: query);

  Future<Object?> patch(
    String path, {
    Object? body,
    Map<String, Object?>? query,
    bool retry = false,
  }) => _send('PATCH', path, body: body, query: query, retry: retry);

  Future<Object?> delete(String path, {Map<String, Object?>? query}) =>
      _send('DELETE', path, query: query);

  /// `https://api.x.com/v1` + `/items` → `https://api.x.com/v1/items`, with
  /// null query values dropped and the rest converted to strings.
  Uri buildUri(String path, [Map<String, Object?>? query]) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final rel = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$base$rel');
    final params = {
      ...uri.queryParameters,
      for (final entry in (query ?? const <String, Object?>{}).entries)
        if (entry.value != null) entry.key: '${entry.value}',
    };
    return params.isEmpty ? uri : uri.replace(queryParameters: params);
  }

  Future<Object?> _send(
    String method,
    String path, {
    Object? body,
    Map<String, Object?>? query,
    bool? retry,
  }) async {
    final idempotent = method == 'GET' || method == 'PUT' || method == 'DELETE';
    final attempts = 1 + ((retry ?? idempotent) ? maxRetries : 0);
    ApiException? last;

    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        return await _once(method, path, body: body, query: query);
      } on ApiException catch (error) {
        last = error;
        final canRetry = error.isRetryable && attempt < attempts - 1;
        if (!canRetry) rethrow;
        await _wait(_retryDelay(error, attempt));
      }
    }
    throw last!; // unreachable: the loop either returns or rethrows
  }

  Duration _retryDelay(ApiException error, int attempt) {
    // Honour the server's Retry-After (seconds), capped at 30s.
    final retryAfter = error.body is Map
        ? (error.body as Map)['retry_after_seconds']
        : null;
    if (retryAfter is num) {
      return Duration(seconds: math.min(30, retryAfter.toInt()));
    }
    return Duration(milliseconds: 500 * (1 << attempt)); // 0.5s, 1s, 2s…
  }

  Future<Object?> _once(
    String method,
    String path, {
    Object? body,
    Map<String, Object?>? query,
  }) async {
    final request = http.Request(method, buildUri(path, query))
      ..headers.addAll({'Accept': 'application/json', ...headers});
    final token = await authToken?.call();
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(timeout),
      );
    } on TimeoutException {
      throw const ApiException(
        ApiErrorKind.timeout,
        'The server took too long to respond.',
      );
    } on http.ClientException {
      throw const ApiException(
        ApiErrorKind.network,
        "Can't reach the server. Check your connection.",
      );
    }

    final decoded = _decode(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is _Undecodable) {
        throw ApiException(
          ApiErrorKind.badResponse,
          'The server sent a response we could not read.',
          statusCode: response.statusCode,
          body: response.body,
        );
      }
      return decoded;
    }
    throw _errorFor(
      response,
      decoded is _Undecodable ? response.body : decoded,
    );
  }

  Object? _decode(http.Response response) {
    if (response.body.trim().isEmpty) return null; // 204 / empty body
    try {
      return jsonDecode(response.body);
    } on FormatException {
      return const _Undecodable();
    }
  }

  ApiException _errorFor(http.Response response, Object? body) {
    final status = response.statusCode;
    final serverMessage = errorMessageFrom(body);
    final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
    final enrichedBody = retryAfter == null
        ? body
        : {if (body is Map) ...body, 'retry_after_seconds': retryAfter};
    final (kind, fallback) = switch (status) {
      401 => (ApiErrorKind.unauthorized, 'Please sign in again.'),
      403 => (ApiErrorKind.forbidden, "You don't have access to that."),
      404 => (ApiErrorKind.notFound, 'That could not be found.'),
      400 ||
      409 ||
      422 => (ApiErrorKind.validation, 'Some of the information is not valid.'),
      429 => (
        ApiErrorKind.rateLimited,
        'Too many requests. Please wait a moment.',
      ),
      >= 500 => (
        ApiErrorKind.server,
        'The server had a problem. Please try again.',
      ),
      _ => (
        ApiErrorKind.badResponse,
        'Unexpected response from the server ($status).',
      ),
    };
    // Server text is shown only for 4xx (written for the caller); 5xx text
    // is often a stack trace.
    final message = status < 500 && serverMessage != null
        ? serverMessage
        : fallback;
    return ApiException(kind, message, statusCode: status, body: enrichedBody);
  }

  void close() => _client.close();
}

/// Pulls a message out of common error shapes: `{"message": …}`,
/// `{"error": "…"}`, `{"error": {"message": …}}`, `{"detail": …}`,
/// `{"errors": [{"message": …}]}`.
String? errorMessageFrom(Object? body) {
  if (body is! Map) return null;
  for (final key in ['message', 'detail', 'error_description']) {
    if (body[key] is String) return body[key] as String;
  }
  final error = body['error'];
  if (error is String) return error;
  if (error is Map && error['message'] is String) {
    return error['message'] as String;
  }
  final errors = body['errors'];
  if (errors is List && errors.isNotEmpty) {
    final first = errors.first;
    if (first is String) return first;
    if (first is Map && first['message'] is String) {
      return first['message'] as String;
    }
  }
  return null;
}

class _Undecodable {
  const _Undecodable();
}
