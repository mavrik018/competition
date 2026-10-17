# Verification report

What was verified, how, and what was **not**. Environment: Windows 11 · Flutter 3.44.1 (stable) · Dart 3.12.1 · Android SDK 36 · Visual Studio Community 2026 · Deno 2.8.3 · Chrome. Date: October 2026.

## 1. Summary

| # | Task | Result |
|---|---|---|
| 1 | Working showcase app | ✅ `example/`: 28 component demos + 3 mini-apps; runs in Chrome; 11 widget tests pass at phone size |
| 2 | Modules integrate independently | ✅ 126 library files, **no import cycles**; 64 files import no other toolkit file, 35 import exactly one; 89 need no third-party package. One coupling found and fixed (repository split) |
| 3 | Representative combinations | ✅ 12 combinations exercised by automated tests (§4) |
| 4 | Example mini-apps | ✅ Expense tracker, Volunteer match, Shared shopping list — 7 end-to-end tests |
| 5 | Analyze, tests, builds | ✅ analyze clean (package, showcase, generated app) · **422 tests pass** · builds: web ✅, Android debug APK ✅, Windows debug ✅ · iOS/macOS ❌ not possible on Windows |
| 6 | Forms, loading, errors, empty, invalid input, persistence, navigation | ✅ each covered by named tests (§6) |
| 7 | Unnecessary dependencies / complicated code | ✅ 3 unused dependencies removed; 1 coupling split; complexity hotspots listed (§7) |
| 8 | No hardcoded credentials / unsafe configs | ✅ none found; 2 disclosures (§8) |
| 9 | Docs match code | ✅ two automated checkers added; 4 real mismatches found and fixed (§9) |
| 10 | Untested scenarios and external requirements | Recorded per component (§10) and on every catalog card |

**Component status** (from the generated, code-verified [CATALOG.md](CATALOG.md)): **105 ✅ fully tested · 5 🟡 partially tested · 1 🔌 requires external configuration · 18 🟡🔌 both** — 129 components.

## 2. Commands and results

| Command | Where | Result |
|---|---|---|
| `flutter analyze` | toolkit root (includes `lib/`, `test/`, `tool/`, `example/`) | No issues found |
| `flutter analyze` | `example/` | No issues found |
| `flutter test` | toolkit root | **400 passed**, 0 failed |
| `flutter test` | `example/` | **11 passed** (4 gallery + 7 mini-app) |
| `dart run tool/create_app.dart fresh_app …` then `flutter analyze` + `flutter test` | freshly generated app | No issues · **5 passed** |
| `deno test supabase/functions/ai-complete/` | toolkit root | **6 passed** · `deno check` clean |
| `python tool/build_catalog.py --check` | toolkit root | 129 entries verified (sources, symbols, test files, counts) |
| `python tool/check_docs.py` | toolkit root | 0 problems in 23 documents |
| `python tool/module_graph.py` | toolkit root | 127 files, no import cycles |
| `flutter build web --release` | `example/` | ✅ built |
| `flutter build apk --debug` | `example/` | ✅ built (after fixes in §5) |
| `flutter build windows --debug` | `example/` | ✅ built |
| `flutter build web`, `apk --debug`, `windows --debug` | freshly generated app (old path-dependency mode) | ✅ web · ✅ APK (desugaring added automatically) · ✅ Windows (from a short path — see §5) |
| `dart run tool/create_app.dart full2 --dir C:/ct` then `flutter analyze` + `flutter test` | self-contained app, full copy (127 files in `lib/toolkit/`, no `competition_toolkit` reference) | No issues · **405 passed** (400 toolkit + 5 starter) |
| `flutter build web`, `flutter build apk --debug` | same app | ✅ web · ✅ APK. Windows **not re-verified**: the disk ran out of space mid-build and the half-written build folder then failed at "native assets"; the plugin set is identical to `example/`, which builds for Windows |
| `create_app.dart mini2 --minimal` then analyze + test | self-contained app, minimal copy (35 files, 4 packages) | No issues · **49 passed** |
| `add_component.dart --app mini2 smart_matching insights reminder_scheduler 14_ai` then analyze + test | same app | +8 files (with their imports), +4 packages, desugaring enabled, `ai-complete` copied · No issues · **61 passed** |

