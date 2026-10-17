import 'package:flutter/material.dart';

import '../01_design_system/app_tokens.dart';

/// A persistent strip that says the device is offline — and, when the
/// screen is showing cached data, how old that data is.
///
/// Source: Couple `offline_banner.dart` (persistent banner, not a toast —
/// being offline is ongoing state) merged with Cookly's `OfflineBanner`
/// ("Offline, showing what we had 12m ago"). Both watched providers
/// directly; this one takes plain values, so it works with any connectivity
/// source (see `connectivityProvider` in `10_backend/connectivity.dart`).
///
/// ```dart
/// Column(children: [
///   OfflineBanner(
///     isOnline: ref.watch(isOnlineProvider),
///     syncedAt: notesSyncedAt, // from JsonCache.syncedAt(uid, 'notes')
///   ),
///   Expanded(child: content),
/// ])
/// ```
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    required this.isOnline,
    this.syncedAt,
    this.message,
    this.now,
  });

  final bool isOnline;

  /// When the visible data was last fetched. Adds "Showing data saved 5m ago".
  final DateTime? syncedAt;

  /// Replaces the default wording entirely.
  final String? message;

  /// Overrides the clock — for tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text =
        message ??
        (syncedAt == null
            ? "You're offline. Changes will sync when you reconnect."
            : "You're offline. Showing data saved ${_timeAgo(syncedAt!, now)}.");

    return AnimatedSize(
      duration: Motion.short,
      alignment: Alignment.topCenter,
      child: isOnline
          ? const SizedBox(width: double.infinity)
          : Semantics(
              liveRegion: true,
              child: Container(
                width: double.infinity,
                color: scheme.errorContainer,
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.md,
                  vertical: Gap.sm - 2,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 16,
                      color: scheme.onErrorContainer,
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: Text(
                        text,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: scheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// "N changes waiting to sync" with a Sync-now button, shown while an
/// offline write queue is non-empty.
///
/// Source: Cookly `PendingSyncBanner` (`features/pantry/application/offline_sync.dart`),
/// which watched three app providers. Here the count and the sync action are
/// passed in — pair it with `OfflineQueue.pendingCount()` from
/// `09_persistence/offline_queue.dart`.
class PendingSyncBanner extends StatefulWidget {
  const PendingSyncBanner({
    super.key,
    required this.pendingCount,
    required this.isOnline,
    required this.onSyncNow,
  });

  final int pendingCount;
  final bool isOnline;
  final Future<void> Function() onSyncNow;

  @override
  State<PendingSyncBanner> createState() => _PendingSyncBannerState();
}

class _PendingSyncBannerState extends State<PendingSyncBanner> {
  bool _syncing = false;

  Future<void> _sync() async {
    setState(() => _syncing = true);
    try {
      await widget.onSyncNow();
    } catch (error) {
      // Still offline or a real failure: the banner stays with the same
      // count, and the button is there to try again.
      debugPrint('PendingSyncBanner: sync failed: $error');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pendingCount <= 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = widget.pendingCount;

    return Container(
      margin: const EdgeInsets.fromLTRB(Gap.gutter, Gap.xs, Gap.gutter, 0),
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.md - 4,
        vertical: Gap.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Row(
        children: [
          Icon(
            Icons.sync_rounded,
            size: 16,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              count == 1
                  ? '1 change waiting to sync'
                  : '$count changes waiting to sync',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
          if (widget.isOnline)
            _syncing
                ? SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onSecondaryContainer,
                    ),
                  )
                : TextButton(
                    onPressed: _sync,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: scheme.onSecondaryContainer,
                    ),
                    child: const Text('Sync now'),
                  ),
        ],
      ),
    );
  }
}

// Same wording as `timeAgo` in 11_utilities/date_utils.dart, kept private
// here so this widget can be copied without the utilities folder.
String _timeAgo(DateTime when, DateTime? now) {
  final diff = (now ?? DateTime.now()).difference(when);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return diff.inDays == 1 ? '1 day ago' : '${diff.inDays} days ago';
}
