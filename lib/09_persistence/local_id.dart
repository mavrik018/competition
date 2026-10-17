/// A random RFC 4122 version-4 UUID generated on the device.
///
/// Source: Cookly `core/local_id.dart`. Creating a row's id on the client is
/// what makes offline-first writes simple: the row keeps the same id when it
/// is synced (Postgres accepts a supplied uuid exactly like a generated
/// one), so nothing ever has to remap a temporary id to a permanent one.
/// Uses [Random.secure], so ids are unguessable.
///
/// ```dart
/// final note = Note(id: generateLocalId(), title: title);
/// await queue.enqueue('note_create', note.toJson());
/// ```
library;

import 'dart:math';

String generateLocalId([Random? random]) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant

  String hex(int start, int end) => bytes
      .sublist(start, end)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
