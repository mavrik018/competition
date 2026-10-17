/// Offline-first repository: reads and writes always hit the local store
/// (instant, works with no signal); every write is also queued and pushed
/// to the server by [OfflineFirstRepository.sync], which then pulls remote
/// changes and merges them with **last-write-wins** by `updatedAt`.
///
/// **Not AI.** A queue plus a timestamp comparison. Implements the same
/// `Repository<T>` interface as the in-memory, SQLite and Supabase ones, so
/// `CrudController` and the screens do not change.
///
/// Suits: field data collection, inspections, clinics or schools with poor
/// connectivity, shopping lists, notes, habit/expense logs — anything that
/// must keep working underground or on a plane.
///
/// ```dart
/// final notes = OfflineFirstRepository<Note>(
///   name: 'notes',
///   local: SqfliteRepository(db, table: 'notes', idOf: …, toJson: …, fromJson: …),
///   remote: SupabaseRepository(client, table: 'notes', …),
///   queue: OfflineQueue(db),
///   idOf: (n) => n.id,
///   updatedAtOf: (n) => n.updatedAt,
///   toJson: (n) => n.toJson(),
///   fromJson: Note.fromJson,
///   isOnline: () async => ref.read(connectivityProvider).value ?? false,
///   userId: currentUserId,
/// );
/// // Call sync on reconnect, on app resume and on pull-to-refresh:
/// ref.listen(connectivityProvider, (_, online) { if (online.value == true) notes.sync(); });
/// ```
///
/// **Conflict rule:** whichever copy has the later `updatedAt` wins as a
/// whole item (fields are not merged). Device clocks can be wrong — set
/// `updatedAt` on the server (a trigger) if that matters.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../09_persistence/offline_queue.dart';
import '../09_persistence/repository.dart';

class SyncReport {
  const SyncReport({
    this.pushed = 0,
    this.pulled = 0,
    this.removed = 0,
    this.dropped = const [],
    this.pending = 0,
    this.skippedOffline = false,
    this.error,
  });

  /// Local writes the server accepted.
  final int pushed;

  /// Remote items that were newer and replaced (or added to) local data.
  final int pulled;

  /// Local items deleted because the server no longer has them.
  final int removed;

  /// Queued writes that were not applied: rejected for good
  /// ([OfflineFirstRepository.isPermanentError]) or older than the server
  /// copy (the conflict was lost). Tell the user.
  final List<PendingOp> dropped;

  /// Writes still waiting (offline or failing).
  final int pending;
  final bool skippedOffline;

  /// Why the pull step failed, if it did.
  final Object? error;
}

class OfflineFirstRepository<T> implements Repository<T> {
  OfflineFirstRepository({
    required this.name,
    required this.local,
    required this.remote,
    required this.queue,
    required this.idOf,
    required this.updatedAtOf,
    required this.toJson,
    required this.fromJson,
    required this.isOnline,
    this.userId,
    this.pruneMissing = false,
    this.isPermanentError,
  });

  /// Prefix for queued op types ('notes_save', 'notes_delete') — unique per
  /// entity when several share one queue.
  final String name;
  final Repository<T> local;
  final Repository<T> remote;
  final OfflineQueue queue;
  final String Function(T item) idOf;
  final DateTime Function(T item) updatedAtOf;
  final Map<String, dynamic> Function(T item) toJson;
  final T Function(Map<String, dynamic> json) fromJson;
  final FutureOr<bool> Function() isOnline;
  final String? userId;

  /// Delete local items the server no longer has (deleted on another
  /// device). Only safe when [remote] returns *all* of this user's rows.
  final bool pruneMissing;

  /// Errors for which retrying is pointless (validation, permission) — the
  /// write is dropped and reported. Others are retried with backoff.
  final bool Function(Object error)? isPermanentError;

  Future<SyncReport>? _running;
  Future<SyncReport>? _queued;

  String get _saveOp => '${name}_save';
  String get _deleteOp => '${name}_delete';

