/// A settings screen described as data: groups of toggles, choices, links
/// and actions, rendered as iOS-style grouped rows.
///
/// Source: TaskFlow `settings_screen.dart` (592 lines) and Couple
/// `settings_page.dart`, which hand-built every row. Here a settings page is
/// a list of items; choices open `showPickerSheet` automatically.
///
/// ```dart
/// SettingsTemplate(groups: [
///   SettingsGroup(title: 'Appearance', items: [
///     SettingsChoice<ThemeMode>(
///       label: 'Theme', icon: Icons.palette_outlined,
///       value: ref.watch(themeModeProvider),
///       options: const {ThemeMode.system: 'System', ThemeMode.light: 'Light', ThemeMode.dark: 'Dark'},
///       onChanged: (m) => ref.read(themeModeProvider.notifier).setMode(m),
///     ),
///   ]),
///   SettingsGroup(title: 'Notifications', items: [
///     SettingsToggle(label: 'Daily reminder', value: on, onChanged: setOn, icon: Icons.alarm),
///   ]),
///   SettingsGroup(items: [
///     SettingsLink(label: 'Privacy policy', onTap: openPrivacy),
///     SettingsAction(label: 'Sign out', onTap: signOut, destructive: true),
///   ], footer: 'Version 1.0.0'),
/// ])
/// ```
library;

import 'package:flutter/material.dart';

import '../01_design_system/app_tokens.dart';
import '../04_dialogs_and_sheets/picker_sheet.dart';
import '../05_forms/form_section.dart';

sealed class SettingsItem {
  const SettingsItem({required this.label, this.icon, this.subtitle});
  final String label;
  final IconData? icon;
  final String? subtitle;
}

class SettingsToggle extends SettingsItem {
  const SettingsToggle({
    required super.label,
    required this.value,
    required this.onChanged,
    super.icon,
    super.subtitle,
  });
  final bool value;

  /// Null disables the switch.
  final ValueChanged<bool>? onChanged;
}

class SettingsChoice<T> extends SettingsItem {
  const SettingsChoice({
    required super.label,
    required this.value,
    required this.options,
    required this.onChanged,
    super.icon,
    super.subtitle,
  });
  final T value;

  /// Ordered value → label.
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  String? get valueLabel => options[value];

  /// Opens a picker sheet and reports the choice. Lives here (not in the
  /// row widget) so `T` is the real type when [onChanged] is called — a
  /// `SettingsChoice<String>` seen as `SettingsChoice<dynamic>` would fail
  /// Dart's runtime type check on its callback.
  Future<void> choose(BuildContext context) async {
    final picked = await showPickerSheet<T>(
      context,
      title: label,
      selected: value,
      options: [
        for (final entry in options.entries)
          PickerOption<T>(value: entry.key, label: entry.value),
      ],
    );
    if (picked != null) onChanged(picked);
  }
}

class SettingsLink extends SettingsItem {
  const SettingsLink({
    required super.label,
    required this.onTap,
    this.value,
    super.icon,
    super.subtitle,
  });
  final VoidCallback onTap;

  /// Shown on the right, e.g. the current language.
  final String? value;
}

class SettingsAction extends SettingsItem {
  const SettingsAction({
    required super.label,
    required this.onTap,
    this.destructive = false,
    super.icon,
    super.subtitle,
  });
  final VoidCallback onTap;
  final bool destructive;
}

class SettingsGroup {
  const SettingsGroup({required this.items, this.title, this.footer});
  final String? title;
  final String? footer;
  final List<SettingsItem> items;
}

class SettingsTemplate extends StatelessWidget {
  const SettingsTemplate({
    super.key,
    required this.groups,
    this.title = 'Settings',
  });

  final List<SettingsGroup> groups;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.xl),
        children: [
          for (final group in groups)
            FormSection(
              header: group.title,
              footer: group.footer,
              margin: const EdgeInsets.only(bottom: Gap.lg),
              children: [for (final item in group.items) _row(context, item)],
            ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, SettingsItem item) {
    final leading = item.icon == null ? null : Icon(item.icon, size: 22);
    final label = item.subtitle == null
        ? item.label
        : '${item.label}\n${item.subtitle}';
    return switch (item) {
      SettingsToggle() => MergeSemantics(
        child: FormRowTile(
          label: label,
          leading: leading,
          onTap: item.onChanged == null
              ? null
              : () => item.onChanged!(!item.value),
          trailing: Switch(value: item.value, onChanged: item.onChanged),
        ),
      ),
      SettingsChoice() => _ChoiceRow(
        item: item,
        label: label,
        leading: leading,
      ),
      SettingsLink() => FormRowTile(
        label: label,
        leading: leading,
        value: item.value,
        valueAsPill: false,
        showChevron: true,
        onTap: item.onTap,
      ),
      SettingsAction() => FormRowTile(
        label: label,
        leading: leading,
        destructive: item.destructive,
        onTap: item.onTap,
      ),
    };
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.item,
    required this.label,
    required this.leading,
  });

  final SettingsChoice<Object?> item;
  final String label;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return FormRowTile(
      label: label,
      leading: leading,
      value: item.valueLabel,
      valueAsPill: false,
      showChevron: true,
      onTap: () => item.choose(context),
    );
  }
}
