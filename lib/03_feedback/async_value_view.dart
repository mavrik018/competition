import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state_views.dart';

/// Renders a Riverpod [AsyncValue] as loading / error / empty / data using
/// the shared state views, so screens stop hand-writing `.when(...)` with
/// three different spinners.
///
/// Newly written glue. Every source app repeated
/// `ref.watch(x).when(loading: …, error: …, data: …)` with slightly
/// different widgets in each branch.
///
/// ```dart
/// AsyncValueView(
///   value: ref.watch(notesProvider),
///   onRetry: () => ref.invalidate(notesProvider),
///   isEmpty: (notes) => notes.isEmpty,
///   empty: const EmptyView(icon: Icons.notes, title: 'No notes yet'),
///   data: (notes) => NotesList(notes),
/// )
/// ```
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.isEmpty,
    this.empty,
    this.loading,
    this.errorMessage,
    this.compact = false,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  /// When it returns true for loaded data, [empty] is shown instead.
  final bool Function(T data)? isEmpty;
  final Widget? empty;

  /// Replaces the default [LoadingView] — e.g. with a skeleton.
  final Widget? loading;

  /// Turns the error into a user-facing sentence. Defaults to a generic one,
  /// because raw exception text should never reach the screen.
  final String Function(Object error)? errorMessage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Show data we already have while a refresh is in flight, instead of
    // flashing a spinner over content (Riverpod keeps the previous value).
    if (value.hasValue) {
      final current = value.requireValue;
      if (empty != null && (isEmpty?.call(current) ?? false)) return empty!;
      return data(current);
    }
    if (value.hasError) {
      return ErrorView(
        message:
            errorMessage?.call(value.error!) ??
            "We couldn't load this. Please try again.",
        onRetry: onRetry,
        compact: compact,
      );
    }
    return loading ?? LoadingView(compact: compact);
  }
}
