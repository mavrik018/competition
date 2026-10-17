import 'package:{{app_name}}/toolkit/01_design_system/theme_mode_controller.dart';
import 'package:{{app_name}}/toolkit/03_feedback/app_snackbars.dart';
import 'package:{{app_name}}/toolkit/04_dialogs_and_sheets/alerts.dart';
import 'package:{{app_name}}/toolkit/06_screen_templates/settings_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../items/item.dart';
import '../items/items_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _deleteAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppConfirm(
      context,
      title: 'Delete all items?',
      message: 'This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    final controller = ref.read(itemsProvider.notifier);
    for (final item in ref.read(itemsProvider).value ?? const <Item>[]) {
      await controller.delete(item.id);
    }
    if (context.mounted) context.showSuccess('All items deleted');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => SettingsTemplate(
    groups: [
      SettingsGroup(
        title: 'Appearance',
        items: [
          SettingsChoice<ThemeMode>(
            label: 'Theme',
            icon: Icons.palette_outlined,
            value: ref.watch(themeModeProvider),
            options: const {
              ThemeMode.system: 'System',
              ThemeMode.light: 'Light',
              ThemeMode.dark: 'Dark',
            },
            onChanged: (mode) =>
                ref.read(themeModeProvider.notifier).setMode(mode),
          ),
        ],
      ),
      SettingsGroup(
        title: 'Data',
        footer: 'Items are stored on this device.',
        items: [
          SettingsAction(
            label: 'Delete all items',
            icon: Icons.delete_outline,
            destructive: true,
            onTap: () => _deleteAll(context, ref),
          ),
        ],
      ),
    ],
  );
}
