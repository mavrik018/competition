import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's light / dark / system choice, persisted across launches.
///
/// Source: StudyBuddies `theme_provider.dart` (`ThemeModeNotifier`), moved
/// from the legacy `StateNotifier` to a Riverpod 3 [Notifier]. TaskFlow stored
/// only a bool, which cannot express "follow the system".
///
/// ```dart
/// final mode = ref.watch(themeModeProvider);
/// ref.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
/// ```
class ThemeModeController extends Notifier<ThemeMode> {
  static const storageKey = 'theme_mode';

  /// Set once the user picks a mode, so a slow initial read can never
  /// overwrite a choice made while it was in flight.
  bool _changedByUser = false;

  @override
  ThemeMode build() {
    _load();
    // Shown until the saved value arrives (normally before the first frame
    // finishes). "system" is the least surprising default.
    return ThemeMode.system;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = parse(prefs.getString(storageKey));
      if (saved != null && !_changedByUser) state = saved;
    } catch (error) {
      debugPrint('ThemeModeController: could not read saved mode: $error');
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    _changedByUser = true;
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, mode.name);
    } catch (error) {
      // The mode still applies for this session; it just won't survive a
      // restart. Not worth interrupting the user over.
      debugPrint('ThemeModeController: could not save mode: $error');
    }
  }

  /// Light ↔ dark. From "system", flips to the opposite of what the platform
  /// is currently showing.
  Future<void> toggle(Brightness platformBrightness) {
    final showingDark =
        state == ThemeMode.dark ||
        (state == ThemeMode.system && platformBrightness == Brightness.dark);
    return setMode(showingDark ? ThemeMode.light : ThemeMode.dark);
  }

  /// Parses a stored value. Unknown or missing values return null.
  @visibleForTesting
  static ThemeMode? parse(String? value) {
    for (final mode in ThemeMode.values) {
      if (mode.name == value) return mode;
    }
    return null;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
