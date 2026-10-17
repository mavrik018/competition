# Competition Toolkit

A Flutter package of 129 reusable components for competition apps, a one-command starter (`tool/create_app.dart`), a showcase with three mini-apps, and the playbook to use them under time pressure.

- **Phase 1** extracted 74 components (UI, screen templates, navigation, state, persistence, backend integrations, utilities and common features) from four production apps: StudyBuddies, Cookly, Couple and TaskFlow. The source projects were not modified.
- **Phase 2** added 54 components for problems those apps never faced: CRUD, search, analytics and settings screens; REST, files, QR, OCR, location, sharing and export; a layer of **smart features** (matching, recommendations, scoring, predictions, insights, automation, scheduling, gamification, personalization, accessibility, voice, offline sync, real-time collaboration); and an optional **AI** layer with rule-based fallbacks.

- **422 automated tests, all passing:** 400 package tests, 11 showcase tests (gallery + 3 mini-apps), 5 starter-template tests (run in a freshly generated app) and 6 Deno tests for the sample Edge Function. `flutter analyze` reports no issues.
- **Built** for the web, Android (debug APK) and Windows; iOS/macOS could not be built on this Windows machine. Full results: [VERIFICATION_REPORT.md](VERIFICATION_REPORT.md).
- **Every component has a status** — ✅ fully tested, 🟡 partially tested, or 🔌 requires external configuration — on its card in [CATALOG.md](CATALOG.md).
- **Rule-based first.** Everything in `13_smart_features` is deterministic, offline and explainable. Only `14_ai` calls a model, through your own server function, and every AI feature falls back to a rule-based result. Device and backend pieces come with clearly labelled fakes, and the docs never present a fake as production behaviour.
- Flutter 3.44 / Dart 3.12, Riverpod 3, Material 3, light and dark themes.
- Components are theme-driven and use plain logical pixels (no `flutter_screenutil`), so they drop into any app.

| Document | What's in it |
|---|---|
| [QUICK_START.md](QUICK_START.md) | **Start here.** Generate an app in one command, then add screens, modules and a differentiator |
| [COMPETITION_PLAYBOOK.md](COMPETITION_PLAYBOOK.md) | Problem analysis, prioritisation, starter selection, component checklist, differentiation matrix, 4- and 5-hour schedules, testing, demo and interview checklists |
| [CATALOG.md](CATALOG.md) | One card per component (use when, inputs, output, dependencies, integration, complexity, interview defence, source, tests, status, edge cases, limitations, example) — generated and verified by `tool/build_catalog.py` |
| [VERIFICATION_REPORT.md](VERIFICATION_REPORT.md) | What was verified and how: analyze, tests, builds, integration combinations, audits, untested scenarios, external requirements |
| [INTERVIEW_PREP.md](INTERVIEW_PREP.md) | A simulated senior interview on the toolkit's decisions, likely weak spots, and concise study notes |
| [ARCHITECTURE_HANDBOOK.md](ARCHITECTURE_HANDBOOK.md) | Decision trees, 18 decision records (default, alternatives, tradeoffs, toolkit example, interview Q&A, failure scenarios), architecture diagrams and a rapid-fire interview drill for a 4–5 hour competition |
| [INVENTORY_AND_PLAN.md](INVENTORY_AND_PLAN.md) | The survey of the four apps, what was picked, rewritten or skipped, and why |
| `lib/NN_*/README.md` | Per folder: usage, how each component works inside, limitations, edge cases, tests |
| [lib/13_smart_features/README.md](lib/13_smart_features/README.md) | The 8-point write-up per smart feature: problems it suits, rule-based vs AI, configurable rules, data/UI wiring, example, difficulty and services, limitations |
| [example/README.md](example/README.md) | A runnable gallery of the components on fakes and in-memory data |

## Structure

