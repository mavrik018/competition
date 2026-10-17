# Competition Toolkit — showcase gallery

A runnable gallery of the toolkit's components. It depends on the package by path (`competition_toolkit: path: ../`) and runs entirely on **fakes and in-memory data**: no Supabase project, API key, camera, microphone or GPS is needed, so it works on an emulator, a phone or the web.

```bash
flutter run
```
```bash
flutter test
```

## What's inside

| Section | Demos |
|---|---|
| UI elements | buttons & inputs (variants, loading, PIN, tags) · cards & charts (stat/action cards, line chart with comparison, donut, sparkline, gauge, heatmap) · animations (counter, checkmark, shake) |
| Feedback & sheets | status banners, `runWithLoading`, overlay, bottom sheet, empty/error views |
| Forms | `DynamicForm` with every field type |
| Device features | QR generation + parsing, CSV export preview |
| Screens | dashboard · CRUD list (search, filter, sort, swipe-delete + Undo) · list/detail · agenda calendar · analytics · profile · settings · OTP (code `123456`) |
| Smart features | matching · recommendations · priority scoring · risk scorecard (sliders) · trends, forecasts & insights · scheduling · gamification · automation rules · contextual actions · personalization · accessibility (live preview + contrast checker) · voice commands · real-time collaboration (two replicas, simulated lag) |
| AI | `AiAssistant` with a scripted fake model and an "AI available" switch that shows the rule-based fallbacks |
| **Mini-apps** | Expense tracker · Volunteer match · Shared shopping list — complete flows built only from toolkit pieces (see below) |

## What is simulated (and labelled as such)

| Demo | Stand-in | The real thing |
|---|---|---|
| Voice commands | `FakeSpeechInput` replays scripted phrases | `DeviceSpeechInput` (speech_to_text) + mic/speech permissions |
| Real-time collaboration | `InMemoryCollabHub` connects two documents in one app | `SupabaseBroadcastTransport` between devices |
| AI assistant | `FakeAiTextClient` returns canned replies | `EdgeFunctionAiClient` → `supabase/functions/ai-complete` → Gemini |
| QR | generation and parsing are real; scanning is not shown | `QrScannerView` on a device with a camera |

Not in the gallery because they need a device or a database: QR scanning, OCR, location, media picking, sharing, PDF sharing and `OfflineFirstRepository` (the last is covered by tests with an in-memory SQLite database).

## Mini-apps (`lib/mini_apps/`)

| Mini-app | Pieces combined | What the tests cover |
|---|---|---|
| Expense tracker | TabShell · CrudListScreen + DynamicForm sheet · CrudController + **PrefsRepository** (persists, incl. web) · dailySeries / analyzeTrend / generateInsights · StatCard, line & donut charts · StatusBanner · toCsv | empty state, invalid + valid input, insights tab, CSV export, persistence across restart, error + retry, empty insights |
| Volunteer match | AuthFormScreen + ActionController (labelled fake auth) · session switch · ListDetailScaffold · SmartMatcher · XP, levels, badges · ProfileTemplate | invalid email, wrong password + loading state, ranking order, detail page, badge unlock, profile XP, sign-out |
| Shared shopping list | CollaborativeDocument over InMemoryCollabHub · VoiceInputButton + FakeSpeechInput + VoiceCommandParser · OfflineBanner · EmptyView | typing, partner sync, offline hold + reconnect, voice add, unrecognised phrase |

**Lesson recorded from building them:** keep one `ProviderScope` above `MaterialApp`. The volunteer app first created its own scope inside its route; the detail page that `ListDetailScaffold` pushes on phones then crashed with "No ProviderScope found", because pushed routes live under the Navigator.

## Tests

`test/gallery_test.dart` (4 tests) and `test/mini_apps_test.dart` (7 tests) run at phone size (390×844), so a layout overflow fails the test. The gallery test:
- opens and closes **every** demo and checks no exception or overflow occurs;
- the AI demo labels real output "AI" and fallbacks "Rule-based fallback";
- the collaboration demo: an item added on phone A appears on phone B;
- the voice demo: the scripted phrase is parsed into the `add_task` intent.

The `android/`, `ios/`, `web/` and `windows/` folders are the standard `flutter create` platform folders; `android/app/build.gradle.kts` enables core library desugaring (required by `flutter_local_notifications`). Verified builds: web, Android debug APK, Windows debug. To run the device implementations (not the fakes), add the platform setup listed in `lib/12_common_features/README.md` and `lib/13_smart_features/README.md`.
