import 'package:flutter/material.dart';

import '../01_design_system/app_palette.dart';

/// One-line success / error / info confirmations, consistent across screens.
///
/// Source: StudyBuddies `AppFeedback` extension (`core/widgets/app_feedback.dart`)
/// plus the Retry action from Cookly's `showErrorSnackBar`. Raw exception text
/// is never shown: [showError] takes a human sentence and logs the error
/// separately.
///
/// ```dart
/// try {
///   await repo.save(note);
///   context.showSuccess('Note saved');
/// } catch (e, st) {
///   context.showError("Couldn't save your note.", error: e, stackTrace: st, onRetry: save);
/// }
/// ```
///
/// After an `await`, check `context.mounted` first — or capture
/// `ScaffoldMessenger.of(context)` before awaiting and use the
/// [ScaffoldMessengerState] overloads in [AppSnackbars].
extension AppSnackbarContext on BuildContext {
  void showSuccess(String message, {Duration? duration}) {
    final messenger = ScaffoldMessenger.maybeOf(this);
    if (messenger == null) return;
    AppSnackbars.success(
      messenger,
      message,
      theme: Theme.of(this),
      duration: duration,
    );
  }

  void showError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    VoidCallback? onRetry,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(this);
    if (messenger == null) return;
    AppSnackbars.error(
      messenger,
      message,
      theme: Theme.of(this),
      error: error,
      stackTrace: stackTrace,
      onRetry: onRetry,
    );
  }

  void showInfo(String message, {SnackBarAction? action}) {
    final messenger = ScaffoldMessenger.maybeOf(this);
    if (messenger == null) return;
    AppSnackbars.info(messenger, message, action: action);
  }
}

/// The same snackbars, for code that captured a [ScaffoldMessengerState]
/// before an `await` and no longer has a usable `BuildContext`.
abstract final class AppSnackbars {
  static void success(
    ScaffoldMessengerState messenger,
    String message, {
    ThemeData? theme,
    Duration? duration,
  }) {
    final color = theme == null
        ? const Color(0xFF2E7D32)
        : (theme.extension<SemanticColors>()?.success ??
              const Color(0xFF2E7D32));
    _show(
      messenger,
      message,
      background: color,
      icon: Icons.check_circle_outline_rounded,
      duration: duration,
    );
  }

  static void error(
    ScaffoldMessengerState messenger,
    String message, {
    ThemeData? theme,
    Object? error,
    StackTrace? stackTrace,
    VoidCallback? onRetry,
  }) {
    if (error != null) {
      debugPrint('$message\n  cause: $error');
      if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
    }
    _show(
      messenger,
      message,
      background: theme?.colorScheme.error ?? const Color(0xFFB3261E),
      icon: Icons.error_outline_rounded,
      // A failure the user can retry stays up a little longer.
      duration: onRetry == null ? null : const Duration(seconds: 5),
      action: onRetry == null
          ? null
          : SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: onRetry,
            ),
    );
  }

  static void info(
    ScaffoldMessengerState messenger,
    String message, {
    SnackBarAction? action,
  }) => _show(messenger, message, action: action);

  static void _show(
    ScaffoldMessengerState messenger,
    String message, {
    Color? background,
    IconData? icon,
    Duration? duration,
    SnackBarAction? action,
  }) {
    // Replace rather than queue: a stale receipt for an earlier action is
    // worse than no receipt.
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: background,
          duration: duration ?? const Duration(milliseconds: 2800),
          action: action,
          content: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: Colors.white),
                const SizedBox(width: 10),
              ],
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}
