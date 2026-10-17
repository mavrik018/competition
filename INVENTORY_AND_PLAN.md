# Inventory and extraction plan

This is the survey of the four source apps and the decisions behind what was extracted into the toolkit. The source projects were only read. Nothing in them was modified.

## 1. Source projects

| Code | Project | Path | Size | Stack |
|---|---|---|---|---|
| **SM** | StudyBuddies (Study-Mate) | `Desktop/Study-Mate` | 175 files, ~65k lines | Riverpod 2, Supabase, sqflite, screenutil, google_fonts, IAP + RevenueCat |
| **KA** | Cookly / EasiMeal (kitchen_app) | `Desktop/Projects/Advance/kitchen_app` | 122 files, ~42k lines | Riverpod 3, Supabase, sqflite, flutter_animate, shimmer, fl_chart, RevenueCat |
| **CP** | Couple | `Desktop/couple` | 250 files, ~34k lines | Riverpod 2, Supabase (auth/storage/realtime), sqflite, FCM, local notifications, rrule |
| **TD** | TaskFlow (todo) | `Desktop/Projects/Advance/todo` | 75 files, ~12k lines | Riverpod 3, drift, go_router, local notifications, Supabase sync |

All four use Riverpod, Supabase and `flutter_screenutil`. SM and KA share an iOS-style UI kit (`ios_ui.dart`, KA ported it from SM). CP has the cleanest architecture: sealed session states, `Failure` types, and no code generation.

## 2. Inventory by category

The **Pick** column says which implementation became the toolkit version and why. ✅ = extracted, ➕ = newly written to fill a gap, ✖ = skipped (reason given).

### 2.1 Design system

| Candidate | Sources | Pick |
|---|---|---|
| Spacing / radii scale | KA `app_spacing.dart` (Gap/Space/Radii/Insets), TD `app_spacing.dart` + `app_radius.dart` | ✅ KA naming, without screenutil |
| Elevation / shadows | KA `app_shadows.dart` (tinted, never black) | ✅ KA, parameterised by tint colour |
| Motion durations / curves | TD `app_animations.dart` | ✅ merged into tokens |
| Colour palette | SM `app_colors.dart` (155 lines, with a light/dark `context` extension), KA `app_colors.dart` (full M3 scheme), TD (light/dark pairs) | ✅ re-shaped: one `AppPalette` seed → light + dark `ColorScheme` + `SemanticColors` ThemeExtension (success/warning/info) |
| Typography ramp | SM `app_typography.dart` (Apple HIG ramp, with documented reasons), KA `app_typography.dart` | ✅ SM ramp, mapped onto Material `TextTheme`. google_fonts dropped, so the font family is a parameter |
| ThemeData builder | SM `app_theme.dart` (412 lines), KA `app_theme.dart` (273 lines), TD | ✅ simplified KA structure, data-driven by palette and brightness |
| Theme-mode persistence | SM `ThemeModeNotifier` (StateNotifier, light/dark/system), TD (bool only) | ✅ SM semantics as a Riverpod 3 `Notifier`, storage injected |

### 2.2 UI elements

| Candidate | Sources | Pick |
|---|---|---|
| Press-scale tap wrapper | KA `pressable.dart`, SM/KA `_IosPressable` (dim on press) | ✅ KA `Pressable` + a `dimOnPress` option |
| Primary button | SM `SMButton`, SM `IosPrimaryButton`, KA `CooklyPrimaryButton` | ✅ merged: loading, destructive, icon, disabled |
| Chip | KA `CooklyChip` | ✅ |
| Section header | KA `SectionHeader` | ✅ asset-icon coupling removed |
| Search field with clear button | KA `CooklySearchField` | ✅ |
| Circular progress gauge | SM `radial_gauge.dart` (no chart dependency) | ✅ as-is, plus a `startAngle` |
| Skeleton loaders | KA `ShimmerBox/List/CardRow` (`shimmer` package) | ✅ rewritten without the package, using one gradient sweep |
| Entrance animations | KA `entrance.dart` (`flutter_animate`) | ✅ rewritten with `TweenAnimationBuilder`, no dependency |
| 3D flip card | SM `spaced_repetition_screen.dart` (inline in a 1,499-line screen) | ✅ extracted into its own widget with a controller |
| Swipe-to-complete / delete row | TD `swipe_action_wrapper.dart` | ✅ generalised: any leading/trailing action |
| Activity heatmap | SM `heatmap_calendar.dart` (study sessions only) | ✅ generalised to `Map<DateTime, num>` |
| Bar chart with target line | KA `week_at_a_glance_card.dart` (`fl_chart`) | ➕ small `CustomPainter` chart, no dependency |
| Spin wheel | KA `roulette_wheel.dart` (693 lines: bezel, brass pegs, glass hub) | ✅ simplified to its mechanics: weighted landing, ticks, controller |
| Step-by-step progress | SM `ai_progress.dart` (AiProgressView) | ✅ generalised `StepProgressView` |
| Keepsake icon | CP `keepsake_icon.dart` (1,010 lines) | ✖ brand-specific illustration set |

