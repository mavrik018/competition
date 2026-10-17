/// A durable queue of writes made while offline, replayed in order when the
/// connection returns.
///
/// Source: three implementations were merged.
/// * Couple `pending_ops_dao.dart` + `offline_sync_coordinator.dart`: opaque
///   `op_type` + JSON payload, capped exponential backoff, attempts cap that
///   leaves the row for a manual retry instead of deleting it.
/// * StudyBuddies `sync_queue_service.dart`: three outcomes per item
///   (success / retry / conflict) and "stop the cycle on the first transient
///   failure — the rest will fail the same way".
/// * Cookly `local_cache_db.dart`: rows scoped by user id, so a second
///   account on the device never replays the first one's writes.
///
/// What an op *means* is not known here: callers register one handler per
/// op type when draining (the Couple coordinator's `switch` became a map).
///
/// ```dart
/// final db = await openDatabase(path, version: 1, onCreate: (db, _) => OfflineQueue.createTable(db));
/// final queue = OfflineQueue(db);
///
/// await queue.enqueue('note_upsert', note.toJson(), userId: uid);
///
/// // On reconnect:
/// await queue.drain(userId: uid, handlers: {
///   'note_upsert': (payload) async {
///     await supabase.from('notes').upsert(payload);
///     return OpOutcome.done;
///   },
/// });
/// ```
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'local_id.dart';

/// What a handler reports after trying to replay one op.
enum OpOutcome {
  /// Applied. The op is removed.
  done,

  /// Failed for a reason that may pass (offline, timeout). The op is kept
  /// with backoff, and the rest of this drain is skipped.
  retry,

  /// Can never succeed as written (validation error, the row was deleted, a
  /// conflict with newer server data). The op is removed and reported in
  /// [DrainResult.dropped] so the app can tell the user.
  drop,
}

typedef OpHandler = Future<OpOutcome> Function(Map<String, dynamic> payload);

@immutable
class PendingOp {
  const PendingOp({
    required this.id,
    required this.userId,
    required this.type,
    required this.payload,
    required this.attempts,
    required this.nextAttemptAt,
    required this.createdAt,
    this.lastError,
  });

  final String id;
  final String? userId;
  final String type;
  final Map<String, dynamic> payload;
  final int attempts;
  final DateTime nextAttemptAt;
  final DateTime createdAt;
  final String? lastError;

  factory PendingOp.fromRow(Map<String, Object?> row) => PendingOp(
    id: row['id']! as String,
    userId: row['user_id'] as String?,
    type: row['op_type']! as String,
    payload: jsonDecode(row['payload']! as String) as Map<String, dynamic>,
    attempts: row['attempts']! as int,
    nextAttemptAt: DateTime.parse(row['next_attempt_at']! as String),
    createdAt: DateTime.parse(row['created_at']! as String),
    lastError: row['last_error'] as String?,
  );
}

@immutable
class DrainResult {
  const DrainResult({
    this.done = 0,
    this.dropped = const [],
    this.stoppedEarly = false,
  });

  final int done;
  final List<PendingOp> dropped;

  /// True when a retryable failure ended the drain before the queue was
  /// empty (usually: still offline).
  final bool stoppedEarly;
}