  @override
  Future<List<T>> getAll() => local.getAll();

  @override
  Future<T?> getById(String id) => local.getById(id);

  @override
  Stream<List<T>> watchAll() => local.watchAll();

  /// Saves locally, queues the upload and tries to sync in the background.
  @override
  Future<void> save(T item) async {
    await local.save(item);
    await queue.enqueue(_saveOp, toJson(item), userId: userId);
    _syncInBackground();
  }

  @override
  Future<void> delete(String id) async {
    await local.delete(id);
    await queue.enqueue(_deleteOp, {'id': id}, userId: userId);
    _syncInBackground();
  }

  void _syncInBackground() => unawaited(
    sync().then<void>(
      (_) {},
      onError: (Object e) => debugPrint('OfflineFirstRepository($name): $e'),
    ),
  );

  Future<int> pendingCount() => queue.pendingCount(userId: userId);

  /// Pushes queued writes, then pulls and merges remote data. Safe to call
  /// often: while a run is in progress, further calls share *one* follow-up
  /// run (so a call made just after reconnecting is never answered with the
  /// result of a run that started offline). Offline runs return at once.
  Future<SyncReport> sync() {
    final running = _running;
    if (running == null) return _start();
    return _queued ??= running.then<void>((_) {}, onError: (Object _) {}).then((
      _,
    ) {
      _queued = null;
      return _start();
    });
  }

  Future<SyncReport> _start() {
    final run = _running = _sync();
    run.whenComplete(() {
      if (identical(_running, run)) _running = null;
    }).ignore();
    return run;
  }

  Future<SyncReport> _sync() async {
    if (!await isOnline()) {
      return SyncReport(skippedOffline: true, pending: await pendingCount());
    }

    // 1. Push, oldest first. Stops at the first retryable failure.
    Future<OpOutcome> guarded(Future<void> Function() write) async {
      try {
        await write();
        return OpOutcome.done;
      } catch (e) {
        if (isPermanentError?.call(e) ?? false) return OpOutcome.drop;
        rethrow; // the queue records the error and backs off
      }
    }

    final drained = await queue.drain(
      userId: userId,
      handlers: {
        _saveOp: (payload) async {
          final mine = fromJson(payload);
          // Last-write-wins on push too: a newer server copy beats this one.
          final theirs = await remote.getById(idOf(mine));
          if (theirs != null &&
              updatedAtOf(theirs).isAfter(updatedAtOf(mine))) {
            return OpOutcome.drop;
          }
          return guarded(() => remote.save(mine));
        },
        _deleteOp: (payload) =>
            guarded(() => remote.delete(payload['id'] as String)),
      },
    );

    // 2. Pull and merge. Items with unsent local writes are left alone so a
    //    stale server copy never overwrites them.
    final waiting = await queue.all(userId: userId);
    final dirtyIds = {
      for (final op in waiting)
        if (op.type == _saveOp || op.type == _deleteOp)
          '${op.type == _deleteOp ? op.payload['id'] : idOf(fromJson(op.payload))}',
    };
    var pulled = 0;
    var removed = 0;
    Object? error;
    try {
      final remoteItems = await remote.getAll();
      final remoteIds = <String>{};
      for (final item in remoteItems) {
        final id = idOf(item);
        remoteIds.add(id);
        if (dirtyIds.contains(id)) continue;
        final mine = await local.getById(id);
        if (mine == null || updatedAtOf(item).isAfter(updatedAtOf(mine))) {
          await local.save(item);
          pulled++;
        }
      }
      if (pruneMissing) {
        for (final item in await local.getAll()) {
          final id = idOf(item);
          if (!remoteIds.contains(id) && !dirtyIds.contains(id)) {
            await local.delete(id);
            removed++;
          }
        }
      }
    } catch (e) {
      error = e;
    }

    return SyncReport(
      pushed: drained.done,
      pulled: pulled,
      removed: removed,
      dropped: drained.dropped,
      pending: waiting.length,
      error: error,
    );
  }
}