Total automated tests: 400 + 11 + 5 + 6 = **422**.

**Restored on 2026-10-15:** `lib/10_backend/supabase_errors.dart` (Supabase error wording, split out of `app_exception.dart` so that file needs no packages) was missing after an interrupted session was rewound — three files still imported it and `flutter analyze` failed. It and the matching `app_exception.dart` were restored from the session transcript; analyze is clean and the 3 error-mapping tests it brought pass (397 → 400 tests).

## 3. Showcase app (task 1)

`example/` depends on the toolkit by path and runs entirely on fakes and in-memory data. It was served from a release web build and exercised in a browser:
- every gallery entry renders (28 demos in 7 sections + 3 mini-apps);
- the collaboration demo was driven by hand: an item added on phone A appeared on phone B; with "simulate lag" on, a change was held and then delivered reversed + duplicated, and both phones converged.

The browser run found two defects that unit tests had missed — both fixed: icons rendering as empty boxes (missing `cupertino_icons` font dependency) and stat cards showing "+1200%" (demos passed `12` where the API takes the fraction `0.12`).

## 4. Integration and combinations (tasks 2–3)

**Independence.** `tool/module_graph.py` prints, for each file, the toolkit files and packages it pulls in transitively and fails on cycles. Result: no cycles; most files stand alone. The largest footprint is `CrudListScreen` (10 toolkit files, only `flutter_riverpod` as a package).
**Coupling fixed:** `repository.dart` contained both the `Repository<T>` interface and the SQLite implementation, so `CrudController` and `SupabaseRepository` pulled in sqflite, which does not run on the web. Split into `repository.dart` (no dependencies) and `sqflite_repository.dart`.
**Remaining intended couplings:** `ai_assistant` → `EdgeFunctionClient` → `supabase_flutter`; `offline_first_repository` → `OfflineQueue` → `sqflite`.

**Combinations exercised by automated tests**

| Combination | Pieces | Test |
|---|---|---|
| Screen + state + local persistence | CrudListScreen + CrudController + PrefsRepository | starter `app_test.dart`; `mini_apps_test.dart` (expense) |
| Form → sheet → state → storage | DynamicForm + showAppBottomSheet + CrudController | starter; expense mini-app |
| State + SQLite | CrudController + SqfliteRepository (desktop SQLite) | `crud_and_query_test.dart` |
| Dashboard + algorithm | DashboardTemplate + rankByPriority | starter (`Next: …`, counts) |
| Navigation + state | TabShell switching tabs with shared providers | starter; expense mini-app |
| Analytics pipeline | dailySeries → analyzeTrend → generateInsights → charts/InsightCard | expense mini-app; `analytics_and_engagement_test.dart` |
| Auth flow + action state | AuthFormScreen + ActionController + session notifier | volunteer mini-app |
| List/detail + matching + gamification | ListDetailScaffold + SmartMatcher + XP/badges + ProfileTemplate | volunteer mini-app |
| Real-time + voice + offline UI | CollaborativeDocument + InMemoryCollabHub + VoiceInputButton + OfflineBanner | shared-list mini-app; `context_and_sync_test.dart` |
| Offline-first sync | OfflineFirstRepository + OfflineQueue (SQLite) + flaky remote | `context_and_sync_test.dart` |
| AI + fallback | AiAssistant + FakeAiTextClient / failing client | `ai_test.dart`; gallery AI demo test |
| Theme + settings + persistence | ThemeModeController + SettingsChoice | starter (theme switch) |

## 5. Builds (task 5)

| Target | Showcase | Generated app | Notes |
|---|---|---|---|
| Web (release) | ✅ | ✅ | Served and used in a browser |
| Android (debug APK) | ✅ | ✅ | Required two fixes below |
| Windows (debug) | ✅ | ✅ | Requires `flutter pub get` after adding the platform (generates `generated_plugins.cmake`) |
| iOS / macOS | ❌ not built | ❌ | Needs a Mac with Xcode |
| Linux | ❌ not built | ❌ | Not set up on this machine |

