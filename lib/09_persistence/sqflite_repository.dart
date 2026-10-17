/// `Repository<T>` stored in SQLite (sqflite): each entity is one JSON row,
/// so adding a model field needs no migration.
///
/// Platforms: Android, iOS, macOS (and Windows/Linux through
/// `sqflite_common_ffi`). **Not the web** — use `InMemoryRepository`, a
/// backend repository, or a web-capable database there.
///
/// ```dart
/// final db = await openDatabase('app.db', version: 1,
///     onCreate: (db, _) => SqfliteRepository.createTable(db, 'tasks'));
/// final tasks = SqfliteRepository<Task>(
///   db,
///   table: 'tasks',
///   idOf: (t) => t.id,
///   toJson: (t) => t.toJson(),
///   fromJson: Task.fromJson,
/// );
/// await tasks.save(Task(id: generateLocalId(), title: 'Buy milk'));
/// tasks.watchAll().listen(render);
/// ```
library;

import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'repository.dart';

/// Stores each entity as a JSON row in a SQLite table:
/// `(id text primary key, json text, updated_at text)`.
///
/// Schema-less on purpose: adding a field to the model needs no migration.
/// For queries on specific columns at scale, write a dedicated table.
class SqfliteRepository<T> implements Repository<T> {
  SqfliteRepository(
    this._db, {
    required this.table,
    required this.idOf,
    required this.toJson,
    required this.fromJson,
  });

  final Database _db;
  final String table;
  final String Function(T item) idOf;
  final Map<String, Object?> Function(T item) toJson;
  final T Function(Map<String, Object?> json) fromJson;
  final _changes = StreamController<List<T>>.broadcast();

  /// Call from `openDatabase(onCreate: …)` once per table.
  static Future<void> createTable(DatabaseExecutor db, String table) =>
      db.execute('''
        create table if not exists $table (
          id         text primary key,
          json       text not null,
          updated_at text not null
        )
      ''');

  @override
  Future<List<T>> getAll() async {
    final rows = await _db.query(table, orderBy: 'updated_at desc');
    return [for (final row in rows) _decode(row)];
  }

  @override
  Future<T?> getById(String id) async {
    final rows = await _db.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _decode(rows.first);
  }

  @override
  Stream<List<T>> watchAll() => watchList(_changes, getAll);

  @override
  Future<void> save(T item) async {
    await _db.insert(table, {
      'id': idOf(item),
      'json': jsonEncode(toJson(item)),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _changes.add(await getAll());
  }

  @override
  Future<void> delete(String id) async {
    await _db.delete(table, where: 'id = ?', whereArgs: [id]);
    _changes.add(await getAll());
  }

  T _decode(Map<String, Object?> row) => fromJson(
    (jsonDecode(row['json']! as String) as Map).cast<String, Object?>(),
  );

  Future<void> dispose() => _changes.close();
}
