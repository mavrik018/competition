/// Centred alert cards in the iOS style — title, message, optional content,
/// and a row (or stack) of actions — that work on every platform.
///
/// Source: StudyBuddies `core/widgets/ios_ui.dart` (`showIosAlert`,
/// `showIosConfirm`, `showIosMessage`, `showIosTextPrompt`), which Cookly
/// ported as `showCooklyAlert…`. Apple system blue/red were replaced by the
/// theme's primary and error colours, and screenutil sizing by fixed sizes.
///
/// ```dart
/// final ok = await showAppConfirm(
///   context,
///   title: 'Delete note?',
///   message: 'This cannot be undone.',
///   confirmLabel: 'Delete',
///   destructive: true,
/// );
/// if (ok) await repo.delete(note);
/// ```
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../01_design_system/app_tokens.dart';

/// Visual weight of an [AlertAction].
enum AlertActionStyle { normal, primary, destructive }

/// One button in an alert.
class AlertAction {
  const AlertAction({
    required this.label,
    this.onPressed,
    this.style = AlertActionStyle.normal,
  });

  final String label;

  /// Runs *after* the alert has closed, so it never works with a stale
  /// dialog context.
  final VoidCallback? onPressed;
  final AlertActionStyle style;
}

/// Shows an alert and resolves to the tapped action's index, or null when
/// dismissed by tapping outside.
///
/// Two short actions sit side by side; anything else stacks vertically.
Future<int?> showAppAlert(
  BuildContext context, {
  required String title,
  String? message,
  Widget? content,
  List<AlertAction> actions = const [],
  bool barrierDismissible = true,
}) {
  final resolved = actions.isEmpty
      ? const [AlertAction(label: 'OK', style: AlertActionStyle.primary)]
      : actions;

  return showGeneralDialog<int>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: title,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    transitionDuration: Motion.short,
    pageBuilder: (_, _, _) => _AlertCard(
      title: title,
      message: message,
      content: content,
      actions: resolved,
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      );
      // Springs in from 92% like the native alert.
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// A single-button informational alert.
Future<void> showAppMessage(
  BuildContext context, {
  required String title,
  String? message,
  String buttonLabel = 'OK',
  bool barrierDismissible = true,
}) => showAppAlert(
  context,
  title: title,
  message: message,
  barrierDismissible: barrierDismissible,
  actions: [AlertAction(label: buttonLabel, style: AlertActionStyle.primary)],
);

/// Resolves to true only when the confirm action is tapped.
Future<bool> showAppConfirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final index = await showAppAlert(
    context,
    title: title,
    message: message,
    actions: [
      AlertAction(label: cancelLabel),
      AlertAction(
        label: confirmLabel,
        style: destructive
            ? AlertActionStyle.destructive
            : AlertActionStyle.primary,
      ),
    ],
  );
  return index == 1;
}

/// An alert with one text field. Resolves to the trimmed text, or null when
/// cancelled.
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  String? message,
  String initialValue = '',
  String? placeholder,
  String? suffix,
  TextInputType keyboardType = TextInputType.text,
  String confirmLabel = 'Done',
  String cancelLabel = 'Cancel',
}) async {
  // The text is mirrored out through onChanged rather than read from a
  // controller owned here: a controller disposed when this future completes
  // would still be used by the closing animation, which throws
  // "A TextEditingController was used after being disposed" (seen in source).
  var current = initialValue;
  String? result;
  await showAppAlert(
    context,
    title: title,
    message: message,
    content: AlertTextField(
      initialValue: initialValue,
      placeholder: placeholder,
      suffix: suffix,
      keyboardType: keyboardType,
      autofocus: true,
      onChanged: (value) => current = value,
    ),
    actions: [
      AlertAction(label: cancelLabel),
      AlertAction(
        label: confirmLabel,
        style: AlertActionStyle.primary,
        onPressed: () => result = current.trim(),
      ),
    ],
  );
  return result;
}

/// A borderless text field for the `content` slot of [showAppAlert]. It owns
/// and disposes its own controller; read the value through [onChanged].
class AlertTextField extends StatefulWidget {
  const AlertTextField({
    super.key,
    required this.onChanged,
    this.initialValue = '',
    this.placeholder,
    this.suffix,
    this.keyboardType,
    this.autofocus = false,
  });

  final ValueChanged<String> onChanged;
  final String initialValue;
  final String? placeholder;
  final String? suffix;
  final TextInputType? keyboardType;
  final bool autofocus;

  @override
  State<AlertTextField> createState() => _AlertTextFieldState();
}

class _AlertTextFieldState extends State<AlertTextField> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      keyboardType: widget.keyboardType,
      textCapitalization: TextCapitalization.sentences,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        isDense: true,
        filled: false,
        hintText: widget.placeholder,
        suffixText: widget.suffix,
        // Just a hairline under the text, so it reads as part of the alert.
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.primary),
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.title,
    required this.message,
    required this.content,
    required this.actions,
  });

  final String title;
  final String? message;
  final Widget? content;
  final List<AlertAction> actions;

  void _tap(BuildContext context, int index) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(index);
    actions[index].onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final divider = Container(color: scheme.outlineVariant, height: 0.5);
    final sideBySide =
        actions.length == 2 && actions.every((a) => a.label.length <= 14);

    Widget button(int i) =>
        _AlertButton(action: actions[i], onTap: () => _tap(context, i));

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Material(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(Radii.lg),
          clipBehavior: Clip.antiAlias,
          elevation: 12,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 300,
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                    child: Column(
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (message != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            message!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (content != null) ...[
                          const SizedBox(height: 14),
                          content!,
                        ],
                      ],
                    ),
                  ),
                ),
                divider,
                if (sideBySide)
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(child: button(0)),
                        Container(color: scheme.outlineVariant, width: 0.5),
                        Expanded(child: button(1)),
                      ],
                    ),
                  )
                else
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) divider,
                    button(i),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AlertButton extends StatelessWidget {
  const _AlertButton({required this.action, required this.onTap});

  final AlertAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = action.style == AlertActionStyle.destructive
        ? scheme.error
        : scheme.primary;

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      minimumSize: const Size(0, 46),
      borderRadius: BorderRadius.zero,
      onPressed: onTap,
      child: Text(
        action.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: color,
          fontWeight: action.style == AlertActionStyle.normal
              ? FontWeight.w400
              : FontWeight.w600,
        ),
      ),
    );
  }
}
