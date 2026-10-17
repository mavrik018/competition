/// Whether the device has a network connection, as a Riverpod stream.
///
/// Source: Couple `core/network/connectivity_provider.dart` (emits the
/// current state first, then only real changes) and Cookly
/// `data/connectivity.dart` (optimistic "online" before the first event, so
/// a slow plugin never flashes an offline banner on a phone that is online).
///
/// This reports link-layer connectivity, not whether your backend is
/// reachable: a captive portal or a server outage still reads as online.
/// That is good enough to retry a cached screen or drain an offline queue.
///
/// ```dart
/// final online = ref.watch(isOnlineProvider);
/// OfflineBanner(isOnline: online);
///
/// ref.listen(isOnlineProvider, (was, now) {
///   if (was == false && now) queue.drain(handlers: handlers);
/// });
/// ```
library;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True when any transport is up.
bool hasConnection(List<ConnectivityResult> results) =>
    results.any((result) => result != ConnectivityResult.none);

final connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  yield hasConnection(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(hasConnection).distinct();
});

/// Synchronous view: optimistic `true` until the first reading and on error.
final isOnlineProvider = Provider<bool>(
  (ref) => ref.watch(connectivityProvider).value ?? true,
);
