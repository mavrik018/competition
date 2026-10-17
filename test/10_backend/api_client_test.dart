import 'dart:async';
import 'dart:convert';

import 'package:competition_toolkit/10_backend/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  ApiClient client(
    MockClientHandler handler, {
    Future<String?> Function()? token,
    List<Duration>? waits,
  }) => ApiClient(
    baseUrl: 'https://api.example.com/v1/',
    client: MockClient(handler),
    authToken: token,
    wait: (d) async => waits?.add(d),
  );

  test('buildUri joins paths and drops null query values', () {
    final api = client((_) async => http.Response('', 200));
    expect(
      api.buildUri('/items', {'q': 'a b', 'page': 2, 'skip': null}).toString(),
      'https://api.example.com/v1/items?q=a+b&page=2',
    );
    expect(
      api.buildUri('items').toString(),
      'https://api.example.com/v1/items',
    );
  });

  test('GET decodes JSON and sends the bearer token', () async {
    late http.Request seen;
    final api = client((request) async {
      seen = request;
      return http.Response(
        jsonEncode([
          {'id': 1},
        ]),
        200,
      );
    }, token: () async => 'abc');
    expect(await api.get('/items'), [
      {'id': 1},
    ]);
    expect(seen.headers['Authorization'], 'Bearer abc');
    expect(seen.method, 'GET');
  });

  test('POST sends a JSON body; empty responses decode to null', () async {
    late http.Request seen;
    final api = client((request) async {
      seen = request;
      return http.Response('', 204);
    });
    expect(await api.post('/items', body: {'title': 'x'}), isNull);
    expect(jsonDecode(seen.body), {'title': 'x'});
    expect(seen.headers['Content-Type'], startsWith('application/json'));
  });

  test('4xx errors carry the server message and kind', () async {
    final api = client(
      (_) async => http.Response(
        jsonEncode({
          'error': {'message': 'Title is required'},
        }),
        422,
      ),
    );
    await expectLater(
      api.post('/items', body: {}),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.validation)
            .having((e) => e.message, 'message', 'Title is required')
            .having((e) => e.statusCode, 'status', 422),
      ),
    );
  });

  test('5xx text is not shown to users', () async {
    final api = client(
      (_) async => http.Response('NullPointerException at line 42', 500),
    );
    await expectLater(
      api.post('/x'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'The server had a problem. Please try again.',
        ),
      ),
    );
  });

  test('GET retries server errors with backoff, then succeeds', () async {
    var calls = 0;
    final waits = <Duration>[];
    final api = client((_) async {
      calls++;
      return calls < 3
          ? http.Response('busy', 503)
          : http.Response('{"ok":true}', 200);
    }, waits: waits);
    expect(await api.get('/x'), {'ok': true});
    expect(calls, 3);
    expect(waits, [
      const Duration(milliseconds: 500),
      const Duration(seconds: 1),
    ]);
  });

  test('POST is not retried; 429 honours Retry-After when retried', () async {
    var calls = 0;
    final api = client((_) async {
      calls++;
      return http.Response('', 503);
    });
    await expectLater(api.post('/x'), throwsA(isA<ApiException>()));
    expect(calls, 1);

    calls = 0;
    final waits = <Duration>[];
    final limited = client((_) async {
      calls++;
      return calls == 1
          ? http.Response('{}', 429, headers: {'retry-after': '7'})
          : http.Response('[]', 200);
    }, waits: waits);
    expect(await limited.get('/x'), isEmpty);
    expect(waits, [const Duration(seconds: 7)]);
  });

  test('network failures and timeouts become typed errors', () async {
    final offline = client(
      (_) async => throw http.ClientException('Failed host lookup'),
    );
    await expectLater(
      offline.post('/x'),
      throwsA(
        isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.network),
      ),
    );

    final slow = ApiClient(
      baseUrl: 'https://api.example.com',
      client: MockClient((_) => Completer<http.Response>().future),
      timeout: const Duration(milliseconds: 10),
      maxRetries: 0,
    );
    await expectLater(
      slow.get('/x'),
      throwsA(
        isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.timeout),
      ),
    );
  });

  test('a 2xx body that is not JSON is a bad response', () async {
    final api = client((_) async => http.Response('<html>', 200));
    await expectLater(
      api.get('/x'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          ApiErrorKind.badResponse,
        ),
      ),
    );
  });

  test('errorMessageFrom understands common shapes', () {
    expect(errorMessageFrom({'message': 'a'}), 'a');
    expect(errorMessageFrom({'detail': 'b'}), 'b');
    expect(errorMessageFrom({'error': 'c'}), 'c');
    expect(
      errorMessageFrom({
        'errors': [
          {'message': 'd'},
        ],
      }),
      'd',
    );
    expect(errorMessageFrom('plain'), isNull);
  });
}