Build issues found and fixed:
1. **Missing icon font** — `CupertinoIcons` used in 6 files without the `cupertino_icons` dependency → added.
2. **Gradle "Unable to establish loopback connection"** (environmental) — the JDK's Unix-domain sockets fail when the temp path is long; fixed by setting `_JAVA_OPTIONS=-Djdk.net.unixdomain.tmpdir=<short folder>`. Documented in QUICK_START §8.
3. **Android `checkDebugAarMetadata`: flutter_local_notifications requires core library desugaring** — added to the example's `android/app/build.gradle.kts`; `tool/create_app.dart` now adds it to every generated app (verified in the fresh app).

4. **Windows: "Unable to generate build files" (MSB3491)** (environmental) — the generated app sat in a very deep temp folder, and MSBuild paths exceeded Windows' 260-character limit. The same app generated under a short folder built successfully. Keep projects in short paths (or enable Windows long paths).

Warnings left as-is: several plugins print a deprecation notice about migrating to Flutter's built-in Kotlin support (plugin authors' change, not ours). The debug APK is ~220 MB because every plugin (including ML Kit) is linked; a real app that copies only the modules it needs will be much smaller.

## 6. Behaviour coverage (task 6)

| Behaviour | Where it is tested |
|---|---|
| Forms — invalid input | starter: empty title → "Title is required"; expense: "Amount is required", "Category is required", "-5" → "Must be at least 0.01"; volunteer: invalid email; `dynamic_form_test.dart`; `forms_test.dart` (validators) |
| Forms — valid submit | starter; expense (comma decimal `12,50` → €12.50); `dynamic_form_test.dart` |
| Loading states | volunteer: spinner while signing in; `new_elements_test.dart` (button loading); `loading_overlay_test.dart`; `feedback_test.dart` (AsyncValueView) |
| Errors | starter & expense: failing repository → error view with "Try again"; volunteer: wrong password message; `api_client_test.dart`; `backend_test.dart` (AppException, envelopes) |
| Empty states | starter ("Nothing here yet"), expense ("No expenses yet", "No data yet"), shared list; `new_screens_test.dart` (no matches vs empty) |
| Persistence | starter & expense: add → drop the app → rebuild → item still there (PrefsRepository); SQLite in `crud_and_query_test.dart`, `persistence_test.dart` |
| Navigation | starter & expense: tab switching; volunteer: push detail, back, profile tab, sign-out → sign-in; `navigation_test.dart`; `new_screens_test.dart` (list/detail on phone vs tablet) |
| Layout overflow | showcase tests run every demo at 390×844 (overflow fails the test) |

## 7. Dependencies and simplification (task 7)

**Removed (never imported):** `path`, `cross_file`, `path_provider`.
**Added:** `cupertino_icons` (font actually needed); dev-only `shared_preferences_platform_interface` (in-memory preferences for tests).
**Simplified:** the repository split (§4).
**Kept, though heavy — needed by a listed module:** `google_mlkit_text_recognition` (OCR), `purchases_flutter` (billing), `sign_in_with_apple`, `mobile_scanner`, `flutter_local_notifications`. Copy only the modules you use (each card lists its packages) to keep an app small.

**Complexity hotspots** (reviewed, kept, covered by tests; the ones to read before defending them):
- `parseNaturalTime` in `voice_input.dart` — ordered regex rules for English time phrases; 13 phrasings tested.
- `OfflineFirstRepository.sync` — push/pull with conflict rules and run coalescing; 6 tests.
- `CollaborativeDocument` protocol — 5 tests including reordered/duplicated delivery.
- `ApiClient` retry loop — 10 tests.

## 8. Credentials and configuration audit (task 8)

Scanned `lib/`, `test/`, `example/`, `supabase/`, `pubspec.yaml` for JWTs (`eyJ…`), OpenAI/Anthropic-style keys (`sk-…`), Google API keys (`AIza…`), Supabase secret/publishable keys, `*.supabase.co` project URLs, RevenueCat keys, and `password/api_key/secret = "…"` assignments. **No credentials found.** The only matches were a comment warning never to ship a `service_role` key, a test password string in a checklist test and a demo Wi-Fi password in the QR demo.

