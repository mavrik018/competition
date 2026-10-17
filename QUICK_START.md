# Quick start — a working app in 5 minutes, then add pieces

The toolkit is a set of puzzle pieces: **starter template → screen templates → functionality modules → one differentiating feature.** This page takes you through each step with copy-paste code. Steps 1, 2 and 8 were run end to end during verification, and the modules in §3–6 are covered by the toolkit's tests and the mini-apps; **§7 (Supabase) needs a live project and was not run** — see [VERIFICATION_REPORT.md](VERIFICATION_REPORT.md).

Requirements: Flutter ≥ 3.38 / Dart ≥ 3.10 (verified on Flutter 3.44.1, Dart 3.12.1).

---

## 1. Create the app (one command)

From the toolkit folder:
```bash
dart run tool/create_app.dart green_route --dir .. --title "Green Route"
```
Options: `--org com.team`, `--platforms android,ios,web,windows` (default), `--minimal` (see below). It takes about a minute and produces a **self-contained app — the toolkit's code is copied in, nothing is imported from the toolkit package**:
1. runs `flutter create` for the platforms,
2. copies the starter (`templates/starter`) into `lib/` and `test/`,
3. copies the toolkit's source into **`lib/toolkit/`** (all 14 folders with their READMEs; with `--minimal`, only the 35 files the starter uses),
4. copies the toolkit tests for the copied files into `test/toolkit/` and the toolkit's lint rules (`analysis_options.yaml`),
5. adds exactly the packages the copied code imports to `pubspec.yaml`, with the toolkit's Dart SDK constraint,
6. enables Android core library desugaring if the reminders plugin was copied (without it the APK build fails), and copies `supabase/functions/ai-complete` if the AI client was copied,
7. runs `flutter pub get`.