class OfflineQueue {
  OfflineQueue(this._db, {this.maxAttempts = 5, DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  static const table = 'pending_ops';

  final Database _db;
  final DateTime Function() _now;

  /// After this many failed attempts an op is no longer retried
  /// automatically; it stays visible for [retryNow] or [remove].
  final int maxAttempts;

  bool _draining = false;

  /// Call from `openDatabase(onCreate: …)` (or `onUpgrade` when adding the
  /// queue to an existing database).
  static Future<void> createTable(DatabaseExecutor db) async {
    await db.execute('''
      create table if not exists $table (
        id              text primary key,
        user_id         text,
        op_type         text not null,
        payload         text not null,
        attempts        integer not null default 0,
        next_attempt_at text not null,
        created_at      text not null,
        last_error      text
      )
    ''');
    await db.execute(
      'create index if not exists ${table}_user_created on $table (user_id, created_at)',
    );
  }

  /// Backoff after [attempts] failures: 30s, 1m, 2m, 4m, then 8m.
  static Duration backoff(int attempts) =>
      Duration(seconds: 30 * (1 << (attempts - 1).clamp(0, 4)));

  /// Adds an op and returns its id.
  Future<String> enqueue(
    String type,
    Map<String, dynamic> payload, {
    String? userId,
  }) async {
    final id = generateLocalId();
    final now = _now().toIso8601String();
    await _db.insert(table, {
      'id': id,
      'user_id': userId,
      'op_type': type,
      'payload': jsonEncode(payload),
      'attempts': 0,
      'next_attempt_at': now,
      'created_at': now,
    });
    return id;
  }

  /// Every queued op for [userId], oldest first — including exhausted ones.
  Future<List<PendingOp>> all({String? userId}) async {
    final rows = await _db.query(
      table,
      where: userId == null ? 'user_id is null' : 'user_id = ?',
      whereArgs: userId == null ? null : [userId],
      orderBy: 'created_at asc, rowid asc',
    );
    return rows.map(PendingOp.fromRow).toList();
  }

  Future<int> pendingCount({String? userId}) async {
    final result = await _db.rawQuery(
      'select count(*) as n from $table where ${userId == null ? 'user_id is null' : 'user_id = ?'}',
      userId == null ? null : [userId],
    );
    return (result.first['n'] as int?) ?? 0;
  }

  /// Replays due ops for [userId] in creation order.
  ///
  /// An op whose type has no handler is left untouched (an older app version
  /// may have queued a type this build does not know yet). Re-entrant calls
  /// while a drain is running return immediately with an empty result.
  Future<DrainResult> drain({
    required Map<String, OpHandler> handlers,
    String? userId,
  }) async {
    if (_draining) return const DrainResult();
    _draining = true;
    var done = 0;
    final dropped = <PendingOp>[];
    try {
      final now = _now();
      final ops = (await all(userId: userId)).where(
        (op) => op.attempts < maxAttempts && !op.nextAttemptAt.isAfter(now),
      );
      for (final op in ops) {
        final handler = handlers[op.type];
        if (handler == null) continue;

        OpOutcome outcome;
        String? error;
        try {
          outcome = await handler(op.payload);
        } catch (e) {
          outcome = OpOutcome.retry;
          error = '$e';
        }

        switch (outcome) {
          case OpOutcome.done:
            await remove(op.id);
            done++;
          case OpOutcome.drop:
            await remove(op.id);
            dropped.add(op);
          case OpOutcome.retry:
            await _recordFailure(op, error);
            return DrainResult(
              done: done,
              dropped: dropped,
              stoppedEarly: true,
            );
        }
      }
      return DrainResult(done: done, dropped: dropped);
    } finally {
      _draining = false;
    }
  }

  /// Makes an op (typically an exhausted one) due again with a fresh budget.
  Future<void> retryNow(String id) => _db.update(
    table,
    {'attempts': 0, 'next_attempt_at': _now().toIso8601String()},
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<void> remove(String id) =>
      _db.delete(table, where: 'id = ?', whereArgs: [id]);

  /// Drops every op for [userId] — on sign-out, so the next account on this
  /// device never replays them.
  Future<void> clearUser(String userId) =>
      _db.delete(table, where: 'user_id = ?', whereArgs: [userId]);

  Future<void> _recordFailure(PendingOp op, String? error) {
    final attempts = op.attempts + 1;
    return _db.update(
      table,
      {
        'attempts': attempts,
        'next_attempt_at': _now().add(backoff(attempts)).toIso8601String(),
        'last_error': error,
      },
      where: 'id = ?',
      whereArgs: [op.id],
    );
  }
}
