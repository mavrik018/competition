// App shell: theme, light/dark mode and the three tabs.
//
// Change the palette (AppPalette.studyBlue / kitchenWarm / coupleNavy /
// taskIndigo) to restyle every component at once.

import 'package:{{app_name}}/toolkit/01_design_system/app_palette.dart';
import 'package:{{app_name}}/toolkit/01_design_system/app_theme.dart';
import 'package:{{app_name}}/toolkit/01_design_system/theme_mode_controller.dart';
import 'package:{{app_name}}/toolkit/07_navigation/tab_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/home/home_screen.dart';
import 'features/items/items_screen.dart';
import 'features/settings/settings_screen.dart';

class App extends ConsumerWidget {
  const App({super.key});

  static const palette = AppPalette.studyBlue;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    title: '{{app_title}}',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.build(palette, Brightness.light),
    darkTheme: AppTheme.build(palette, Brightness.dark),
    themeMode: ref.watch(themeModeProvider),
    home: TabShell(
      destinations: [
        TabDestination(
          label: 'Home',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          builder: (_) => const HomeScreen(),
        ),
        TabDestination(
          label: 'Items',
          icon: Icons.checklist_outlined,
          selectedIcon: Icons.checklist,
          builder: (_) => const ItemsScreen(),
        ),
        TabDestination(
          label: 'Settings',
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings,
          builder: (_) => const SettingsScreen(),
        ),
      ],
    ),
  );
}
