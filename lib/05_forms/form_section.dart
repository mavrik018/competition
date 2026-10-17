/// Grouped, inset form rows in the iOS "Settings" style: a rounded card of
/// rows separated by hairlines, with an optional header above and footer
/// below.
///
/// Source: StudyBuddies `IosFormSection`, `IosFormRow`, `IosValuePill`,
/// `IosTextFieldRow` (`core/widgets/ios_ui.dart`) and their Cookly ports.
/// The card is a [Material] so rows can use ink ripples, and colours come
/// from the theme.
///
/// ```dart
/// FormSection(
///   header: 'Account',
///   footer: 'Your email is never shown to other users.',
///   children: [
///     FormRowTile(label: 'Email', value: user.email, valueAsPill: false),
///     FormRowTile(label: 'Notifications', trailing: Switch(value: on, onChanged: setOn)),
///     FormRowTile(label: 'Privacy policy', showChevron: true, onTap: openPrivacy),
///     TextFieldRow(controller: nameController, label: 'Name', placeholder: 'Your name'),
///   ],
/// )
/// ```
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../01_design_system/app_tokens.dart';

class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.margin = EdgeInsets.zero,
  });

  final List<Widget> children;

  /// Shown in small caps above the card.
  final String? header;

  /// Explanatory note under the card.
  final String? footer;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final caption = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
              child: Semantics(
                header: true,
                child: Text(
                  header!.toUpperCase(),
                  style: caption?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          Material(
            color: scheme.surfaceContainerLowest,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.md),
              side: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const Divider(indent: 16),
                  children[i],
                ],
              ],
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(footer!, style: caption),
            ),
        ],
      ),
    );
  }
}

/// One row: a label on the left and a value, a control, or a chevron on the
/// right.
class FormRowTile extends StatelessWidget {
  const FormRowTile({
    super.key,
    required this.label,
    this.value,
    this.trailing,
    this.leading,
    this.onTap,
    this.showChevron = false,
    this.valueAsPill = true,
    this.destructive = false,
  });

  final String label;

  /// Right-aligned value text, as a tinted pill when [valueAsPill].
  final String? value;

  /// A custom right-hand widget (switch, badge…); takes precedence over
  /// [value].
  final Widget? trailing;
  final Widget? leading;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool valueAsPill;

  /// Shows the label in the error colour — for "Delete account" rows.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: Gap.md - 4)],
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: destructive ? scheme.error : null,
              ),
            ),
          ),
          if (trailing != null)
            Flexible(child: trailing!)
          else if (value != null)
            Flexible(
              child: valueAsPill
                  ? ValuePill(text: value!)
                  : Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
            ),
          if (showChevron) ...[
            const SizedBox(width: 6),
            Icon(
              CupertinoIcons.chevron_right,
              size: 15,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ],
        ],
      ),
    );

    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

/// The tinted rounded chip used for values on the right of a row.
class ValuePill extends StatelessWidget {
  const ValuePill({super.key, required this.text, this.highlighted = false});

  final String text;

  /// Primary-coloured text, the way an actively edited field looks.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted
            ? scheme.primary.withValues(alpha: 0.12)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w500,
          color: highlighted ? scheme.primary : scheme.onSurface,
        ),
      ),
    );
  }
}

/// A borderless text field laid out as a form row, with an optional fixed
/// label column.
class TextFieldRow extends StatelessWidget {
  const TextFieldRow({
    super.key,
    required this.controller,
    required this.placeholder,
    this.label,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.autofocus = false,
    this.onChanged,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final TextEditingController controller;
  final String placeholder;
  final String? label;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final field = TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      autofocus: autofocus,
      onChanged: onChanged,
      textCapitalization: textCapitalization,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        isDense: true,
        filled: false,
        counterText: '',
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintText: placeholder,
        labelText: null,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: label == null
          ? field
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 96,
                  child: Text(label!, style: theme.textTheme.bodyLarge),
                ),
                Expanded(child: field),
              ],
            ),
    );
  }
}
