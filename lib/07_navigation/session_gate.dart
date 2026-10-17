/// Decides which top-level screen the app shows — splash, sign-in, a
/// first-run setup step, or the app itself — from one state machine,
/// instead of scattering redirects across screens.
///
/// Source: Couple `app/session/session_state.dart`, `session_provider.dart`
/// and `app/router/root_gate.dart`. Couple composed three checks (signed
/// in? profile exists? partner paired?) into a sealed state and switched the
/// whole tree on it. Generalised: the "is setup complete" check is a function
/// you pass in, and the auth source is a stream of user ids, so it works
/// with any backend.
///
/// ```dart
/// // main.dart
/// ProviderScope(overrides: [
///   sessionSourceProvider.overrideWithValue(SessionSource(
///     userIds: supabase.auth.onAuthStateChange.map((e) => e.session?.user.id),
///     currentUserId: () => supabase.auth.currentUser?.id,
///     isSetupComplete: (uid) async => await profiles.exists(uid),
///   )),
/// ], child: const App());
///
/// // App home:
/// SessionGate(
///   state: ref.watch(sessionProvider),
///   loading: (_) => const SplashScreen(),
///   signedOut: (_) => const SignInScreen(),
///   needsSetup: (_, userId) => ProfileSetupScreen(userId: userId),
///   ready: (_, userId) => const HomeShell(),
/// )
/// ```
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

sealed class SessionState {
  const SessionState();
}

class SessionLoading extends SessionState {
  const SessionLoading();
}

class SessionSignedOut extends SessionState {
  const SessionSignedOut();
}

/// Signed in, but a required first-run step (profile, onboarding, pairing)
/// is not done yet.
class SessionNeedsSetup extends SessionState {
  const SessionNeedsSetup(this.userId);
  final String userId;
}

class SessionReady extends SessionState {
  const SessionReady(this.userId);
  final String userId;
}

/// The setup check failed (usually offline) for a user we had no answer
/// for yet. Call [SessionController.refresh] to retry.
///
/// The source had no such state: it stayed on the splash screen until the
/// next auth event, which offline could mean forever.
class SessionCheckFailed extends SessionState {
  const SessionCheckFailed(this.userId, this.error);
  final String userId;
  final Object error;
}

/// Where the session comes from. Override [sessionSourceProvider] with one.
class SessionSource {
  const SessionSource({
    required this.userIds,
    required this.currentUserId,
    this.isSetupComplete,
  });

  /// Emits the signed-in user id on every auth change; null when signed out.
  final Stream<String?> userIds;

  /// The user id restored from disk at launch (auth streams usually do not
  /// replay it).
  final String? Function() currentUserId;

  /// Omit when the app has no first-run step.
  final Future<bool> Function(String userId)? isSetupComplete;
}

final sessionSourceProvider = Provider<SessionSource>(
  (ref) => throw UnimplementedError(
    'Override sessionSourceProvider in your ProviderScope.',
  ),
);

class SessionController extends Notifier<SessionState> {
  StreamSubscription<String?>? _subscription;
  late SessionSource _source;

  /// Increments per evaluation so a slow check for an old user can never
  /// overwrite the state of a newer one.
  int _generation = 0;

  @override
  SessionState build() {
    _source = ref.watch(sessionSourceProvider);
    _subscription = _source.userIds.listen((id) => unawaited(_evaluate(id)));
    ref.onDispose(() => _subscription?.cancel());

    final current = _source.currentUserId();
    if (current == null) return const SessionSignedOut();
    // State cannot be assigned while build() is still running, so the
    // first check starts right after it returns.
    Future.microtask(() => _evaluate(current));
    return const SessionLoading();
  }

  /// Re-runs the setup check without an auth event — call it after the user
  /// finishes the setup step.
  Future<void> refresh() => _evaluate(_source.currentUserId());

  Future<void> _evaluate(String? userId) async {
    if (!ref.mounted) return;
    final generation = ++_generation;
    if (userId == null) {
      state = const SessionSignedOut();
      return;
    }
    final check = _source.isSetupComplete;
    if (check == null) {
      state = SessionReady(userId);
      return;
    }
    // Only show the loading screen when switching users; a refresh for the
    // same user keeps the current screen up while it checks.
    final previous = state;
    final sameUser =
        (previous is SessionReady && previous.userId == userId) ||
        (previous is SessionNeedsSetup && previous.userId == userId);
    if (!sameUser) state = const SessionLoading();

    try {
      final done = await check(userId);
      if (!ref.mounted || generation != _generation) return;
      state = done ? SessionReady(userId) : SessionNeedsSetup(userId);
    } catch (error, stackTrace) {
      debugPrint('SessionController: setup check failed: $error\n$stackTrace');
      if (!ref.mounted || generation != _generation) return;
      // A network blip must not bounce a user who is already in the app back
      // out of it, so a failed refresh keeps the screen they are on. A user
      // we have no answer for gets a retryable error instead of an endless
      // splash.
      state = sameUser ? previous : SessionCheckFailed(userId, error);
    }
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

/// Builds the screen for the current [SessionState], cross-fading between
/// phases.
class SessionGate extends StatelessWidget {
  const SessionGate({
    super.key,
    required this.state,
    required this.loading,
    required this.signedOut,
    required this.ready,
    this.needsSetup,
    this.checkFailed,
  });

  final SessionState state;
  final WidgetBuilder loading;
  final WidgetBuilder signedOut;
  final Widget Function(BuildContext context, String userId) ready;

  /// Required when the [SessionSource] has an `isSetupComplete` check.
  final Widget Function(BuildContext context, String userId)? needsSetup;

  /// Shown for [SessionCheckFailed] — typically a message with a retry
  /// button calling `ref.read(sessionProvider.notifier).refresh()`. Falls
  /// back to [loading].
  final Widget Function(BuildContext context, Object error)? checkFailed;

  @override
  Widget build(BuildContext context) {
    final child = switch (state) {
      SessionLoading() => loading(context),
      SessionSignedOut() => signedOut(context),
      SessionNeedsSetup(:final userId) =>
        needsSetup?.call(context, userId) ?? ready(context, userId),
      SessionReady(:final userId) => ready(context, userId),
      SessionCheckFailed(:final error) =>
        checkFailed?.call(context, error) ?? loading(context),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(key: ValueKey(state.runtimeType), child: child),
    );
  }
}
