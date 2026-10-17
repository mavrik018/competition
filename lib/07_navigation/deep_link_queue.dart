/// Holds a deep link (a notification tap, a universal link) until the app is
/// ready to show it, instead of dropping it.
///
/// Source: Couple `app/router/app_link_handler.dart`. Its key insight is
/// kept: a link that arrives while the app is still on splash / sign-in is
/// queued and replayed the moment the session becomes ready — without that,
/// tapping a notification on a cold, signed-out app silently does nothing,
/// the most common bug in hand-rolled deep linking. The Couple-specific
/// "join couple" branch was removed; route special cases through [open].
///
/// ```dart
/// final navigatorKey = GlobalKey<NavigatorState>();
/// final links = DeepLinkQueue(
///   isReady: () => ref.read(sessionProvider) is SessionReady,
///   open: (path) => navigatorKey.currentState?.pushNamed(path),
/// );
///
/// // From a notification tap or app-link callback:
/// links.handle('/note/42');
///
/// // When the session becomes ready:
/// ref.listen(sessionProvider, (_, next) {
///   if (next is SessionReady) links.flush();
/// });
/// ```
library;

class DeepLinkQueue {
  DeepLinkQueue({required this.isReady, required this.open});

  /// Whether a link can be opened right now.
  final bool Function() isReady;

  /// Actually navigates. Receives the path exactly as handled.
  final void Function(String path) open;

  String? _pending;

  /// The link waiting for [flush], if any.
  String? get pending => _pending;

  /// Opens [path] now, or holds it until [flush] if the app is not ready.
  /// Only the most recent pending link is kept — if two arrive while signed
  /// out, the user wants the one they tapped last.
  void handle(String path) {
    if (isReady()) {
      open(path);
    } else {
      _pending = path;
    }
  }

  /// Opens the held link if there is one and the app is ready. Safe to call
  /// on every state change.
  void flush() {
    final path = _pending;
    if (path == null || !isReady()) return;
    _pending = null;
    open(path);
  }

  /// Drops a held link — e.g. on sign-out, so the next account does not
  /// open a link meant for the previous one.
  void clear() => _pending = null;
}