### 2.3 Feedback and states

| Candidate | Sources | Pick |
|---|---|---|
| Snackbars | SM `AppFeedback` extension, KA `showErrorSnackBar` (retry), TD `AISnackBar` | ✅ SM API + KA retry action |
| Loading / empty / error views | SM `async_state_views.dart`, KA `states.dart`, CP `empty_view/error_view/loading_view` | ✅ SM layout, theme-driven |
| AsyncValue → view glue | used ad hoc everywhere | ➕ `AsyncValueView` |
| Offline banner | KA (`syncedAt` "showing what we had 12m ago"), CP (wraps the shell) | ✅ merged: both modes |
| Pending-sync banner | KA `PendingSyncBanner` (Riverpod-coupled) | ✅ made provider-agnostic (count + callback) |

### 2.4 Dialogs and sheets

| Candidate | Sources | Pick |
|---|---|---|
| Alert / confirm / message / text prompt | SM `ios_ui.dart` `showIosAlert…`, KA `showCookly…` (same lineage) | ✅ SM, with colours taken from `ColorScheme` |
| Picker action sheet | SM `showIosPicker`, KA `showCooklyPicker` | ✅ |
| Sheet grabber | SM/KA | ✅ |

### 2.5 Forms

| Candidate | Sources | Pick |
|---|---|---|
| Grouped form section / row / value pill / text-field row | SM/KA `ios_ui.dart` | ✅ |
| Segmented control | SM/KA | ✅ |
| Stepper | SM/KA | ✅ |
| Month calendar grid / date field / date sheet | SM/KA `IosCalendarGrid` (+ heat colours) | ✅ week start configurable, no `intl` |
| Validators | scattered inline lambdas | ➕ composable `Validators` |
| Password rules + checklist | SM `password_requirements_checklist.dart` | ✅ rules made configurable |
| Consent checkbox with links | SM `legal_consent_checkbox.dart` | ✅ links passed in, legal sheets decoupled |

### 2.6 Screen templates

| Candidate | Sources | Pick |
|---|---|---|
| Onboarding pager | CP `onboarding_walkthrough.dart`, KA 3-step, SM, TD (755 lines) | ✅ CP structure (smallest correct) |
| Auth form screen | KA `auth_scaffold.dart` + login/signup, SM sign-in/up (400+ lines each) | ✅ one `AuthFormScreen` with sign-in/sign-up modes and callbacks |
| Responsive max-width frame | SM `tablet_frame.dart` + `responsive.dart` | ✅ screenutil coupling removed |
| Splash | KA video splash, TD 678-line animated splash | ✖ brand-specific. `SessionGate` covers the loading phase |

### 2.7 Navigation

| Candidate | Sources | Pick |
|---|---|---|
| Bottom-tab shell keeping tab state | CP `app_shell.dart` (IndexedStack + HeroMode), SM `root_shell.dart`, TD (go_router ShellRoute) | ✅ CP approach on Material 3 `NavigationBar` |
| Session/auth gate | CP `root_gate.dart` + sealed `SessionState` | ✅ generic `SessionGate<S>` |
| Deep-link queue until ready | CP `app_link_handler.dart` | ✅ generic `DeepLinkQueue` |
| Fade-through transition | KA `page_transitions.dart` | ✅ |
| Unfocus on navigate | KA `UnfocusOnNavigate` | ✅ |
| go_router + Riverpod refresh | TD `app_router.dart` `_RefListener` + redirect | ✅ `RouterRefreshNotifier` + a pure redirect function |
| Provider scope reset per user | KA `user_scope.dart` | ✅ generic `KeyedProviderScope` (takes a user-id stream) |

### 2.8 State management

| Candidate | Sources | Pick |
|---|---|---|
| Debounce | TD `debounce.dart`, TD debounced search provider | ✅ |
| Async action runner with busy guard | KA `AuthController._run` (returns bool), SM `AuthNotifier._run` (double-tap guard) | ✅ merged `ActionController` |
| Pagination state | CP `pagination.dart` (state only) | ✅ + a working `PaginationController` |
| Wall-clock countdown | SM `focus_timer_notifier.dart` (deadline-based, survives suspend) | ✅ generic `CountdownController` (injectable clock) |

### 2.9 Persistence

