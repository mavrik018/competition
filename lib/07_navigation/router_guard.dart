/// Router guard helpers (written for go_router, usable with any router that
/// asks "where should this location go?"): a redirect rule for splash → onboarding → sign-in →
/// app, and a [Listenable] that re-runs it whenever Riverpod state changes.
///
/// Source: TaskFlow `core/routing/app_router.dart` (`_RefListener` +
/// `redirect`). The redirect logic was pulled out into the pure function
/// [guardRedirect] so it can be unit-tested without building a router, and
/// sign-in was added (TaskFlow only guarded onboarding). Nothing here imports
/// go_router, so the toolkit does not depend on it.
///
/// ```dart
/// final routerProvider = Provider<GoRouter>((ref) {
///   return GoRouter(
///     initialLocation: '/splash',
///     refreshListenable: RouterRefresh(ref, [sessionProvider, onboardingProvider]),
///     redirect: (context, state) {
///       final session = ref.read(sessionProvider);
///       return guardRedirect(
///         location: state.matchedLocation,
///         isLoading: session is SessionLoading,
///         isSignedIn: session is SessionReady,
///         onboardingDone: ref.read(onboardingProvider).value ?? false,
///       );
///     },
///     routes: [...],
///   );
/// });
/// ```
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

/// Notifies go_router to re-evaluate `redirect` whenever any of [providers]
/// changes. Pass it as `GoRouter.refreshListenable`.
class RouterRefresh extends ChangeNotifier {
  RouterRefresh(Ref ref, List<ProviderListenable<Object?>> providers) {
    for (final provider in providers) {
      ref.listen(provider, (_, _) => notifyListeners());
    }
  }
}

/// Where to send the user, or null to let them stay on [location].
///
/// Order of checks: still loading → splash; first run → onboarding; signed
/// out → sign-in (unless the route is public); signed in on an entry route
/// → home.
String? guardRedirect({
  required String location,
  required bool isLoading,
  required bool isSignedIn,
  bool onboardingDone = true,
  String splashPath = '/splash',
  String onboardingPath = '/onboarding',
  String signInPath = '/sign-in',
  String homePath = '/',
  Set<String> publicPaths = const {},
}) {
  String? goTo(String path) => location == path ? null : path;

  if (isLoading) return goTo(splashPath);
  if (!onboardingDone) return goTo(onboardingPath);
  if (!isSignedIn) {
    if (publicPaths.contains(location)) return null;
    return goTo(signInPath);
  }
  final onEntryRoute =
      location == splashPath ||
      location == onboardingPath ||
      location == signInPath;
  return onEntryRoute ? homePath : null;
}