Configuration sources:
- Supabase URL and publishable key: `--dart-define` only (`SupabaseConfig`); no defaults baked in.
- RevenueCat key: passed by the caller to `configure(apiKey:)`.
- Gemini key: `GEMINI_API_KEY` in Edge Function secrets only.
- No `http://` endpoints in code; no secrets in logs (logging reviewed).

**Disclosures:**
- `ai-complete` sets `Access-Control-Allow-Origin: *`. Acceptable because every call must carry a valid user JWT, which the function verifies; tighten to your domains for production.
- `ai-complete` has no per-user usage caps or moderation — required before a public launch (documented in its README and catalog card).
- Demo-only fakes (`FakeVolunteerAuth`, `FakeAiTextClient`, `FakeSpeechInput`, `InMemoryCollabHub`, …) are labelled in code and docs as not production functionality.

## 9. Documentation vs code (task 9)

Two checkers were added and pass:
- `tool/check_docs.py` — every local path and Markdown link exists; every backticked type and function call in the documents is declared in the code (or is a known Flutter/Dart/package name, or a documented historical name).
- `tool/build_catalog.py --check` — the catalog is generated from data that is verified against the code: source files exist and define the component, each cited test file exercises it, and **test counts are counted from the test files**.

Mismatches found and fixed:
1. Forms README: single-choice `ChoiceFieldSpec` documented as chips — it renders a dropdown (chips only for `multiple: true`).
2. `StatCard.delta` is a fraction; demos, catalog example and README implied whole percentages.
3. `SqfliteRepository` import path changed by the split — docs and tests updated.
4. `CrudListScreen` shows "Try again" only when `onRefresh` is passed — now documented as a gotcha (found when the expense mini-app's error state had no retry).

## 10. Untested scenarios and external integration requirements (task 10)

Not exercised by any automated test or manual run, by component (also on each catalog card):

| Component (#) | Not verified | External requirement |
|---|---|---|
| Supabase bootstrap (53) | Initialising against a live project | Supabase project; `--dart-define` URL + publishable key |
| AuthService (55) | Every sign-in flow (email, OAuth, Apple, OTP, reset, delete) | Supabase Auth providers, redirect URLs, Apple/Google developer setup |
| EdgeFunctionClient (56), AI Text Client (126), ai-complete (128) | Calls to deployed functions; a live Gemini response | Deployed functions; `GEMINI_API_KEY` secret |
| StorageUploader (57) | Real uploads, signed URLs | Storage bucket + RLS policies |
| PresenceRoom (58), Real-time collaboration Supabase transport (125) | Realtime channels between devices | Realtime enabled; private-channel policy |
| SupabaseRepository (99) | All of it (no unit tests) | Table with `id` primary key, RLS, Realtime for `watchAll` |
| OfflineFirstRepository (124) | Against a real remote; on the web (unsupported) | A remote repository; SQLite platform |
| PurchasesGateway (60) | Store purchases | RevenueCat project, store products |
| Connectivity (59) | The plugin's live stream | Device |
| ReminderScheduler (71, 107) | Notification delivery | Device, notification permission, Android desugaring (automated by create_app) |
| Permission helper (72) | OS prompts | Device, usage strings |
| MediaPicker (101) | Camera / gallery / file dialogs | Device; iOS `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` |
| QR scanner (102) | Camera scanning | Device with camera |
| OCR (103) | ML Kit recognition | Android (minSdk 21+) or iOS 15.5+ |
| Location (104) | GPS | Device, location permission and usage strings |
| ShareService (105) | System share sheet | Device |
| Voice (123) | Device speech recognition | Microphone; Android `RECORD_AUDIO` + RecognitionService query; iOS mic/speech usage strings |
| OfflineQueue, JsonCache, SqfliteRepository (51, 52, 97) | Mobile SQLite (tested via desktop FFI SQLite); web | sqflite on a device; not the web |
| All | Physical-device runs; iOS/macOS builds; screen-reader passes (TalkBack/VoiceOver) | A Mac for Apple builds; devices |
| QUICK_START §7 | The Supabase setup steps end to end | A Supabase project |