| Candidate | Sources | Pick |
|---|---|---|
| Key/value prefs | ad hoc `SharedPreferences.getInstance()` everywhere | ➕ `PrefsStore` (typed keys + JSON) |
| Offline write queue | SM `sync_queue_service.dart` (conflict detection, hard-coded tables), CP `pending_ops_dao.dart` + coordinator (backoff, handler switch), KA pending_mutations | ✅ CP design (opaque ops + backoff) + SM outcomes (success/retry/drop) + handler registry |
| Offline read cache | KA `local_cache_db.dart` (user-scoped collections + `synced_at`) | ✅ generalised `JsonCache` |
| Client UUID v4 | KA `local_id.dart` | ✅ |
| Drift DB | TD | ✖ code generation, which three of the four apps avoided. sqflite raw SQL is used instead |
| Secure storage | CP `secure_storage.dart` | ✖ thin wrapper. Supabase already persists the session |

### 2.10 Backend integrations

| Candidate | Sources | Pick |
|---|---|---|
| Supabase init + core providers | KA `supabase_client.dart` (dart-define config, init-error provider), CP | ✅ |
| Exception → user message | KA `app_exception.dart` (Postgrest codes, FunctionException reasons), SM `friendlyErrorMessage`, TD `ErrorMapper`, CP `Failure` | ✅ KA, with brand copy removed |
| Auth service | SM (Apple native + nonce, OTP reset, delete via Edge Function), KA (timeouts, cache clear), CP (native Google) | ✅ SM flows + KA `_guard` |
| Edge-function envelope client | SM `ai_edge_client.dart` + `ai_failure.dart` | ✅ generalised `EdgeFunctionClient` |
| Storage upload with retry + cancel | CP `upload_manager.dart` | ✅ bytes-only core, compression left to the caller |
| Signed URL cache | CP `signed_url_cache.dart` | ✅ |
| Realtime presence | CP `couple_presence_channel.dart` | ✅ generic room presence |
| Connectivity | KA, CP (two variants) | ✅ CP stream (initial check + distinct) |
| RevenueCat gateway | KA `purchases_gateway.dart` (interface for testability), `plan_tier.dart` | ✅ gateway + `productTier` helper |
| Push (FCM) | CP | ✖ needs Firebase project config files |

### 2.11 Utilities

| Candidate | Sources | Pick |
|---|---|---|
| Date helpers | TD `date_formatter.dart` (intl), KA `week_math.dart`, KA `_relative`, CP `_addYears` | ✅ merged, no `intl` |
| Number formatting | KA `format_number.dart` | ✅ |
| Inline markdown spans + live-styled editor | TD `rich_text_parser.dart` | ✅ |
| Markdown block parser (headings, lists, fences, tables) | SM `markdown_tokens.dart` | ✅ |
| Haversine distance | CP | ✅ |
| SM-2 spaced repetition | SM `smart_review.dart` `nextRetention` + duplicate in screen | ✅ |
| Daily streak | TD `streak_manager.dart` (prefs + Supabase coupled) | ✅ pure function |
| Quantity scaler (ranges, fractions) | KA `servings_scaler.dart` | ✅ unit lookup injected |
| BMR / TDEE / macros | KA `calorie_calculator.dart` | ✅ |
| Logger | CP `logger.dart` | ✅ |
| List reorder | CP `element_ordering.dart` | ✅ generic |

### 2.12 Common features

| Candidate | Sources | Pick |
|---|---|---|
| Local reminder scheduling | CP `reminder_scheduler.dart` (tz-safe, stable ids), TD `notification_manager.dart` (timezone guess tables) | ✅ CP |
| Permission request flow | CP `permission_service.dart` | ✅ + permanently-denied result |
| Pomodoro timer | SM focus timer | ✅ built on `CountdownController` |
| Quiz session (progress, score, resume JSON) | SM `quiz_session_store.dart` | ✅ |
| Shared drawing canvas | CP canvas page + broadcast channel | ✖ feature-sized, tightly bound to the realtime schema |

## 3. Extraction rules applied

1. **No `flutter_screenutil` in components.** Each app scales against its own design frame (411×914). Components use logical pixels and `Theme.of(context)`, so they drop into any app.
2. **No hard-coded brand colours.** Widgets read `ColorScheme` and `TextTheme`, and status colours come from `SemanticColors`. Re-theming is a palette change.
3. **Dependencies only where they earn their place.** `shimmer`, `flutter_animate`, `fl_chart`, `intl` and `google_fonts` were each used for one thing that is a few dozen lines of plain Flutter.
4. **Seams for testing.** Anything that touches a platform or network takes its I/O as a constructor argument (a function, an interface, or a `Database`), so the logic is tested without a device.
5. **Riverpod 3.** Two of the four apps were already on it. `StateNotifier` and `StateProvider` are legacy there, so everything uses `Notifier` and `AsyncNotifier`.
6. **One file per component.** A file imports only Flutter, its listed packages and, at most, `01_design_system/app_tokens.dart`, so it can be copied on its own.

