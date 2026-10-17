/// The generic [Repository] backed by a Supabase table, so `CrudController`,
/// `CrudListScreen` and `OfflineFirstRepository` work unchanged against a
/// real backend.
///
/// Newly written; it condenses the per-table repositories in all four
/// source apps. Row-level security does the per-user filtering — add a
/// policy like `user_id = auth.uid()` and include `user_id` in [toRow].
///
/// ```dart
/// final notes = SupabaseRepository<Note>(
///   Supabase.instance.client,
///   table: 'notes',
///   fromRow: Note.fromJson,
///   toRow: (n) => {...n.toJson(), 'user_id': uid},
///   idOf: (n) => n.id,
///   orderBy: 'updated_at',
/// );
/// ```
///
/// [watchAll] uses Supabase Realtime (`.stream()`), which needs Realtime
/// enabled for the table in the dashboard.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../09_persistence/repository.dart';
import 'supabase_errors.dart';

class SupabaseRepository<T> implements Repository<T> {
  SupabaseRepository(
    this._client, {
    required this.table,
    required this.fromRow,
    required this.toRow,
    required this.idOf,
    this.idColumn = 'id',
    this.orderBy,
    this.ascending = false,
  });

  final SupabaseClient _client;
  final String table;
  final T Function(Map<String, dynamic> row) fromRow;
  final Map<String, dynamic> Function(T item) toRow;
  final String Function(T item) idOf;
  final String idColumn;
  final String? orderBy;
  final bool ascending;

  @override
  Future<List<T>> getAll() => _guard(() async {
    final query = _client.from(table).select();
    final rows = orderBy == null
        ? await query
        : await query.order(orderBy!, ascending: ascending);
    return [for (final row in rows) fromRow(row)];
  });

  @override
  Future<T?> getById(String id) => _guard(() async {
    final row = await _client
        .from(table)
        .select()
        .eq(idColumn, id)
        .maybeSingle();
    return row == null ? null : fromRow(row);
  });

  @override
  Stream<List<T>> watchAll() => _client
      .from(table)
      .stream(primaryKey: [idColumn])
      .map((rows) => [for (final row in rows) fromRow(row)]);

  @override
  Future<void> save(T item) =>
      _guard(() => _client.from(table).upsert(toRow(item)));

  @override
  Future<void> delete(String id) =>
      _guard(() => _client.from(table).delete().eq(idColumn, id));

  /// Every failure leaves as an [AppException] with a user-safe message.
  Future<R> _guard<R>(Future<R> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw supabaseFailure(error);
    }
  }
}
