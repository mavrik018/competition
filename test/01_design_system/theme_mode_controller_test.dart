import 'package:competition_toolkit/01_design_system/theme_mode_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container(Map<String, Object> saved) async {
  SharedPreferences.setMockInitialValues(saved);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('starts on system and then loads the saved mode', () async {
    final container = await _container({'theme_mode': 'dark'});
    expect(container.read(themeModeProvider), ThemeMode.system);
    await _settle();
    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  test('setMode applies immediately and persists', () async {
    final container = await _container({});
    await container.read(themeModeProvider.notifier).setMode(ThemeMode.light);
    expect(container.read(themeModeProvider), ThemeMode.light);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ThemeModeController.storageKey), 'light');
  });

  test(
    'a choice made before the saved value loads is not overwritten',
    () async {
      final container = await _container({'theme_mode': 'dark'});
      final notifier = container.read(themeModeProvider.notifier);
      final pending = notifier.setMode(ThemeMode.light);
      await _settle();
      await pending;
      expect(container.read(themeModeProvider), ThemeMode.light);
    },
  );

  test('toggle from system flips what the platform is showing', () async {
    final container = await _container({});
    await _settle();
    await container.read(themeModeProvider.notifier).toggle(Brightness.dark);
    expect(container.read(themeModeProvider), ThemeMode.light);
    await container.read(themeModeProvider.notifier).toggle(Brightness.dark);
    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  test('parse ignores unknown values', () {
    expect(ThemeModeController.parse('dark'), ThemeMode.dark);
    expect(ThemeModeController.parse('purple'), isNull);
    expect(ThemeModeController.parse(null), isNull);
  });
}