Imports inside your app are your own package: `package:green_route/toolkit/06_screen_templates/crud_list_screen.dart` (the CATALOG's `package:competition_toolkit/` becomes `package:<your_app>/toolkit/`). The copied files are yours — read, edit or delete them; the toolkit folder can even be moved or deleted afterwards.

**Full or minimal?**

| | Default (full) | `--minimal` |
|---|---|---|
| Copied | all 127 toolkit files, 28 toolkit test files | 35 files the starter needs, 6 test files |
| Packages | all 23 toolkit packages (camera, OCR, payments, …) | 4 (`flutter_riverpod`, `shared_preferences`, `cupertino_icons` + a test helper) |
| Tests in the new app | 405 | 49 |
| Best when | you want everything at hand during the competition | you want a lean app where every file is one you can explain |

Add parts to any app later (copies the files, what they import, their tests and packages; files already in the app are never overwritten):
```bash
dart run tool/add_component.dart --app ../green_route smart_matching insights 12_common_features
```
Arguments are a folder, a file path, or a unique file name.

Then:
```bash
cd ../green_route
```
```bash
flutter test
```
```bash
flutter run -d chrome
```

**What you get** — a three-tab app that already handles forms, validation, persistence, empty/error states and theming:
```
lib/
  main.dart                       ProviderScope → App
  app.dart                        theme (palette), light/dark mode, TabShell (Home · Items · Settings)
  features/items/item.dart        the record (id, title, notes, importance, due, done, timestamps) + JSON
  features/items/items_providers.dart   storage (ONE line) + CrudController + priority sort
  features/items/items_screen.dart      CrudListScreen: search, filters, sorts, swipe-delete + Undo
  features/items/item_form.dart         DynamicForm in a bottom sheet (add/edit, validation)
  features/home/home_screen.dart        DashboardTemplate: counts + "Next" by rule-based priority score
  features/settings/settings_screen.dart  theme choice, delete-all with confirmation
  toolkit/                        the copied building blocks (01_design_system … 14_ai), each folder
                                  with its README; toolkit/README.md lists what was copied
test/app_test.dart               5 tests: empty state, invalid input, valid add, dashboard update,
                                 persistence across restart, error state, theme switch
test/toolkit/                    the toolkit's own tests for the copied files
```
**Where things go:** `lib/features/` is your app (data, screens, providers — one folder per thing); `lib/toolkit/` is the generic parts those screens use. Change a toolkit file when you need it to behave differently; it is your code now.
Items persist across restarts on **every platform including the web** (`PrefsRepository`).

---

## 2. Make it yours (10 minutes)

1. **Rename the record.** Rename `Item` → `Task` (or Report, Booking…) with your IDE's rename. Keep `id` and `updatedAt`.
2. **Add fields.** Add to the class, `copyWith`, `toJson`, `fromJson` (with a default), and add a spec to `item_form.dart`:
   ```dart
   const NumberFieldSpec(key: 'cost', label: 'Cost', min: 0, decimal: true, suffix: '€'),
   ```
   and read it in `_toItem`: `cost: (values['cost'] as num?)?.toDouble()`.
3. **Restyle.** In `app.dart`, change `palette` to `AppPalette.kitchenWarm` / `coupleNavy` / `taskIndigo`, or your own `AppPalette(primary: Color(0xFF0B6E4F))`.
4. **Rename tabs and icons** in `app.dart`.

---

## 3. Change storage (one line)

Everything reads `Repository<Item>` from `itemRepositoryProvider` in `items_providers.dart`. Swap the implementation; no screen changes.

| You need | Use | Setup |
|---|---|---|
| Any platform incl. web, small data (default) | `PrefsRepository<Item>(key: 'items', …)` | none |
| Mobile/desktop, larger data, offline | `SqfliteRepository<Item>(db, table: 'items', …)` | open a database, `SqfliteRepository.createTable` (§3a) |
| Accounts, sharing, multiple devices | `SupabaseRepository<Item>(client, table: 'items', …)` | Supabase project (§7) |
| Offline-first with sync | `OfflineFirstRepository<Item>(local: sqlite, remote: supabase, …)` | both of the above |
| Tests / demos | `InMemoryRepository<Item>(idOf: (i) => i.id)` | none |

**3a. SQLite** (not on the web):
```dart
// main.dart
final db = await openDatabase('app.db', version: 1,
    onCreate: (db, _) => SqfliteRepository.createTable(db, 'items'));
runApp(ProviderScope(overrides: [databaseProvider.overrideWithValue(db)], child: const App()));

// items_providers.dart
final databaseProvider = Provider<Database>((ref) => throw UnimplementedError());
final itemRepositoryProvider = Provider<Repository<Item>>((ref) => SqfliteRepository<Item>(
  ref.watch(databaseProvider), table: 'items',
  idOf: (i) => i.id, toJson: (i) => i.toJson(), fromJson: Item.fromJson,
));
```
(`import 'package:sqflite/sqflite.dart';` and add `sqflite` to your pubspec.)

---

## 4. Add screen templates

Each template takes data and callbacks; add it as a tab in `app.dart` or push it with `Navigator.push`.

| Screen | Code |
|---|---|
| List / detail (side by side on tablets) | `ListDetailScaffold<Item>(title: 'Browse', items: items, idOf: (i) => i.id, tileBuilder: (c, i, selected, open) => ListTile(title: Text(i.title), selected: selected, onTap: open), detailBuilder: (c, i) => Text(i.notes ?? ''))` |
| Calendar + agenda | `AgendaCalendar<Item>(events: withDue, dateOf: (i) => i.due!, itemBuilder: (c, i) => ListTile(title: Text(i.title)))` |
| Analytics | `AnalyticsTemplate(title: 'Stats', periods: {'Week': AnalyticsSnapshot(kpis: [...], trend: values, breakdown: segments)})` |
| Profile | `ProfileTemplate(name: name, stats: [ProfileStat('Done', '$done')], onEdit: edit)` |
| Sign-in | `AuthFormScreen(mode: AuthMode.signIn, isLoading: a.isLoading, errorText: err, onSubmit: (d) => …)` + an `ActionController` provider |
| Code verification | `OtpVerificationScreen(destination: email, onVerify: verify, onResend: resend)` |
| First-run | `OnboardingPager(slides: [...], onFinish: done)` |

Imports follow the folder: `package:<your_app>/toolkit/06_screen_templates/<file>.dart` (made with `--minimal`? copy the screen first: `dart run tool/add_component.dart --app <your app> 06_screen_templates`). Full parameters: [CATALOG.md](CATALOG.md) (#36–38, #85–93).

**Rule that avoids a crash:** keep the single `ProviderScope` in `main.dart` above `MaterialApp`. A `ProviderScope` placed inside a screen is invisible to routes it pushes (bottom sheets, detail pages) → "No ProviderScope found".

---

## 5. Add functionality modules

| Need | Module | Extra setup |
|---|---|---|
| Call a REST API | `ApiClient(baseUrl: …).get('/items')` (10) | none |
| Pick photos / files | `ref.read(mediaPickerProvider).pickImage(...)` (12) | iOS usage strings |
| Validate uploads | `const FileRules(maxBytes: …, allowedExtensions: {...}).check(name, bytes)` | none |
| Show / scan QR | `QrCodeView(data: QrUrl(uri).encode())`, `QrScannerView(onScanned: …)` | camera permission (device only) |
| Read text from photos | `MlKitTextRecognizer().recognizeFile(path)` → `extractFromText(text)` | Android/iOS only |
| Location / geofence | `ref.read(locationServiceProvider).currentPosition()`, `Geofence(...)` | location permission |
| Export / share | `toCsv(rows)`, `buildPdfReport(...)`, `ref.read(shareServiceProvider).shareFile(...)` | none |
| Daily reminder | `ReminderScheduler(...).scheduleDaily(...)` | notification permission; Android desugaring (done by create_app / add_component) |
| Voice commands | `VoiceInputButton(speech: ref.read(speechInputProvider), onResult: …)` + `VoiceCommandParser` | mic + speech permissions |

Platform setup details: [lib/12_common_features/README.md](lib/12_common_features/README.md) and [lib/13_smart_features/README.md](lib/13_smart_features/README.md). In tests and demos, override the provider with the labelled fake (`FakeMediaPicker`, `FakeLocationService`, `FakeShareService`, `FakeSpeechInput`, `FakeTextRecognizer`) — fakes are not production behaviour.

---

## 6. Add one differentiating feature

Pick with the matrix in [COMPETITION_PLAYBOOK.md §5](COMPETITION_PLAYBOOK.md#5-differentiation-feature-selection-matrix). Three common ones:

**Insights on the dashboard** (rule-based sentences from the user's data):
```dart
final days = dailySeries(items.where((i) => i.done), dateOf: (i) => i.updatedAt, valueOf: (_) => 1,
    from: DateTime.now().subtract(const Duration(days: 13)), to: DateTime.now());
final insights = generateInsights(days, config: const InsightConfig(metric: 'completed items'), now: DateTime.now());
// in sections: DashboardSection(title: 'Insights', child: Column(children: [for (final i in insights) InsightCard(insight: i)]))
```

**Matching** (who/what fits best, with reasons):
```dart
final ranked = SmartMatcher<Need, Offer>([
  MatchCriterion('Skills', weight: 3, required: true, score: (n, o) => coverage(n.skills, o.skills)),
  MatchCriterion('Distance', weight: 2, score: (n, o) => proximityScore(o.km, maxKm: 10)),
]).rank(myNeed, offers);   // r.percent, r.explanation, r.strengths()
```

**AI with a fallback** (only if the brief needs free text):
```dart
final ai = AiAssistant(ref.read(aiTextClientProvider));     // override with FakeAiTextClient in demos
final summary = await ai.summarize(item.notes ?? '');       // summary.usedFallback → label honestly
```
Real AI needs the `supabase/functions/ai-complete` function deployed with `GEMINI_API_KEY` ([lib/14_ai/README.md](lib/14_ai/README.md)).

---

## 7. Optional: Supabase backend (~30–45 min) — not verified (needs a project)

1. Create a project; copy the URL and **publishable** key (never the service-role key).
2. Run with config injected at build time:
   ```bash
   flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxx
   ```
3. In `main.dart`: `final error = await initializeSupabase();` before `runApp` (show a "can't connect" screen if `error != null`).
4. Create the table with row-level security:
   ```sql
   create table items (id uuid primary key, user_id uuid not null default auth.uid(),
     title text not null, payload jsonb, updated_at timestamptz not null default now());
   alter table items enable row level security;
   create policy "own items" on items for all using (user_id = auth.uid()) with check (user_id = auth.uid());
   ```
5. Swap the provider to `SupabaseRepository<Item>(ref.watch(supabaseClientProvider), table: 'items', fromRow: …, toRow: …, idOf: (i) => i.id)`.
6. Add sign-in with `AuthFormScreen` + `AuthService` and gate the app with `SessionGate`.

---

## 8. Verify before the demo

```bash
flutter analyze
```
```bash
flutter test
```
```bash
flutter build web
```
```bash
flutter build apk --debug
```
If an Android build fails with "Unable to establish loopback connection" on Windows, the temp path is too long for Gradle's sockets: set `_JAVA_OPTIONS=-Djdk.net.unixdomain.tmpdir=C:\gtmp` (any short existing folder) and retry. If `flutter build windows` says `generated_plugins.cmake` is missing, run `flutter pub get` first. If it fails with MSB3491 ("exceeds the OS max path limit"), move the project to a shorter folder.

Toolkit maintainers: `python tool/check_docs.py` (docs vs code), `python tool/build_catalog.py --check` (catalog vs code and test counts), `python tool/module_graph.py` (dependencies per file, no cycles).

---

## 9. Learn from working examples

`example/` is a runnable gallery (`flutter run -d chrome` inside it) with 28 component demos and **3 mini-apps** that combine pieces end to end:

| Mini-app | Pieces combined | Tests |
|---|---|---|
| Expense tracker (`example/lib/mini_apps/expense_tracker.dart`) | TabShell, CrudListScreen + DynamicForm sheet, CrudController + PrefsRepository, trends + insights, StatCard/line/donut charts, StatusBanner, CSV export | invalid/valid input, persistence across restart, error + retry, empty insights |
| Volunteer match (`example/lib/mini_apps/volunteer_match.dart`) | AuthFormScreen + ActionController (fake auth), ListDetailScaffold, SmartMatcher, XP/badges, ProfileTemplate | validation, wrong password + loading, ranking, detail navigation, badge unlock, sign-out |
| Shared shopping list (`example/lib/mini_apps/shared_list.dart`) | CollaborativeDocument (CRDT) over an in-memory hub, VoiceInputButton + parser (fake speech), OfflineBanner | sync, offline hold + reconnect, voice add, unknown phrase |
