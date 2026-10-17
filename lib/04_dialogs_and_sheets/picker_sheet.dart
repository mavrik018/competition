/// A bottom action sheet for picking one value from a list — the
/// replacement for dropdowns and popup menus — plus the grabber bar for the
/// top of custom sheets.
///
/// Source: StudyBuddies `showIosPicker` / `IosSheetGrabber`
/// (`core/widgets/ios_ui.dart`) and the Cookly port (`showCooklyPicker`,
/// `SheetGrabber`). `TabletFrame` was replaced by a plain max-width
/// constraint, and colours come from the theme.
///
/// ```dart
/// final sort = await showPickerSheet<SortOrder>(
///   context,
///   title: 'Sort by',
///   selected: currentSort,
///   options: const [
///     PickerOption(value: SortOrder.newest, label: 'Newest first', icon: Icons.schedule),
///     PickerOption(value: SortOrder.title, label: 'Title', icon: Icons.sort_by_alpha),
///   ],
/// );
/// if (sort != null) setSort(sort);
/// ```
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../01_design_system/app_tokens.dart';

/// One selectable row in [showPickerSheet].
class PickerOption<T> {
  const PickerOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.isDestructive = false,
  });

  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool isDestructive;
}

/// Shows the sheet and resolves to the chosen value, or null if cancelled.
///
/// The [selected] value is ticked. The list grows to at most 60% of the
/// screen height before scrolling.
Future<T?> showPickerSheet<T>(
  BuildContext context, {
  required List<PickerOption<T>> options,
  T? selected,
  String? title,
  String? message,
  String cancelLabel = 'Cancel',
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    showDragHandle: false,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (sheetContext) => Center(
      heightFactor: 1,
      child: ConstrainedBox(
        // Keeps the sheet phone-width on tablets.
        constraints: const BoxConstraints(maxWidth: 540),
        child: _PickerSheet<T>(
          options: options,
          selected: selected,
          title: title,
          message: message,
          cancelLabel: cancelLabel,
        ),
      ),
    ),
  );
}

class _PickerSheet<T> extends StatelessWidget {
  const _PickerSheet({
    required this.options,
    required this.selected,
    required this.title,
    required this.message,
    required this.cancelLabel,
  });

  final List<PickerOption<T>> options;
  final T? selected;
  final String? title;
  final String? message;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final card = scheme.surfaceContainerLow;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.6,
              ),
              // A Material (not a decorated Container) so row ink splashes
              // paint on top of the card colour instead of underneath it.
              child: Material(
                color: card,
                borderRadius: BorderRadius.circular(Radii.lg - 2),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null || message != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Column(
                          children: [
                            if (title != null)
                              Text(
                                title!,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleSmall,
                              ),
                            if (message != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                message!,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (title != null || message != null) const Divider(),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: options.length,
                        separatorBuilder: (_, _) => const Divider(indent: 20),
                        itemBuilder: (context, i) =>
                            _optionRow(context, options[i]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Gap.sm),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 14),
                borderRadius: BorderRadius.circular(Radii.lg - 2),
                color: card,
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  cancelLabel,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionRow(BuildContext context, PickerOption<T> option) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isSelected = option.value == selected;
    final color = option.isDestructive ? scheme.error : scheme.onSurface;

    return Semantics(
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).pop(option.value);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              if (option.icon != null) ...[
                Icon(
                  option.icon,
                  size: 20,
                  color: option.isDestructive
                      ? scheme.error
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: Gap.md - 4),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: color,
                        fontWeight: isSelected ? FontWeight.w600 : null,
                      ),
                    ),
                    if (option.subtitle != null)
                      Text(
                        option.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  CupertinoIcons.check_mark,
                  size: 18,
                  color: scheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The small rounded bar at the top of a custom modal sheet.
class SheetGrabber extends StatelessWidget {
  const SheetGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 5,
        margin: const EdgeInsets.only(top: 8, bottom: 10),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
