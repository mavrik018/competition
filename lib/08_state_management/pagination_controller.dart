/// Cursor-based infinite scrolling: first page, "load more", pull to
/// refresh, and an error that does not throw away the rows already shown.
///
/// Source: Couple `core/utils/pagination.dart` — which defined `Page<T>` and
/// `PaginatedState<T>` (including the `_unset` sentinel trick for nullable
/// `copyWith` fields) but left each feature to write its own notifier.
/// This adds the shared notifier.
///
/// ```dart
/// final notesPager = NotifierProvider.autoDispose<
///     PaginationController<Note>, PaginatedState<Note>>(
///   () => PaginationController((ref, cursor) =>
///       ref.read(notesRepoProvider).page(after: cursor, limit: 20)),
/// );
///
/// // In a ListView.builder: when the last row builds, load the next page.
/// if (index == state.items.length - 1) ref.read(notesPager.notifier).loadMore();
/// ```
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One page from the backend. A null [nextCursor] means there is no more.
class PageResult<T> {
  const PageResult(this.items, {this.nextCursor});

  final List<T> items;

  /// Opaque — typically the last row's `created_at` or id. Pass it back
  /// unchanged; never parse it.
  final String? nextCursor;
}

@immutable
class PaginatedState<T> {
  const PaginatedState({
    this.items = const [],
    this.isLoadingFirstPage = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.cursor,
    this.error,
  });

  final List<T> items;
  final bool isLoadingFirstPage;
  final bool isLoadingMore;
  final bool hasMore;
  final String? cursor;

  /// The last failure. Rows already in [items] stay visible.
  final Object? error;

  bool get isEmpty => items.isEmpty && !isLoadingFirstPage && error == null;

  PaginatedState<T> copyWith({
    List<T>? items,
    bool? isLoadingFirstPage,
    bool? isLoadingMore,
    bool? hasMore,
    Object? cursor = _unset,
    Object? error = _unset,
  }) {
    return PaginatedState<T>(
      items: items ?? this.items,
      isLoadingFirstPage: isLoadingFirstPage ?? this.isLoadingFirstPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      // A sentinel distinguishes "leave as is" from "set to null".
      cursor: identical(cursor, _unset) ? this.cursor : cursor as String?,
      error: identical(error, _unset) ? this.error : error,
    );
  }

  static const Object _unset = Object();
}

typedef PageFetcher<T> =
    Future<PageResult<T>> Function(Ref ref, String? cursor);

class PaginationController<T> extends Notifier<PaginatedState<T>> {
  PaginationController(this._fetch);

  final PageFetcher<T> _fetch;

  /// Bumped by [refresh] so a page requested before the refresh can never be
  /// appended after it.
  int _generation = 0;

  @override
  PaginatedState<T> build() {
    Future.microtask(_loadFirstPage);
    return PaginatedState<T>(isLoadingFirstPage: true);
  }

  Future<void> _loadFirstPage() async {
    final generation = ++_generation;
    try {
      final page = await _fetch(ref, null);
      if (!ref.mounted || generation != _generation) return;
      state = PaginatedState<T>(
        items: page.items,
        hasMore: page.nextCursor != null,
        cursor: page.nextCursor,
      );
    } catch (error) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(isLoadingFirstPage: false, error: error);
    }
  }

  /// Fetches the next page. Ignored while a load is running or when there
  /// is nothing more, so it is safe to call from every scroll event.
  Future<void> loadMore() async {
    final current = state;
    if (current.isLoadingFirstPage ||
        current.isLoadingMore ||
        !current.hasMore) {
      return;
    }
    final generation = _generation;
    state = current.copyWith(isLoadingMore: true, error: null);
    try {
      final page = await _fetch(ref, current.cursor);
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(
        items: [...state.items, ...page.items],
        isLoadingMore: false,
        hasMore: page.nextCursor != null,
        cursor: page.nextCursor,
      );
    } catch (error) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(isLoadingMore: false, error: error);
    }
  }

  /// Starts again from the first page (pull to refresh). Existing rows stay
  /// on screen until the new first page arrives.
  Future<void> refresh() {
    state = state.copyWith(isLoadingFirstPage: true, error: null);
    return _loadFirstPage();
  }
}
