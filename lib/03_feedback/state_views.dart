/// The three non-happy-path states every data screen needs — loading, empty
/// and error — with one shared layout.
///
/// Source: StudyBuddies `async_state_views.dart` (layout, retry button),
/// Cookly `states.dart` (`EmptyState`, `ErrorView`) and Couple
/// `empty_view.dart` / `error_view.dart`. All three apps had their own; this
/// keeps StudyBuddies' layout and reads colours from the theme.
///
/// ```dart
/// if (notes.isEmpty) {
///   return EmptyView(
///     icon: Icons.note_add_outlined,
///     title: 'No notes yet',
///     message: 'Your notes will appear here.',
///     actionLabel: 'New note',
///     onAction: createNote,
///   );
/// }
/// ```
library;

import 'package:flutter/material.dart';

import '../01_design_system/app_tokens.dart';

/// Centred spinner with an optional message.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message, this.compact = false});

  final String? message;

  /// Less vertical padding, for use inside a section rather than a page.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? Gap.lg : Gap.xxl + 16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            if (message != null) ...[
              const SizedBox(height: Gap.md - 2),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Nothing here yet" — distinct from an error. Offer a next step when you
/// can, through [actionLabel] and [onAction].
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _StateLayout(
      compact: compact,
      icon: icon,
      iconColor: scheme.primary,
      title: title,
      message: message,
      action: actionLabel != null && onAction != null
          ? FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(actionLabel!),
            )
          : null,
    );
  }
}

/// A failure the user can understand and, when possible, retry.
///
/// [message] must already be human-readable — map exceptions first (see
/// `AppException.from` in `10_backend/app_exception.dart`).
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.title = 'Something went wrong',
    this.icon = Icons.cloud_off_rounded,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.compact = false,
  });

  final String message;
  final String title;
  final IconData icon;
  final VoidCallback? onRetry;
  final String retryLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _StateLayout(
      compact: compact,
      icon: icon,
      iconColor: scheme.error,
      title: title,
      message: message,
      action: onRetry == null
          ? null
          : OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(retryLabel),
            ),
    );
  }
}

class _StateLayout extends StatelessWidget {
  const _StateLayout({
    required this.compact,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.action,
  });

  final bool compact;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Gap.xl,
          vertical: compact ? Gap.lg : Gap.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: iconColor),
            ),
            const SizedBox(height: Gap.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: Gap.sm - 1),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: Gap.lg - 4),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
