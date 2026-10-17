/// An offline read cache: mirrors the last successful fetch of a list (or a
/// single item) per user, and remembers when it was synced, so a screen can
/// show "offline — data from 12m ago" instead of an error.
///
/// Source: Cookly `data/local/local_cache_db.dart`, which had one method pair
/// per model (`savePantry`/`loadPantry`, `saveShoppingList`/…). Generalised
/// to any JSON-serialisable model through a cache key. Kept from the source:
///
/// * Saving replaces the whole collection in one transaction — simpler and
///   safer than diffing at tens-to-hundreds of rows.
/// * `null` from [loadCollection] means "never synced", distinct from an
///   empty list ("synced, and there was nothing"). Callers use that to decide
///   between an empty state and a "can't reach the server" error.
/// * Every row is scoped by user id, and [clearUser] runs on sign-out, so a
///   shared device never shows one person's data to the next.
///
/// ```dart
/// Future<List<Note>> loadNotes(String uid) async {
///   try {
///     final rows = await supabase.from('notes').select();
///     unawaited(cache.saveCollection(uid, 'notes', rows));
///     return rows.map(Note.fromJson).toList();
///   } catch (e) {
///     final cached = await cache.loadCollection(uid, 'notes');
///     if (cached == null) rethrow; // never synced: a real error
///     return cached.map(Note.fromJson).toList();
///   }
/// }
/// ```
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

class JsonCache {
  JsonCache(this._db, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final Database _db;
  final DateTime Function() _now;

  static const _items = 'cache_items';
  static const _meta = 'cache_meta';

  /// Call from `openDatabase(onCreate: …)`.
  static Future<void> createTables(DatabaseExecutor db) async {
    await db.execute('''
      create table if not exists $_items (
        user_id   text    not null,
        cache_key text    not null,
        item_id   text    not null,
        position  integer not null,
        json      text    not null,
        primary key (user_id, cache_key, item_id)
      )
    ''');
    await db.execute('''
      create table if not exists $_meta (
        user_id   text not null,
        cache_key text not null,
        synced_at text not null,
        primary key (user_id, cache_key)
      )
    ''');
  }

  /// Replaces the cached collection [key] for [userId] with [items], in
  /// order. [idOf] picks each item's id (default: its `'id'` field, falling
  /// back to its position).
  ///
  /// Never throws: a cache write mirrors a fetch that already succeeded, so
  /// its failure is logged rather than shown as if the fetch had failed.
  Future<void> saveCollection(
    String userId,
    String key,
    List<Map<String, dynamic>> items, {
    String Function(Map<String, dynamic> item)? idOf,
  }) async {
    try {
      await _db.transaction((txn) async {
        await txn.delete(
          _items,
          where: 'user_id = ? and cache_key = ?',
          whereArgs: [userId, key],
        );
        final batch = txn.batch();
        for (var i = 0; i < items.length; i++) {
          final item = items[i];
          batch.insert(_items, {
            'user_id': userId,
            'cache_key': key,
            'item_id': idOf?.call(item) ?? '${item['id'] ?? i}',
            'position': i,
            'json': jsonEncode(item),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
        await _markSynced(txn, userId, key);
      });
    } catch (error) {
      debugPrint('JsonCache: could not save "$key": $error');
    }
  }

  /// The cached collection in saved order, or null if it was never saved.
  Future<List<Map<String, dynamic>>?> loadCollection(
    String userId,
    String key,
  ) async {
    if (await syncedAt(userId, key) == null) return null;
    final rows = await _db.query(
      _items,
      columns: ['json'],
      where: 'user_id = ? and cache_key = ?',
      whereArgs: [userId, key],
      orderBy: 'position asc',
    );
    return [
      for (final row in rows)
        jsonDecode(row['json']! as String) as Map<String, dynamic>,
    ];
  }

  /// Caches one item (e.g. a detail page) under [key]/[itemId] without
  /// touching the rest of the collection.
  Future<void> saveItem(
    String userId,
    String key,
    String itemId,
    Map<String, dynamic> item,
  ) async {
    try {
      await _db.transaction((txn) async {
        await txn.insert(_items, {
          'user_id': userId,
          'cache_key': key,
          'item_id': itemId,
          'position': 0,
          'json': jsonEncode(item),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await _markSynced(txn, userId, '$key/$itemId');
      });
    } catch (error) {
      debugPrint('JsonCache: could not save "$key/$itemId": $error');
    }
  }

  Future<Map<String, dynamic>?> loadItem(
    String userId,
    String key,
    String itemId,
  ) async {
    final rows = await _db.query(
      _items,
      columns: ['json'],
      where: 'user_id = ? and cache_key = ? and item_id = ?',
      whereArgs: [userId, key, itemId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['json']! as String) as Map<String, dynamic>;
  }

  /// When [key] was last saved for [userId]; null if never. For a single
  /// item pass `'$key/$itemId'`.
  Future<DateTime?> syncedAt(String userId, String key) async {
    final rows = await _db.query(
      _meta,
      columns: ['synced_at'],
      where: 'user_id = ? and cache_key = ?',
      whereArgs: [userId, key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['synced_at']! as String);
  }

  /// Deletes everything cached for [userId]. Call on sign-out and on
  /// account deletion.
  Future<void> clearUser(String userId) => _db.transaction((txn) async {
    await txn.delete(_items, where: 'user_id = ?', whereArgs: [userId]);
    await txn.delete(_meta, where: 'user_id = ?', whereArgs: [userId]);
  });

  Future<void> _markSynced(Transaction txn, String userId, String key) =>
      txn.insert(_meta, {
        'user_id': userId,
        'cache_key': key,
        'synced_at': _now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
}