```
lib/
  01_design_system/       tokens · palette (+ semantic colours) · typography · AppTheme.build · theme-mode controller
  02_ui_elements/         Pressable · PrimaryButton · AppButton (+ social sign-in) · AppChip · SectionHeader · SearchField
                          text inputs (field, password, PIN, tags) · cards (stat, action, image) · RadialGauge · skeletons
                          FadeSlideIn/Stagger · AnimatedCounter · SuccessCheckmark · Shake · FlipCard · SwipeActionTile
                          ActivityHeatmap · SimpleBarChart · SimpleLineChart · Sparkline · DonutChart · SpinWheel · MarkdownView
  03_feedback/            snackbars · Loading/Empty/ErrorView · AsyncValueView · OfflineBanner · PendingSyncBanner
                          StepProgressView · runWithLoading · LoadingOverlay · StatusBanner
  04_dialogs_and_sheets/  alert / confirm / message / text prompt · picker sheet · general bottom sheet
  05_forms/               grouped form rows · segmented control · stepper · calendar (+ event dots) & date picker
                          validators (+ number, phone, url, pattern) · DynamicForm (JSON forms) · password checklist
                          consent checkbox · live Markdown editing controller
  06_screen_templates/    OnboardingPager · AuthFormScreen · OTP · dashboard · CRUD list · search/filter bar · list/detail
                          agenda calendar · analytics · profile · settings · responsive builder & grid · MaxWidthFrame
  07_navigation/          TabShell (+ rail on wide screens) · SessionGate · DeepLinkQueue · route guard · transitions
                          per-user ProviderScope
  08_state_management/    ActionController · CrudController · ListQuery · PaginationController · CountdownController · Debouncer
  09_persistence/         Repository<T> (in-memory, SQLite) · PrefsStore · local UUIDs · OfflineQueue · JsonCache
  10_backend/             Supabase bootstrap · AppException · AuthService · EdgeFunctionClient · ApiClient (REST)
                          SupabaseRepository · Storage upload & signed URLs · Realtime presence · connectivity · RevenueCat
  11_utilities/           dates · numbers · Markdown parser · geo · SM-2 · streaks · quantity scaling · health · collections · logger
  12_common_features/     reminders (+ daily) · permissions · Pomodoro · quiz session · file rules · media picker · QR
                          OCR · location & geofences · sharing · CSV/JSON/PDF export
  13_smart_features/      rule conditions · matching · recommendations · priority · risk · trends · predictions · insights
                          automation · scheduling · gamification · activity timeline · contextual actions · personalization
                          accessibility · voice commands · offline-first repository · real-time collaboration (CRDT)
  14_ai/                  AiTextClient (Edge Function or fake) · AiAssistant with validated output and rule-based fallbacks
supabase/functions/ai-complete/   sample Edge Function (Gemini, server-held key) + Deno tests
example/                  showcase: 28 component demos + 3 mini-apps (lib/mini_apps) + widget tests
templates/starter/        the app tool/create_app.dart generates (3 tabs, persisted CRUD, dashboard, settings, 5 tests)
tool/                     create_app.dart · add_component.dart (+ src/vendor.dart: copying code into apps)
                          build_catalog.py (+ catalog/ data) · check_docs.py · module_graph.py
test/                     mirrors lib/
```

## Using it

