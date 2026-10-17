/// `Repository<T>` stored as one JSON list in shared preferences. Works on
/// **every** platform — including the web, where SQLite does not — with no
/// setup, which makes it the fastest way to get real persistence into a
/// competition prototype.
///
/// **Small data only.** The whole list is rewritten on every save, and the
/// shared_preferences documentation warns that writes are not guaranteed to
/// be on disk when the call returns, so it "must not be used for storing
/// critical data". Fine for a few hundred settings-sized records (a to-do
/// list, favourites, a habit log); switch to `SqfliteRepository` or a
/// backend repository for more, or for data you cannot afford to lose.
///
/// ```dart
/// final notes = PrefsRepository<Note>(
///   key: 'notes',
///   idOf: (n) => n.id,
///   toJson: (n) => n.toJson(),
///   fromJson: Note.fromJson,
/// );
/// await notes.save(note);           // survives restarts, on any platform
/// ```
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'repository.dart';

class PrefsRepository<T> implements Repository<T> {
  PrefsRepository({
    required this.key,
    required this.idOf,
    required this.toJson,
    required this.fromJson,
    SharedPreferencesAsync? prefs,
  }) : _prefs = prefs ?? SharedPreferencesAsync();

  /// The preferences key holding this collection — one per entity type.
  final String key;
  final String Function(T item) idOf;
  final Map<String, Object?> Function(T item) toJson;
  final T Function(Map<String, Object?> json) fromJson;

  final SharedPreferencesAsync _prefs;
  final _changes = StreamController<List<T>>.broadcast();

  /// Loaded once, then kept in memory: this repository is the only writer
  /// of its key.
  Map<String, T>? _items;

  Future<Map<String, T>> _load() async {
    final cached = _items;
    if (cached != null) return cached;
    final items = <String, T>{};
    final raw = await _prefs.getString(key);
    if (raw != null) {
      try {
        for (final entry in jsonDecode(raw) as List) {
          try {
            final item = fromJson((entry as Map).cast<String, Object?>());
            items[idOf(item)] = item;
          } catch (e) {
            debugPrint('PrefsRepository($key): skipped an unreadable item: $e');
          }
        }
      } catch (e) {
        debugPrint('PrefsRepository($key): stored data is not a JSON list: $e');
      }
    }
    return _items = items;
  }

  Future<void> _write(Map<String, T> items) async {
    await _prefs.setString(
      key,
      jsonEncode([for (final item in items.values) toJson(item)]),
    );
    _changes.add(List.unmodifiable(items.values));
  }

  @override
  Future<List<T>> getAll() async => List.unmodifiable((await _load()).values);

  @override
  Future<T?> getById(String id) async => (await _load())[id];

  @override
  Stream<List<T>> watchAll() => watchList(_changes, getAll);

  /// Updates keep the item's position; new items are appended.
  @override
  Future<void> save(T item) async {
    final items = await _load();
    items[idOf(item)] = item;
    await _write(items);
  }

  @override
  Future<void> delete(String id) async {
    final items = await _load();
    if (items.remove(id) != null) await _write(items);
  }

  /// Removes the whole collection (e.g. on sign-out).
  Future<void> clear() async {
    _items = {};
    await _prefs.remove(key);
    _changes.add(const []);
  }
}
