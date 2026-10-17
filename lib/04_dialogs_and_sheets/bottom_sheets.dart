/// A general-purpose modal bottom sheet: title, scrollable content, sticky
/// action buttons, keyboard-aware, capped height, tablet-width limit.
///
/// Newly written. `showPickerSheet` covers "choose one option"; this covers
/// everything else the source apps hand-built with `showModalBottomSheet`
/// (Cookly's pantry and shopping sheets, StudyBuddies' course picker and
/// detail-level sheet), each re-solving the same three problems: the
/// keyboard covering fields, content taller than the screen, and sheets
/// stretching across tablets.
///
/// ```dart
/// final saved = await showAppBottomSheet<bool>(
///   context,
///   title: 'Add item',
///   builder: (sheetContext) => AddItemForm(onSaved: () => Navigator.pop(sheetContext, true)),
/// );
///
/// await showAppBottomSheet<void>(
///   context,
///   title: 'Filters',
///   builder: (_) => FiltersList(),
///   actions: (sheetContext) => [
///     AppButton(label: 'Reset', variant: ButtonVariant.text, onPressed: reset),
///     AppButton(label: 'Apply', onPressed: () => Navigator.pop(sheetContext)),
///   ],
/// );
/// ```
library;

import 'package:flutter/material.dart';

import '../01_design_system/app_tokens.dart';

/// Resolves to whatever the sheet pops with (null when dragged away).
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  List<Widget> Function(BuildContext sheetContext)? actions,
  double maxHeightFraction = 0.9,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    useSafeArea: true,
    showDragHandle: true,
    constraints: BoxConstraints(
      maxWidth: 640,
      maxHeight: MediaQuery.sizeOf(context).height * maxHeightFraction,
    ),
    builder: (sheetContext) => Padding(
      // Lift everything above the on-screen keyboard.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.gutter,
                0,
                Gap.gutter,
                Gap.md - 4,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
            ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: Gap.gutter),
              child: builder(sheetContext),
            ),
          ),
          if (actions != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.gutter,
                  Gap.md - 4,
                  Gap.gutter,
                  Gap.md,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  spacing: Gap.sm,
                  children: actions(sheetContext),
                ),
              ),
            )
          else
            const SizedBox(height: Gap.lg),
        ],
      ),
    ),
  );
}
