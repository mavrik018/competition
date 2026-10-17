/// Typed keys over `SharedPreferences`, plus JSON objects, so settings code
/// reads `prefs.get(Prefs.onboardingDone)` instead of repeating string keys
/// and defaults at every call site.
///
/// Newly written. Every source app called `SharedPreferences.getInstance()`
/// inline with string keys (`'onboarding_completed'`, `'is_dark_mode'`,
/// `'streak_last_used_date'`…), and the defaults were repeated wherever a key
/// was read.
///
/// ```dart
/// abstract final class Prefs {
///   static const onboardingDone = PrefKey<bool>('onboarding_done', false);
///   static const userName = PrefKey<String>('user_name', '');
/// }
///
/// // main.dart
/// final prefs = await SharedPreferences.getInstance();
/// runApp(ProviderScope(
///   overrides: [prefsStoreProvider.overrideWithValue(PrefsStore(prefs))],
///   child: const App(),
/// ));
///
/// // anywhere
/// final store = ref.read(prefsStoreProvider);
/// if (!store.get(Prefs.onboardingDone)) …
/// await store.set(Prefs.onboardingDone, true);
/// ```
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A preference name, its type and its default. Supported types: bool, int,
/// double, String and `List<String>`.
class PrefKey<T> {
  const PrefKey(this.name, this.defaultValue);

  final String name;
  final T defaultValue;
}

class PrefsStore {
  PrefsStore(this._prefs);

  final SharedPreferences _prefs;

  /// The stored value, or the key's default when missing or of the wrong
  /// type (e.g. after a key was reused with a different type).
  T get<T>(PrefKey<T> key) {
    final Object? raw = _prefs.get(key.name);
    if (raw is List) {
      // SharedPreferences returns List<Object?>; narrow it for List<String>.
      final strings = raw.whereType<String>().toList();
      return strings is T ? strings as T : key.defaultValue;
    }
    return raw is T ? raw : key.defaultValue;
  }

  Future<void> set<T>(PrefKey<T> key, T value) async {
    final name = key.name;
    final ok = switch (value) {
      final bool v => await _prefs.setBool(name, v),
      final int v => await _prefs.setInt(name, v),
      final double v => await _prefs.setDouble(name, v),
      final String v => await _prefs.setString(name, v),
      final List<String> v => await _prefs.setStringList(name, v),
      _ => throw ArgumentError(
        'Unsupported preference type ${value.runtimeType}',
      ),
    };
    if (!ok) throw StateError('Could not save preference "$name"');
  }

  Future<void> remove(PrefKey<Object?> key) => _prefs.remove(key.name);

  bool contains(PrefKey<Object?> key) => _prefs.containsKey(key.name);

  /// A JSON object stored as a string. Returns null when missing or not
  /// valid JSON (corrupt data is treated as absent, never thrown).
  Map<String, dynamic>? getJson(String name) {
    final raw = _prefs.getString(name);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> setJson(String name, Map<String, dynamic> value) =>
      _prefs.setString(name, jsonEncode(value));
}

/// Override in `main()` with an instance built from
/// `await SharedPreferences.getInstance()`, so reads are synchronous.
final prefsStoreProvider = Provider<PrefsStore>(
  (ref) => throw UnimplementedError(
    'Override prefsStoreProvider with PrefsStore(await SharedPreferences.getInstance()).',
  ),
);
