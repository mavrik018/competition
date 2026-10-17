/// Blocking progress for actions that must finish before the user does
/// anything else (payment, upload, sign-out), plus an inline status banner
/// for messages that should stay on screen.
///
/// Newly written. The source apps showed ad-hoc `showDialog(barrierDismissible:
/// false, …CircularProgressIndicator…)` spinners that were sometimes never
/// popped on error; [runWithLoading] always closes in a `finally`.
///
/// ```dart
/// final receipt = await runWithLoading(context, () => payments.charge(cart), message: 'Paying…');
///
/// LoadingOverlay(isLoading: saving, message: 'Saving', child: form)
///
/// StatusBanner(kind: StatusKind.warning, message: 'Your trial ends in 3 days.', actionLabel: 'Upgrade', onAction: openPlans)
/// ```
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../01_design_system/app_palette.dart';
import '../01_design_system/app_tokens.dart';

/// Shows a non-dismissible progress dialog while [task] runs and always
/// closes it — on success and on error. Errors are rethrown to the caller.
Future<T> runWithLoading<T>(
  BuildContext context,
  Future<T> Function() task, {
  String? message,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  var open = true;
  // Not awaited: the dialog stays up while the task runs below.
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) =>
          PopScope(canPop: false, child: _ProgressCard(message: message)),
    ).whenComplete(() => open = false),
  );
  try {
    return await task();
  } finally {
    if (open && navigator.mounted) navigator.pop();
  }
}

/// Covers [child] with a translucent barrier and spinner while [isLoading];
/// taps on the child are blocked meanwhile.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  final bool isLoading;
  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.3),
              child: _ProgressCard(message: message),
            ),
          ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: message ?? 'Loading',
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                if (message != null) ...[
                  const SizedBox(width: Gap.md),
                  Text(message!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum StatusKind { info, success, warning, error }

/// An inline, persistent message with an icon and an optional action — for
/// states the user should keep seeing (trial ending, sync paused,
/// verification pending), unlike a snackbar that disappears.
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.kind,
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });

  final StatusKind kind;
  final String message;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = SemanticColors.of(context);
    final (color, icon) = switch (kind) {
      StatusKind.info => (semantic.info, Icons.info_outline),
      StatusKind.success => (semantic.success, Icons.check_circle_outline),
      StatusKind.warning => (semantic.warning, Icons.warning_amber_rounded),
      StatusKind.error => (scheme.error, Icons.error_outline),
    };

    return Semantics(
      container: true,
      liveRegion: kind == StatusKind.error,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          Gap.md,
          Gap.md - 4,
          Gap.sm,
          Gap.md - 4,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: Gap.md - 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(title!, style: theme.textTheme.titleSmall),
                  Text(message, style: theme.textTheme.bodyMedium),
                  if (actionLabel != null && onAction != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: onAction,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          foregroundColor: color,
                        ),
                        child: Text(actionLabel!),
                      ),
                    ),
                ],
              ),
            ),
            if (onDismiss != null)
              IconButton(
                tooltip: 'Dismiss',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18),
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}
