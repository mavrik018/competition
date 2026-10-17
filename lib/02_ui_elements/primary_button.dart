import 'package:flutter/material.dart';

import '../01_design_system/app_tokens.dart';

/// Full-width call-to-action button with loading, disabled and destructive
/// states.
///
/// Source: StudyBuddies `SMButton` (explicit disabled styling, inline
/// spinner) merged with `IosPrimaryButton` / `CooklyPrimaryButton`
/// (destructive variant). Colours come from the theme's [ColorScheme].
///
/// ```dart
/// PrimaryButton(
///   label: 'Save',
///   isLoading: saving,
///   onPressed: canSave ? save : null,
/// )
/// ```
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.destructive = false,
    this.icon,
    this.expand = true,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// Shows a spinner in place of the label and ignores taps, while keeping
  /// the button's enabled colour so it does not look disabled mid-request.
  final bool isLoading;

  /// Uses the error colour — for delete / sign-out style actions.
  final bool destructive;
  final IconData? icon;

  /// Stretch to the available width (default) or hug the label.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = destructive ? scheme.error : scheme.primary;
    final foreground = destructive ? scheme.onError : scheme.onPrimary;

    final Widget content = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: foreground,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: Gap.sm),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    final button = FilledButton(
      // Loading disables taps (no double submit) but keeps the enabled
      // colours, so the button does not look greyed out mid-request.
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: isLoading ? background : null,
        disabledForegroundColor: isLoading ? foreground : null,
        minimumSize: const Size(64, 52),
      ),
      child: content,
    );

    return Semantics(
      liveRegion: isLoading,
      label: isLoading ? '$label, loading' : null,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}
