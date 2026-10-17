import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:competition_toolkit/10_backend/app_exception.dart';
import 'package:competition_toolkit/10_backend/auth_service.dart';
import 'package:competition_toolkit/10_backend/connectivity.dart';
import 'package:competition_toolkit/10_backend/edge_function_client.dart';
import 'package:competition_toolkit/10_backend/purchases_gateway.dart';
import 'package:competition_toolkit/10_backend/realtime_presence.dart';
import 'package:competition_toolkit/10_backend/storage_uploader.dart';
import 'package:competition_toolkit/10_backend/supabase_errors.dart';
import 'package:competition_toolkit/10_backend/supabase_bootstrap.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AppException.from', () {
    test('passes an AppException through', () {
      const original = AppException('x', kind: AppErrorKind.validation);
      expect(AppException.from(original), same(original));
    });

    test('timeouts and connection errors are offline; others unknown', () {
      expect(AppException.from(TimeoutException('slow')).isOffline, isTrue);
      expect(
        AppException.from(
          Exception('ClientException: Connection refused'),
        ).isOffline,
        isTrue,
      );
      final unknown = AppException.from(StateError('bug'));
      expect(unknown.kind, AppErrorKind.unknown);
      expect(unknown.message, 'Something went wrong. Please try again.');
    });

    test('without the Supabase translator, Supabase errors are generic', () {
      final e = AppException.from(
        const PostgrestException(message: 'dup', code: '23505'),
      );
      expect(e.kind, AppErrorKind.unknown);
    });

    test('a registered translator is used, once, until removed', () {
      AppException.registerTranslator(translateSupabaseError);
      AppException.registerTranslator(translateSupabaseError);
      addTearDown(
        () => AppException.unregisterTranslator(translateSupabaseError),
      );
      expect(
        AppException.from(
          const PostgrestException(message: 'dup', code: '23505'),
        ).message,
        'That already exists.',
      );
      AppException.unregisterTranslator(translateSupabaseError);
      expect(
        AppException.from(
          const PostgrestException(message: 'dup', code: '23505'),
        ).kind,
        AppErrorKind.unknown,
      );
    });
  });

  group('supabaseFailure', () {
    test('auth errors get friendlier wording', () {
      final e = supabaseFailure(
        const AuthException('Invalid login credentials'),
      );
      expect(e.kind, AppErrorKind.auth);
      expect(e.message, "That email and password don't match.");
      expect(
        supabaseFailure(const AuthException('Some new server text')).message,
        'Some new server text',
      );
    });

    test('a retryable auth fetch is an offline error', () {
      final e = supabaseFailure(
        AuthRetryableFetchException(
          message: 'SocketException: Failed host lookup',
        ),
      );
      expect(e.isOffline, isTrue);
    });

    test('Postgres codes map to validation / permission', () {
      expect(
        supabaseFailure(
          const PostgrestException(message: 'dup', code: '23505'),
        ).message,
        'That already exists.',
      );
      expect(
        supabaseFailure(
          const PostgrestException(message: 'rls', code: '42501'),
        ).kind,
        AppErrorKind.permission,
      );
      expect(
        supabaseFailure(
          const PostgrestException(message: '?', code: 'XX000'),
        ).kind,
        AppErrorKind.server,
      );
    });

    test('storage size errors', () {
      final e = supabaseFailure(
        const StorageException('Payload too large', statusCode: '413'),
      );
      expect(e.message, 'That file is too large to upload.');
    });

    test('edge function reasons prefer the server message', () {
      final quota = supabaseFailure(
        const FunctionException(
          status: 429,
          details: {
            'reason': 'quota_exhausted',
            'message': 'Monthly limit reached.',
          },
        ),
      );
      expect(quota.isQuotaExceeded, isTrue);
      expect(quota.message, 'Monthly limit reached.');

      final busy = supabaseFailure(const FunctionException(status: 429));
      expect(busy.kind, AppErrorKind.rateLimited);
      expect(busy.isRetryable, isTrue);

      expect(
        supabaseFailure(const FunctionException(status: 401)).isAuth,
        isTrue,
      );
    });

    test('non-Supabase errors fall back to the generic rules', () {
      expect(translateSupabaseError(StateError('bug')), isNull);
      expect(supabaseFailure(TimeoutException('slow')).isOffline, isTrue);
    });
  });

  group('Auth helpers', () {
    test('generateNonce uses the URL-safe charset at the given length', () {
      final nonce = generateNonce(48, Random(1));
      expect(nonce, hasLength(48));
      expect(RegExp(r'^[0-9A-Za-z\-._]+$').hasMatch(nonce), isTrue);
      expect(generateNonce(), isNot(generateNonce()));
    });

    test('sha256Hex matches a known vector', () {
      expect(
        sha256Hex('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('Supabase config is empty unless passed with --dart-define', () async {
      expect(SupabaseConfig.isConfigured, isFalse);
      expect(await initializeSupabase(), contains('not configured'));
    });
  });

  group('EdgeFunctionClient', () {
    EdgeFunctionClient client(
      Object? Function() respond, {
      bool signedIn = true,
    }) => EdgeFunctionClient(
      invoke: (name, body) async => respond(),
      isSignedIn: () => signedIn,
    );

    test('returns parsed data from an ok envelope', () async {
      final result = await client(
        () => {
          'ok': true,
          'data': {'summary': 'short'},
        },
      ).call('summarize', parse: (d) => d['summary'] as String);
      expect(result, 'short');
    });

    test('ok:false on a 2xx is still a failure', () async {
      final call = client(
        () => {
          'ok': false,
          'error': {
            'code': 'limit_reached',
            'message': 'Limit',
            'details': {'cap': 5},
          },
        },
      ).call('x', parse: (d) => d);
      await expectLater(
        call,
        throwsA(
          isA<EdgeFunctionFailure>()
              .having((f) => f.isLimitReached, 'limit', isTrue)
              .having((f) => f.details['cap'], 'cap', 5),
        ),
      );
    });

    test('non-2xx with an envelope keeps the server code', () async {
      final call = client(
        () => throw const FunctionException(
          status: 400,
          details: {
            'ok': false,
            'error': {
              'code': 'invalid_request',
              'message': 'Text is empty',
              'retryable': false,
            },
          },
        ),
      ).call('x', parse: (d) => d);
      await expectLater(
        call,
        throwsA(
          isA<EdgeFunctionFailure>().having(
            (f) => f.message,
            'message',
            'Text is empty',
          ),
        ),
      );
    });

    test(
      'a gateway error page becomes a retryable transport failure',
      () async {
        final call = client(
          () => throw const FunctionException(status: 502, details: '<html>'),
        ).call('x', parse: (d) => d);
        await expectLater(
          call,
          throwsA(
            isA<EdgeFunctionFailure>()
                .having((f) => f.code, 'code', 'transport')
                .having((f) => f.retryable, 'retryable', isTrue),
          ),
        );
      },
    );

    test('a parse failure is reported, not thrown raw', () async {
      final call = client(
        () => {
          'ok': true,
          'data': {'n': 'not a number'},
        },
      ).call('x', parse: (d) => d['n'] as int);
      await expectLater(
        call,
        throwsA(
          isA<EdgeFunctionFailure>().having(
            (f) => f.code,
            'code',
            'bad_response',
          ),
        ),
      );
    });

    test('signed-out callers fail before the network', () async {
      var called = false;
      final c = EdgeFunctionClient(
        invoke: (_, _) async {
          called = true;
          return null;
        },
        isSignedIn: () => false,
      );
      await expectLater(
        c.call('x', parse: (d) => d),
        throwsA(isA<EdgeFunctionFailure>()),
      );
      expect(called, isFalse);
    });
  });

  group('StorageUploader', () {
    final bytes = Uint8List.fromList([1, 2, 3]);

    test('retries with growing waits, then succeeds', () async {
      var attempts = 0;
      final waits = <Duration>[];
      final progress = <double>[];
      final uploader = StorageUploader(
        uploadBytes: (path, data, type) async {
          if (++attempts < 3) throw const StorageException('flaky');
        },
        wait: (d) async => waits.add(d),
      );
      final path = await uploader.upload(
        bytes: bytes,
        path: 'u/a.jpg',
        onProgress: progress.add,
      );
      expect(path, 'u/a.jpg');
      expect(attempts, 3);
      expect(waits, [const Duration(seconds: 2), const Duration(seconds: 4)]);
      expect(progress.last, 1);
    });

    test('throws the last error when attempts run out', () async {
      final uploader = StorageUploader(
        uploadBytes: (_, _, _) async => throw const StorageException('down'),
        wait: (_) async {},
      );
      await expectLater(
        uploader.upload(bytes: bytes, path: 'p'),
        throwsA(isA<StorageException>()),
      );
    });

    test('a cancelled handle stops before the next attempt', () async {
      final handle = UploadHandle();
      var attempts = 0;
      final uploader = StorageUploader(
        uploadBytes: (_, _, _) async {
          attempts++;
          handle.cancel();
          throw const StorageException('flaky');
        },
        wait: (_) async {},
      );
      await expectLater(
        uploader.upload(bytes: bytes, path: 'p', handle: handle),
        throwsA(isA<UploadCancelled>()),
      );
      expect(attempts, 1);
    });

    test('storagePath puts the owner first', () {
      expect(
        storagePath(
          ownerId: 'u1',
          folder: 'avatars',
          extension: '.jpg',
          id: 'abc',
        ),
        'u1/avatars/abc.jpg',
      );
      expect(
        storagePath(ownerId: 'u1', folder: 'f', extension: 'png'),
        matches(RegExp(r'^u1/f/[0-9a-f-]{36}\.png$')),
      );
    });
  });

  test('SignedUrlCache re-signs shortly before expiry', () async {
    var now = DateTime(2026);
    var signs = 0;
    final cache = SignedUrlCache(
      (path, ttl) async => '$path?v=${++signs}',
      ttl: const Duration(minutes: 10),
      clock: () => now,
    );
    expect(await cache.get('a'), 'a?v=1');
    now = now.add(const Duration(minutes: 9));
    expect(await cache.get('a'), 'a?v=1');
    now = now.add(const Duration(seconds: 40)); // inside the 30s margin
    expect(await cache.get('a'), 'a?v=2');
    cache.invalidate('a');
    expect(await cache.get('a'), 'a?v=3');
  });

  test('onlineIdsFrom de-duplicates and skips malformed payloads', () {
    expect(
      onlineIdsFrom([
        {'user_id': 'a'},
        {'user_id': 'a'}, // two devices, same user
        {'user_id': 'b'},
        {'other': 1},
      ]),
      {'a', 'b'},
    );
  });

  test('hasConnection', () {
    expect(hasConnection([ConnectivityResult.none]), isFalse);
    expect(hasConnection([]), isFalse);
    expect(
      hasConnection([ConnectivityResult.none, ConnectivityResult.wifi]),
      isTrue,
    );
  });

  test('product ids map to plans without the Play base-plan suffix', () {
    const plans = {'pro_monthly': 'pro', 'pro_yearly': 'pro'};
    expect(baseProductId('pro_monthly:monthly-base'), 'pro_monthly');
    expect(planForProduct('pro_yearly:annual', plans, 'free'), 'pro');
    expect(planForProduct('unknown', plans, 'free'), 'free');
    expect(planForProduct(null, plans, 'free'), 'free');
  });
}