**Option A (recommended): generate a self-contained app.** `dart run tool/create_app.dart my_app` copies the starter plus the toolkit's source into the app's `lib/toolkit/` folder (and the matching toolkit tests into the app's tests) and adds only the packages that code imports. The app does not depend on this folder; its imports are its own:
```dart
import 'package:my_app/toolkit/01_design_system/app_theme.dart';
import 'package:my_app/toolkit/02_ui_elements/primary_button.dart';
```
`--minimal` copies only what the starter uses; `dart run tool/add_component.dart --app ../my_app <folder|file>...` copies more later, with everything those files import. See [QUICK_START.md §1](QUICK_START.md#1-create-the-app-one-command).

**Option B: depend on the package** (how `example/` uses it).
```yaml
dependencies:
  competition_toolkit:
    path: ../competition
```
```dart
import 'package:competition_toolkit/01_design_system/app_theme.dart';
```

## A minimal app built from the toolkit

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final startupError = await initializeSupabase();                           // 10
  final prefs = await SharedPreferences.getInstance();
  final client = Supabase.instance.client;

  runApp(UserProviderScope(                                                   // 07: fresh state per account
    initialUserId: client.auth.currentUser?.id,
    userIds: userIdChanges(client),
    overrides: [
      prefsStoreProvider.overrideWithValue(PrefsStore(prefs)),               // 09
      sessionSourceProvider.overrideWithValue(SessionSource(                 // 07
        userIds: userIdChanges(client),
        currentUserId: () => client.auth.currentUser?.id,
      )),
    ],
    child: const App(),
  ));
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    theme: AppTheme.build(AppPalette.studyBlue, Brightness.light, pageTransitionsTheme: fadeThroughTransitions),
    darkTheme: AppTheme.build(AppPalette.studyBlue, Brightness.dark, pageTransitionsTheme: fadeThroughTransitions),
    themeMode: ref.watch(themeModeProvider),                                  // 01
    navigatorObservers: [UnfocusOnNavigate()],                                // 07
    home: SessionGate(                                                        // 07
      state: ref.watch(sessionProvider),
      loading: (_) => const Scaffold(body: LoadingView()),                   // 03
      signedOut: (_) => const SignInPage(),                                   // wraps AuthFormScreen (06)
      ready: (_, uid) => TabShell(destinations: [                            // 07
        TabDestination(label: 'Home', icon: Icons.home_outlined, builder: (_) => const HomePage()),
        TabDestination(label: 'Profile', icon: Icons.person_outline, builder: (_) => const ProfilePage()),
      ]),
    ),
  );
}
```

## Commands

```bash
flutter pub get
```
```bash
flutter analyze
```
```bash
flutter test
```
```bash
deno test supabase/functions/ai-complete/
```

The showcase app has its own tests: run `flutter test` inside `example/`, or start the gallery with `flutter run` there.

The persistence and offline-sync tests run against real SQLite through `sqflite_common_ffi`. Timer tests use `fake_async`. HTTP tests use `http/testing`'s `MockClient`. Nothing in the test suite touches the network.

## Bugs fixed while extracting

These were found by the tests written for the toolkit. The fixes live only here; the source apps are unchanged.

| Component | Problem in the source | Fix |
|---|---|---|
| `SpinWheel` (Cookly roulette) | Every spin after the first stopped on a different slice from the one reported | End angle computed from the resting angle; 50-spin test |
| Debounced search (TaskFlow) | `build()` returned the raw query, so nothing was debounced | Return the previous value until the timer fires; test |
| `SessionGate` (Couple) | A failed profile check at launch left the app on the splash screen until the next auth event | `SessionCheckFailed` state with retry; test |
| `scaleQuantity` (Cookly) | `"1/0 cup"` became `"2/0 cup"` | Malformed fractions returned unchanged; test |
| Reminder ids (Couple) | Derived from `String.hashCode`, which is not guaranteed stable between runs | FNV-1a hash that is also exact on the web |
| `AuthService.deleteAccount` (Couple variant) | Signed the user out even when deletion failed | Stays signed in and throws |
| `AppException` (Cookly) | Imported `dart:io`, which breaks web builds | Connection errors recognised by text |

Found by the phase-2 tests, in new code:

| Component | Problem | Fix |
|---|---|---|
| `Repository.watchAll` | A write made right after `listen` was missed, because changes were subscribed only after the first load | Subscribe immediately; drop a stale initial load |
| `SettingsChoice` | Choosing a value crashed: `(String) => void` is not a subtype of `(dynamic) => void` | Picker logic moved into the generic item (`choose()`) |
| `OfflineFirstRepository.sync` | A sync requested while an offline check was running returned that run's stale "skipped" result | Overlapping calls queue one follow-up run |
| Icon font | `CupertinoIcons` were used in 02, 04 and 05 without depending on `cupertino_icons`, so they rendered as empty boxes in apps without it (found by the web build) | Added `cupertino_icons` to the toolkit's dependencies |
| `Repository<T>` coupling | The interface file also held the SQLite implementation, so anything using the interface pulled in sqflite (not available on the web) | Split into `repository.dart` (no dependencies) and `sqflite_repository.dart` |
| Unused dependencies | `path`, `cross_file` and `path_provider` were declared but never imported | Removed |
| Android builds | `flutter_local_notifications` requires core library desugaring; the APK build failed without it | Example configured; `create_app.dart` adds it automatically |
| Docs vs code | The forms README said single-choice fields render as chips (they are dropdowns); showcase cards passed `delta: 12` (shows +1200%) instead of `0.12` | Fixed; `tool/check_docs.py` and `tool/build_catalog.py` now verify docs against code |
| `Matcher`, `Badge` | Names clashed with `package:matcher` (exported by `flutter_test`) and Material's `Badge` | Renamed `SmartMatcher` and `AchievementBadge` |

## Conventions

- **Riverpod 3:** `Notifier`/`AsyncNotifier` only. `state` is never set inside `build()`, and async work checks `ref.mounted`.
- **Errors:** repositories throw, UI maps with `AppException.from(e).message`, and raw exception text never reaches the screen.
- **I/O behind seams:** clocks, uploaders, invokers and databases are constructor arguments, so logic is tested without devices.
- **Accessibility:** semantic labels on custom controls, custom semantics actions for swipe gestures, reduce-motion respected, live regions for loading and errors, spoken summaries for charts.
- **Honest intelligence:** rule-based and statistical features are labelled as such. AI output is validated, labelled and always has a fallback.
- **Plugins behind interfaces:** each device feature has an interface, a device implementation and a labelled fake, overridable through a Riverpod provider.
