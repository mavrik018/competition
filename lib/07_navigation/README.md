# 07 · Navigation

App structure: which top-level screen shows, the tab frame, deep links, route guards and transitions.

| File | Component | Source | Deps |
|---|---|---|---|
| `tab_shell.dart` | `TabShell`, `TabDestination` | Couple `app_shell.dart`, StudyBuddies `root_shell.dart` | — |
| `session_gate.dart` | `SessionState` (sealed), `SessionController`, `sessionProvider`, `SessionSource`, `SessionGate` | Couple `session_*.dart`, `root_gate.dart` | flutter_riverpod |
| `deep_link_queue.dart` | `DeepLinkQueue` | Couple `app_link_handler.dart` | — |
| `router_guard.dart` | `guardRedirect`, `RouterRefresh` | TaskFlow `app_router.dart` | flutter_riverpod |
| `page_transitions.dart` | `FadeThroughPageTransitionsBuilder`, `fadeThroughTransitions`, `UnfocusOnNavigate` | Cookly | — |
| `user_provider_scope.dart` | `UserProviderScope` | Cookly `user_scope.dart` | flutter_riverpod |

## How the pieces fit

```
main()
 └─ UserProviderScope(userIds: userIdChanges(supabase.client))      ← fresh providers per account
     └─ ProviderScope overrides: sessionSourceProvider
         └─ MaterialApp(theme: AppTheme.build(..., pageTransitionsTheme: fadeThroughTransitions),
                        navigatorKey: navigatorKey, navigatorObservers: [UnfocusOnNavigate()])
             └─ SessionGate(state: ref.watch(sessionProvider), …)
                 ├─ loading    → splash
                 ├─ signedOut  → AuthFormScreen (06)
                 ├─ needsSetup → profile/onboarding step
                 └─ ready      → TabShell(...)        + DeepLinkQueue.flush()
```
Two routing styles are supported. **Router-less** (Couple's approach) uses `SessionGate` plus `Navigator.push`, which needs no package. **go_router** uses `guardRedirect` plus `RouterRefresh`. The toolkit does not depend on go_router; the guard is a pure function.

---

## TabShell

**Purpose.** A bottom `NavigationBar` frame whose tabs keep their state.
**How it works.** `IndexedStack` keeps visited tabs alive. Each tab is wrapped in `HeroMode(enabled: visible)`, so hidden tabs' heroes don't animate. **Improvement:** tabs are built the first time they are opened. A plain `IndexedStack` builds every tab at launch and starts all of their data loading at once. Re-tapping the current tab calls `onReselect` (e.g. scroll to top). `GlobalKey<TabShellState>().currentState!.select(i)` switches tabs programmatically.
**Tests.** Lazy build, preserved state, reselect.

## SessionGate / SessionController

**Purpose.** One state machine decides the top-level screen: `SessionLoading → SessionSignedOut | SessionNeedsSetup(userId) | SessionReady(userId) | SessionCheckFailed(userId, error)`.
```dart
ProviderScope(overrides: [
  sessionSourceProvider.overrideWithValue(SessionSource(
    userIds: userIdChanges(Supabase.instance.client),               // 10
    currentUserId: () => Supabase.instance.client.auth.currentUser?.id,
    isSetupComplete: (uid) async => await supabase.from('profiles').select('id').eq('id', uid).maybeSingle() != null,
  )),
], child: const App());

SessionGate(
  state: ref.watch(sessionProvider),
  loading: (_) => const SplashScreen(),
  signedOut: (_) => const SignInScreen(),
  needsSetup: (_, uid) => ProfileSetupScreen(onDone: () => ref.read(sessionProvider.notifier).refresh()),
  ready: (_, uid) => const HomeShell(),
  checkFailed: (_, e) => ErrorView(message: "Can't reach the server.", onRetry: () => ref.read(sessionProvider.notifier).refresh()),
)
```
**How it works.** `build()` subscribes to `userIds` and returns `SessionSignedOut` or `SessionLoading`. The first check runs in a microtask, because Riverpod 3 forbids assigning `state` during `build` (a test caught this). A generation counter drops results from stale checks. A refresh for the same user keeps the current screen up while it checks.
**Improvement over the source.** In Couple, a failed profile check (offline at launch) left the app on the splash screen until the next auth event. Now a user we have no answer for gets `SessionCheckFailed` with a retry, and a user already in the app stays where they are when a refresh fails (both tested).
**Limitations.** A single boolean setup step. For multi-step onboarding, make `isSetupComplete` check the last step, or extend the sealed class.

## DeepLinkQueue

**Purpose.** A notification tap or app link that arrives while the app is still on splash or sign-in is held, then opened once the session is ready. Without this, tapping a notification on a cold, signed-out app does nothing.
**API.** `handle(path)` opens now or holds the link. `flush()` (call on every session change) opens the held link once. `clear()` (call on sign-out). Only the latest held link is kept.
**Tests.** Hold, latest wins, single open, clear.

## guardRedirect / RouterRefresh

**Purpose.** `guardRedirect(location:, isLoading:, isSignedIn:, onboardingDone:, publicPaths:)` returns where to send the user, or null to stay. Order: loading → `/splash`, first run → `/onboarding`, signed out → `/sign-in` (except public paths), signed in on an entry route → `/`. `RouterRefresh(ref, [providers])` is a `ChangeNotifier` to pass as go_router's `refreshListenable`.
**Changed from the source.** TaskFlow's redirect was inline in the router and only covered onboarding. Pulling it out made it testable. All paths are parameters.
**Tests.** The full decision table, and refresh on provider change.

## FadeThroughPageTransitionsBuilder / UnfocusOnNavigate

The fade-through route transition: the outgoing page fades out over the first 35%, and the incoming page fades in and scales from 96%. `fadeThroughTransitions` applies it on all platforms. `UnfocusOnNavigate` dismisses the keyboard on push and pop. Without it, Flutter restores focus to the previous page's field when you come back, and its keyboard pops open again (a Cookly bug).

## UserProviderScope

**Purpose.** Each signed-in account gets a brand-new `ProviderScope`, so cached data from the previous user can never leak to the next one on a shared device.
**How it works.** It listens to a user-id stream and bumps a generation counter that keys the `ProviderScope`. Same-id events (token refreshes) are ignored.
**Architectural reasoning.** StudyBuddies kept a hand-maintained list of nine providers to invalidate on sign-out, which had to be updated for every new feature. Replacing the scope is a guarantee instead of a checklist.
**Limitations.** Everything below the scope rebuilds, including the navigator, which is intended on an account switch. Put it above `MaterialApp`.
**Tests.** The counter resets for a new user and survives a same-user event.

**Folder tests: 18** (`navigation_test.dart`).

---

## Phase 2 addition — adaptive `TabShell`

`TabShell` now switches from a bottom `NavigationBar` to a `NavigationRail` (with a divider) when the window is at least `railBreakpoint` wide (default 840, the Material 3 "expanded" size), so the same app works on phones, tablets and the web without a second layout. Tested in `test/06_screen_templates/responsive_layout_test.dart`.