## 4. Target structure

```
lib/
  01_design_system/      tokens, palette, typography, theme, theme mode
  02_ui_elements/        buttons, chips, gauges, charts, cards, animations
  03_feedback/           snackbars, state views, banners
  04_dialogs_and_sheets/ alerts, prompts, picker sheets
  05_forms/              grouped rows, controls, calendar, validators
  06_screen_templates/   onboarding, auth, responsive frame
  07_navigation/         tab shell, session gate, deep links, routing
  08_state_management/   action runner, pagination, countdown, debounce
  09_persistence/        prefs, offline queue, JSON cache, ids
  10_backend/            Supabase, auth, edge functions, storage, realtime, billing
  11_utilities/          dates, numbers, markdown, geo, SRS, streaks
  12_common_features/   reminders, permissions, pomodoro, quiz
test/                    mirrors lib/
```

Each numbered folder has a `README.md` that documents every component in it: purpose, usage, dependencies, how it works internally, limitations, and tests. `CATALOG.md` at the root indexes all of them.

## 5. Outcome

The plan was implemented as described: 74 components, 217 passing tests, and a clean `flutter analyze`. Where the build differs from the plan above:

- **go_router was not added as a dependency.** The route guard turned out to need nothing from it: `guardRedirect` is a pure function and `RouterRefresh` is a `ChangeNotifier`.
- **The per-user scope is named `UserProviderScope`** (planned as `KeyedProviderScope`).
- **Added during implementation:** `MarkdownView` (02) and `MarkdownEditingController` (05). Both are built on the shared Markdown parser, which delivers the source's goal of one parser feeding every renderer.
- **Bugs found while testing** and fixed in the toolkit only (the sources are untouched):
  - Cookly's roulette landed on the wrong slice from the second spin on.
  - TaskFlow's debounced search never debounced.
  - Couple's session gate could stay on the splash screen forever when offline.
  - Cookly's quantity scaler mangled zero-denominator fractions.
  - Couple's reminder ids relied on `String.hashCode`.
  - `SessionController` assigned Riverpod state during `build()`. This was in my own first draft, not the source, and was caught by its tests.

  Details are in `CATALOG.md` and the folder READMEs.

## 6. Phase 2 — filling the gaps for unknown competition problems

**Goal.** Make the toolkit adaptable to problems none of the four apps faced, with small combinable modules rather than sample apps.

**Gap analysis.** The four apps covered auth, onboarding, study/recipe/task flows, Supabase, reminders and billing. Missing for a general competition: generic CRUD/list/detail/search/analytics/profile/settings screens, a REST client, form-from-data, file/QR/OCR/location/share/export features, adaptive layouts, and anything "smart" beyond streaks and SM-2.

**Rules added for phase 2.**
1. **Rule-based first.** Smart features are deterministic, offline and explainable; each one's docs state plainly that it is not AI. The single AI module (`14_ai`) goes through a server function, validates the model's output and always has a rule-based fallback.
2. **Fakes are labelled.** Every plugin-backed feature is an interface + device implementation + a `Fake…` double. Fakes are documented as test/demo doubles, never as production behaviour. Device implementations are marked 🔶 where `flutter test` cannot exercise them.
3. **Business rules as data.** One JSON condition language (`rule_conditions.dart`) powers risk rules, automations, badges, predictions and contextual actions.
4. **One storage interface.** `Repository<T>` with in-memory, SQLite, Supabase and offline-first implementations, so screens and `CrudController` never change when storage does.
5. **Dependency choices.** `file_picker` pinned to ^10 and `share_plus` to ^12 (newer majors conflict on `win32`); no chart, AI SDK or state-machine packages added.

**Outcome.**
- 54 new components (#75–#128 in `CATALOG.md`), bringing the total to **128 in 14 folders**.
- **394 package tests + 4 showcase tests + 6 Deno tests, all passing**; `flutter analyze` clean.
- A showcase gallery in `example/` running every demo on fakes and in-memory data, with a test that opens each demo at phone size.
- A sample `ai-complete` Edge Function (Gemini, server-held key, standard envelope), tested with Deno against a fake `fetch`.
- Bugs and clashes found by the tests: `Repository.watchAll` missing early writes; a `SettingsChoice` generic type crash; stale results from overlapping offline syncs; `Matcher`/`Badge` name clashes (renamed `SmartMatcher` / `AchievementBadge`); two wrong figures in doc examples (`textSimilarity`, a contrast ratio).
- **Not done / out of scope:** live tests against a real Supabase project or Gemini; device runs of the camera, OCR, GPS, microphone and share sheet (all 🔶); usage caps and moderation for the AI function (documented as required before launch).
