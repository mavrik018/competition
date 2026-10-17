# Flutter Architecture Decision Handbook

*For a 4–5 hour competition, where you must build fast **and** defend every choice to a strict technical interviewer.*

This handbook does three jobs:
1. **Decide.** Eight decision trees take you from an unknown problem statement to a stack in the first 15 minutes.
2. **Build.** Eighteen decision records each give a default, its alternatives, and a working example from this toolkit (`lib/NN_*`).
3. **Defend.** Each record ends with interview questions, model answers and failure scenarios. A rapid-fire drill closes the book.

No technology here is "the best". Every recommendation is a **default under stated conditions**, with the conditions that would change it.

---

## 0. How to read the labels

Every recommendation carries one of these tags, so you know (and can tell a judge) where it comes from.

| Tag | Meaning |
|---|---|
| **[Official]** | Stated in Flutter/Dart documentation or the package's own pub.dev page. Checked October 2026; see the sources in §8. |
| **[Toolkit]** | What this toolkit implements and tests. A fact about the code in this repo. |
| **[Preference]** | My engineering judgement for a 4–5 hour competition. Defensible, but other competent engineers would choose differently. |

Two official facts frame everything else:
- Flutter's architecture guide labels its own advice *Strongly recommend*, *Recommend* or *Conditional*, and says it is "recommendations rather than steadfast rules". **[Official]**
- On state management, the same guide says "the decision comes down to personal preference", and the options page says the best choice "depends on the app's complexity, your team's preferences, and the specific problems you need to solve". **[Official]** So a judge cannot fault you for picking Riverpod over Bloc. They *can* fault you for not knowing why.

---

## 1. The competition playbook

### 1.1 Time budget for 4–5 hours  **[Preference]**

| Phase | Time | Output |
|---|---|---|
| Read & decide | 0:00–0:15 | Run the decision trees (§3). Write the stack and the 3 core user flows at the top of the README. |
| Skeleton | 0:15–0:45 | Theme, navigation shell, one model, one repository (in-memory first), one screen wired end to end. |
| Core flows | 0:45–2:45 | The three flows working on in-memory or local data. Commit after each. |
| Persistence / backend | 2:45–3:30 | Swap the in-memory repository for SQLite or Supabase. The screens should not change. |
| Differentiator | 3:30–4:15 | One smart feature (§13 of the toolkit) the judges will remember, explained honestly. |
| Polish & defend | 4:15–5:00 | Empty/error/loading states, accessibility pass, 3–5 tests, README "Architecture decisions" section, rehearse answers. |

**Rule of thumb:** a working, explainable app with in-memory data beats a half-wired Firebase app. Leave backend integration until the flows work, behind an interface, so it is a swap, not a rewrite.

### 1.2 The default stack and when to leave it

| Concern | Default | Leave the default when… |
|---|---|---|
| Architecture | Views → Riverpod notifiers (view models) → repositories → services **[Official layers]** | — (keep the layers; scale the *number* of classes) |
| State | `setState` for widget-local state; Riverpod `Notifier`/`AsyncNotifier` for shared state **[Preference]** | The team knows Bloc well; or the app is tiny (`setState` + `ChangeNotifier` only) |
| Navigation | `Navigator.push` + `TabShell` **[Preference]** | Deep links, web URLs, auth redirects or >6 routes → go_router **[Official: Recommend]** |
| Local data | `Repository<T>` in memory → `SqfliteRepository` **[Toolkit]** | Only settings → SharedPreferences; heavy relational queries → Drift |
| Backend | None (local-only) **[Preference]** | Multi-user, sharing, cross-device, server-side secrets → Supabase (or Firebase) |
| Errors | Typed exceptions → `AppException.from(e).message` **[Toolkit]** | — |
| Smart feature | Rule-based (`13_smart_features`) **[Preference]** | Free text the rules can't parse → `14_ai` with a fallback |
| Tests | Unit tests on logic + 1–2 widget tests **[Official: test layers separately]** | — |

### 1.3 What judges reward  **[Preference]**
- A **clear boundary** between UI and data ("my screens never call Supabase directly").
- **Honest naming.** "Rule-based priority score", not "AI prioritisation".
- **Handled unhappy paths**: loading, empty, error, offline.
- **Knowing your tradeoffs**: "I chose X; I'd switch to Y if Z."
- **Tests on the logic that matters**, not coverage numbers.

---

## 2. Architecture diagrams

### 2.1 Layers and separation of concerns  **[Official layers, Toolkit names]**

```
┌──────────────────────────── UI layer ────────────────────────────┐
│  View (Widget)                    View model (Notifier)           │
│  • renders state                  • holds UI state (AsyncValue)    │
│  • forwards events  ───────────▶  • exposes commands (save, delete)│
│  • no business logic  ◀─────────  • calls repositories             │
│  e.g. CrudListScreen              e.g. CrudController<T>           │
└───────────────────────────────────────┬──────────────────────────┘
                                        │ depends on (abstract)
┌──────────────────────────── Data layer ──────────────────────────┐
│  Repository<T>  (source of truth for one data type)               │
│  • caching, retries, error mapping, sync                          │
│  InMemoryRepository · SqfliteRepository · SupabaseRepository       │
│  OfflineFirstRepository (local + remote + queue)                  │
│                         │                                          │
│  Services (stateless wrappers around one data source)              │
│  sqflite Database · SupabaseClient · ApiClient · EdgeFunctionClient│
└───────────────────────────────────────────────────────────────────┘
   Optional domain layer (use-cases) only when logic merges several
   repositories, is complex, or is reused by several view models. [Official: Conditional]
   Pure logic (scoring, trends, rules) lives in plain Dart functions:
   13_smart_features, 11_utilities — testable without Flutter.
```

### 2.2 Unidirectional data flow  **[Official: Strongly recommend]**

```
        user taps "Save"
              │  event
              ▼
   View ── calls ──▶ ref.read(tasksProvider.notifier).save(task)
                              │
                              │ 1. state = optimistic list   (UI updates now)
                              │ 2. await repository.save(task)
                              │ 3a. success → keep state
                              │ 3b. failure → restore old state, rethrow
                              ▼
                    Repository ──▶ Service (SQLite / HTTP)
                              │
   View ◀── rebuilds ── ref.watch(tasksProvider)  (new immutable List<Task>)

   State goes down, events go up. Widgets never mutate data directly.
```

### 2.3 State update lifecycle (Riverpod `AsyncNotifier`)  **[Toolkit: CrudController]**

```
 build() ──▶ AsyncLoading ──▶ AsyncData(items) ◀─────────────┐
                    │                                         │
                    └──▶ AsyncError(e) ── Retry: ref.invalidate┘

 save(x):  AsyncData(old) ─▶ AsyncData(old+x) ─▶ (write ok)   AsyncData(old+x)
                                            └─▶ (write fails) AsyncData(old) + throw
 Rules: never assign state inside build(); after every await check ref.mounted.
```

### 2.4 Persistence and offline-first sync  **[Toolkit: OfflineFirstRepository; Official pattern: offline-first]**

```
 write(item)                         sync()  (on reconnect / resume / pull-to-refresh)
   │                                   │
   ▼                                   ▼
 Local DB (SQLite) ◀── reads      1. PUSH  OfflineQueue ──▶ remote.save / delete
   │  instant, works offline           │   newer server copy? → drop (conflict lost, reported)
   ▼                                   │   transient error?   → retry with backoff
 OfflineQueue (pending ops)            │   permanent error?   → drop, report
   (durable, per user)                 ▼
                                  2. PULL  remote.getAll ──▶ merge into local
                                           last-write-wins by updatedAt
                                           skip items with unsent local edits
```

### 2.5 Real-time collaboration  **[Toolkit: CollaborativeDocument]**

```
 Phone A                         transport                        Phone B
 doc.set('item:1', {...})        (Supabase broadcast,              doc.values
   │ stamp = (counter+1, 'A')     in-memory hub in tests)            ▲
   ├─ apply locally ─▶ UI                                            │
   └─ send {'type':'op'} ─────────────────────────────────▶ apply if stamp is newer
                                                              (Lamport max + replica tie-break)
 Late, reordered or duplicated messages → same final state (CRDT).
 New device sends 'hello' → peers reply with full 'state'.
```

### 2.6 AI integration  **[Toolkit: 14_ai]**

```
 Widget ─▶ AiAssistant.classify(text, labels)
              │ wrap user text in <<< >>> (treat as data)
              ▼
         EdgeFunctionAiClient ──JWT──▶ Edge Function ──server-held key──▶ LLM
              │                          validates input, caps tokens, maps errors
              ▼
         validate reply (must be one of your labels / valid JSON / keep numbers)
              │ ok                          │ invalid, timeout, offline, quota
              ▼                             ▼
     AiResult(value, source: ai)    AiResult(ruleBasedValue, source: fallback)
```

---

## 3. Decision trees

Answer the questions in order; stop at the first leaf that fits. **[Preference]** unless marked.

### 3.1 Small vs medium vs complex application

```
How many core user flows and data types?
├─ ≤ 3 screens, 1 data type, no login ─────────────▶ SMALL
│     setState + one ChangeNotifier or Riverpod Notifier, Navigator.push,
│     in-memory or SharedPreferences, no repository interface needed (but cheap to add).
├─ 4–10 screens, 2–5 data types, maybe login ───────▶ MEDIUM  ← most competitions
│     Riverpod notifiers per feature, Repository<T> per data type,
│     TabShell + Navigator (go_router if deep links), SQLite or Supabase.
└─ multi-role, many relationships, real-time, offline sync, web URLs ──▶ COMPLEX
      Everything in MEDIUM + go_router with guards, use-cases where repositories
      combine, OfflineFirstRepository or realtime, more tests.
      In 4–5 h: build ONE complex slice well; stub the rest honestly.
```

### 3.2 Offline vs online vs offline-first

```
Must the app work with no network?
├─ No, and data is shared/live (chat, marketplace) ─────▶ ONLINE
│     Supabase/REST directly through a repository; OfflineBanner; disable writes offline.
├─ Yes, but data is personal and never leaves the device ▶ OFFLINE (local-only)
│     SqfliteRepository; no sync code at all.
└─ Yes, AND data must reach a server/other devices ──────▶ OFFLINE-FIRST
      ├─ reads only need to survive offline → JsonCache fallback ("local data as fallback") [Official pattern]
      └─ writes must work offline → OfflineFirstRepository (queue + last-write-wins) [Official pattern: offline-first writes]
      Budget: +45–90 min. Only do it if the brief says "poor connectivity", "field", "rural", "offline".
```

### 3.3 Single-user vs multi-user

```
Do two people ever see the same record?
├─ No ─────────────────────────────────────▶ SINGLE-USER: local-only, no auth needed.
│                                              (Add auth only if data must follow the user across devices.)
└─ Yes
   ├─ Same person, several devices ────────▶ auth + per-user rows (RLS: user_id = auth.uid()).
   ├─ Small groups (couple, team, class) ──▶ auth + membership table + RLS via membership;
   │                                          realtime if they edit at the same time.
   └─ Public / roles (admin, staff, user) ─▶ auth + role column/claims + RLS per role;
                                              never trust the client's idea of its role.
```

### 3.4 Local vs cloud persistence

```
What must the data survive?
├─ App restart only, small settings ───────────▶ SharedPreferences (PrefsStore). Not for critical data. [Official]
├─ App restart, lists/records, queries ─────────▶ SQLite (SqfliteRepository; Drift if many typed queries/joins)
├─ Reinstall / new device / other users ───────▶ Cloud: Supabase (SQL, RLS) or Firebase (document, offline cache built in)
└─ Large files (images, PDFs) ─────────────────▶ Cloud storage (StorageUploader) + only the path in the DB
```

### 3.5 Simple vs complex state

```
Who needs this state?
├─ One widget (text field, toggle, animation) ───────▶ setState / controllers in a StatefulWidget
├─ A screen and its children ───────────────────────▶ Riverpod Notifier (autoDispose) or ChangeNotifier
├─ Several screens / survives navigation ───────────▶ Riverpod provider (not autoDispose)
├─ Async data with loading/error ───────────────────▶ AsyncNotifier + AsyncValueView
└─ Event-heavy workflows needing an audit of transitions (multi-step checkout, game states)
                                                       ▶ Bloc (events → states) or a sealed-class state machine in a Notifier
```

### 3.6 Static vs real-time data

```
How fast must other users' changes appear?
├─ Never / on next launch ──────────▶ fetch on open + pull-to-refresh
├─ Within a minute ─────────────────▶ refresh on resume + periodic Timer (cancel in dispose)
├─ Within a second, server-owned ───▶ Supabase .stream() via SupabaseRepository.watchAll / Firestore snapshots
├─ Presence ("who's online") ───────▶ PresenceRoom (Realtime presence)
└─ Concurrent edits to the same doc ▶ CollaborativeDocument (CRDT over broadcast)
```

### 3.7 Basic vs complex navigation

```
├─ ≤ 6 screens, no deep links, mobile only ─────────▶ Navigator.push/pop + TabShell
├─ Auth gating only ───────────────────────────────▶ SessionGate as home (state machine, no router needed)
├─ Deep links, web URLs, back-button correctness on web,
│  redirects based on auth/onboarding, nested tab stacks ─▶ go_router + guardRedirect + RouterRefresh
└─ Fully custom transitions / dynamic page stacks ─▶ Navigator 2.0 (Router API) directly — rarely worth it in 5 h
```

### 3.8 AI-powered vs algorithmic functionality

```
Can you write down the rule?
├─ Yes (thresholds, weights, formulas) ─────────────▶ ALGORITHMIC (13_smart_features). Offline, testable, explainable.
├─ Mostly, but inputs are messy free text ──────────▶ HYBRID: AI extracts/classifies into YOUR schema,
│                                                      rules decide; rule-based fallback when AI fails.
├─ No: summarising, rephrasing, open questions ─────▶ AI via server function (14_ai), labelled, validated, with fallback.
└─ Safety-critical (health, money, legal) ──────────▶ ALGORITHMIC + human confirmation. Never let model output act alone.
```

---

## 4. Decision records

Each record answers the same ten questions. Code is from this toolkit unless marked *(sketch)*.

---

### D1. Application architecture and folder structure

**1. Situation.** Every app. In five hours the risk is not "too little architecture" but logic smeared across widgets, so you can't change storage, test a rule, or answer "where does this happen?".

**2. Recommended default.** Two layers plus pure logic, feature-first folders. **[Official layers: Strongly recommend; folder shape: Preference]**
```
lib/
  main.dart                 ProviderScope, theme, home
  core/                     theme, router/shell, shared widgets, errors (or import the toolkit)
  features/
    tasks/
      task.dart             immutable model + fromJson/toJson
      task_repository.dart  abstract Repository<Task> choice + provider
      tasks_controller.dart view model (Notifier/AsyncNotifier)
      tasks_screen.dart     view
      task_rules.dart       pure functions (scoring, validation) ← easiest thing to test
  …
test/features/tasks/…
```

**3. Reasoning.** Flutter's guide strongly recommends separate UI and data layers, repositories, MVVM-style views and view models, no logic in widgets, and unidirectional data flow. **[Official]** Feature-first folders keep everything about one flow together, so you edit one folder per change and can explain the app feature by feature. **[Preference]**

**4. Alternatives.** Layer-first (`models/`, `screens/`, `services/`); Clean Architecture with entities/use-cases/data sources per feature; a single `main.dart` for a throwaway prototype.

**5. Tradeoffs.** Gain: swappable storage, testable logic, a clear story. Sacrifice: a few more files than a single-file app. Full Clean Architecture triples the file count — that time comes out of features.

**6. When not to use it.** A one-screen calculator or game: a `StatefulWidget` plus a pure-logic file is enough. Don't add a domain layer by default; the guide marks it *Conditional* — add use-cases only when logic merges several repositories, is complex, or is reused. **[Official]**

**7. Implementation.** The toolkit's own layering: `CrudListScreen` (view) → `CrudController<T>` (view model) → `Repository<T>` (data) → `sqflite`/`SupabaseClient` (service).
```dart
final tasksProvider = AsyncNotifierProvider<CrudController<Task>, List<Task>>(
  () => CrudController((ref) => ref.watch(taskRepositoryProvider), idOf: (t) => t.id),
);
final taskRepositoryProvider = Provider<Repository<Task>>(
  (ref) => InMemoryRepository(idOf: (t) => t.id),       // swap for SqfliteRepository later
);
```

**8. Interview questions.**
- Q1. Where does business logic live, and how do you know it isn't in a widget?
- Q2. Why a repository if you only have one data source?
- Q3. When would you add a domain/use-case layer?

**9. Model answers.**
- A1. "In view models and in pure Dart functions like `scorePriority`. Widgets only lay out state and forward taps — if I can't unit-test a rule without `pumpWidget`, it's in the wrong place."
- A2. "The repository is the seam. Screens depend on `Repository<Task>`, so I built the flows against `InMemoryRepository` and swapped in SQLite without touching a screen. It's also where caching and error mapping go. Flutter's own guide strongly recommends it."
- A3. "When logic combines several repositories or is reused by several view models — for example 'complete task → award XP → check badges'. For single-repository CRUD a use-case would only forward calls."

**10. Failure scenarios.**
- *Widgets call the database directly* → impossible to test or swap. Fix: move the call into the repository; the widget calls a notifier command.
- *A "utils" folder becomes a junk drawer* → name files by what they decide (`priority_scoring.dart`), not by kind.
- *Over-engineering eats the clock* → if a class only forwards calls, delete it.

---

### D2. State management: setState, ChangeNotifier, Riverpod, Bloc

**1. Situation.** Any state shared beyond one widget, async loading/error states, or state that must survive navigation.

**2. Recommended default.** `setState` for ephemeral widget state; **Riverpod** `Notifier`/`AsyncNotifier` for shared and async state. **[Preference]** — Flutter documents `setState` as "the low-level approach to use for widget-specific, ephemeral state" **[Official]**, and states that the choice of package is a matter of app complexity and preference. **[Official]**

**3. Reasoning.** Riverpod gives dependency injection and state in one tool (Flutter's guide strongly recommends DI) **[Official]**; providers are overridable in tests (`ProviderScope(overrides: […])`), which makes fakes trivial; `AsyncValue` models loading/data/error explicitly; providers can be read outside the widget tree. The toolkit and three of the four source apps already use it, so you are faster with it. **[Toolkit/Preference]**

**4. Alternatives.**
| Option | Best when | Cost |
|---|---|---|
| `setState` | one widget's state | doesn't scale across screens |
| `ChangeNotifier` / `ValueNotifier` (+ `ListenableBuilder`) | small apps, no packages, the official MVVM samples | manual DI, manual loading/error states, easy to forget `dispose` |
| Riverpod 3 | medium apps, async data, testability | learning curve; `ref.watch` vs `ref.read` rules |
| Bloc / Cubit | event-driven flows, teams wanting strict event→state traceability | more boilerplate (events, states, blocs) |
| provider package | the Flutter guide's DI suggestion | less compile-time safety than Riverpod |

**5. Tradeoffs.** Riverpod: gain testability, async modelling and DI; sacrifice some ceremony and a concept your interviewer may probe (`autoDispose`, `ref.mounted`). Bloc: gain explicit, loggable transitions; sacrifice speed in a five-hour build.

**6. When not to use it.** Riverpod is overkill for a three-screen app with no shared state; use `setState` + a `ChangeNotifier`. Don't adopt Bloc (or Riverpod) for the first time during a competition — the best state tool is the one you can debug under pressure.

**7. Implementation.** One-shot actions with a spinner and error, from `08_state_management/action_controller.dart`:
```dart
final saveNoteAction =
    NotifierProvider.autoDispose<ActionController, AsyncValue<void>>(ActionController.new);

final save = ref.watch(saveNoteAction);
PrimaryButton(
  label: 'Save',
  isLoading: save.isLoading,
  onPressed: () async {
    final ok = await ref.read(saveNoteAction.notifier).run(() => repo.save(note));
    if (ok && context.mounted) Navigator.pop(context);
  },
);
if (save.hasError) Text(AppException.from(save.error!).message);
```
Rendering async state with all three branches: `AsyncValueView(value: ref.watch(notesProvider), onRetry: () => ref.invalidate(notesProvider), data: (notes) => NotesList(notes))`.

**8. Interview questions.**
- Q1. `ref.watch` vs `ref.read` — when do you use each?
- Q2. Why not just `setState` everywhere?
- Q3. What happens if an async method sets state after the screen is gone?
- Q4. Why Riverpod over Bloc here?

**9. Model answers.**
- A1. "`watch` in `build` to subscribe and rebuild; `read` in callbacks for one-off access. Watching in a callback would subscribe at the wrong time; reading in build would miss updates."
- A2. "`setState` is right for local state like a text field or an expanded tile. Shared state — the task list used by three screens — would need to be lifted and passed down by hand; a provider gives one source of truth and rebuilds only listeners."
- A3. "With `autoDispose` the notifier may be disposed mid-await. In Riverpod 3 I check `ref.mounted` after each await before touching `state`; in widgets I check `context.mounted`."
- A4. "Both are valid; Flutter doesn't prescribe one. Riverpod gives me DI and async states with less boilerplate, and I already know it, which matters in five hours. If the domain were a strict state machine with many events, Bloc's event log would be a reason to switch."

**10. Failure scenarios.**
- *Setting `state` inside `build()`* throws in Riverpod 3. Fix: return the initial value from `build`; schedule follow-up work. (This toolkit hit and fixed it in `SessionController`.)
- *Whole screen rebuilds on any change* → watch a narrower provider or `provider.select(...)`.
- *Leaked listeners/timers* → `ref.onDispose(timer.cancel)`; `dispose()` controllers in `State`.

---

### D3. Navigation: Navigator vs go_router

**1. Situation.** More than one screen; possibly auth gating, deep links, web URLs, tabs with their own stacks.

**2. Recommended default.** `Navigator.push` + a tab shell for mobile-only apps with ≤ ~6 screens and no deep links **[Preference]**; **go_router** as soon as you need URLs, deep links or redirect rules. Flutter's guide *recommends* go_router and calls it "the preferred way to write 90% of Flutter applications". **[Official]** go_router is published by flutter.dev and is feature-complete, focused on bug fixes and stability. **[Package docs]**

**3. Reasoning.** Imperative `Navigator` is the least code and the easiest to explain; most competition apps are mobile flows. go_router adds declarative routes, URL sync on the web, `redirect` for auth, and `StatefulShellRoute` for per-tab stacks.

**4. Alternatives.** Navigator 2.0 (Router API) directly; auto_route (code generation); beamer.

**5. Tradeoffs.** Navigator: gain speed and simplicity; lose URLs, deep links and centralised guards. go_router: gain declarative routing and redirects; pay route-table setup and a refresh mechanism for auth changes.

**6. When not to use it.** Navigator alone is a poor choice for web targets (browser back/refresh), share links, or role-based route protection. go_router is unnecessary for a single-flow kiosk or game.

**7. Implementation.** Auth gating without a router — `SessionGate` maps a sealed session state to screens:
```dart
SessionGate(
  state: ref.watch(sessionProvider),
  loading: (_) => const SplashScreen(),
  signedOut: (_) => const SignInScreen(),
  needsSetup: (_, userId) => ProfileSetupScreen(userId: userId),
  ready: (_, userId) => const HomeShell(),     // TabShell inside
)
```
With go_router, the toolkit's pure `guardRedirect` plus `RouterRefresh` (re-runs redirects when providers change):
```dart
GoRouter(
  initialLocation: '/splash',
  refreshListenable: RouterRefresh(ref, [sessionProvider]),
  redirect: (context, state) {
    final session = ref.read(sessionProvider);
    return guardRedirect(
      location: state.matchedLocation,
      isLoading: session is SessionLoading,
      isSignedIn: session is SessionReady,
    );
  },
  routes: [...],
);
```
`guardRedirect` is a plain function, so the routing rules are unit-tested without a router. **[Toolkit]**

**8. Interview questions.**
- Q1. How do you stop a signed-out user reaching `/admin`?
- Q2. What happens to a pushed route's state when you switch tabs?
- Q3. How do you return a result from a screen?

**9. Model answers.**
- A1. "A redirect evaluated on every navigation and on every auth change (`refreshListenable`). And — more importantly — the server enforces it with row-level security; a client guard is UX, not security."
- A2. "With `TabShell` each tab is kept alive in an indexed stack. With go_router I'd use `StatefulShellRoute` so each tab keeps its own navigation stack."
- A3. "`final picked = await Navigator.push<Item>(…)`, and the pushed screen calls `Navigator.pop(context, item)`; check `context.mounted` after the await."

**10. Failure scenarios.**
- *Redirect loop* (`/sign-in` ↔ `/`) → return `null` when already at the target; `guardRedirect` does this and is tested.
- *Using a `BuildContext` after an await* → `if (!context.mounted) return;` (the `use_build_context_synchronously` lint flags it).
- *Auth state changes but the router doesn't react* → missing `refreshListenable`.

---

### D4. Local persistence: SharedPreferences, SQLite, Drift, Hive alternatives

**1. Situation.** Anything that must survive an app restart.

**2. Recommended default.** SharedPreferences for small settings; SQLite via `Repository<T>` for records. **[Preference]**

**3. Reasoning (with sources).**
- shared_preferences: the legacy `SharedPreferences` API "will be deprecated in the future"; new code should use `SharedPreferencesAsync` or `SharedPreferencesWithCache`; writes may not be persisted when the call returns, so it "must not be used for storing critical data". **[Package docs]** The toolkit's `PrefsStore` is a typed wrapper for settings only.
- SQLite (sqflite) is mature, relational and queryable. The toolkit's `SqfliteRepository` stores JSON rows `(id, json, updated_at)`, so adding a model field needs no migration. **[Toolkit]**
- Drift (drift 2.35, verified publisher) adds typed queries, joins, migrations and reactive streams, and runs on Android, iOS, desktop and web — at the cost of code generation. **[Package docs]**
- Hive: `hive` 2.2.3 was last published about four years ago; `hive_ce` describes itself as "a spiritual continuation of Hive v2" and is actively published. **[Package docs]** Prefer `hive_ce` if you want Hive's key-value boxes.

**4. Alternatives.** Drift; hive_ce; Isar (check its current maintenance status before choosing); plain JSON files (`path_provider`); `flutter_secure_storage` for secrets only.

**5. Tradeoffs.**
| | Setup | Queries | Migrations | Web | Fits |
|---|---|---|---|---|---|
| SharedPreferences | 1 min | none | none | yes | settings, flags |
| sqflite + JSON rows | 10 min | in Dart | none needed | **no** (needs an ffi-web setup) | records, offline queue |
| Drift | 30+ min (codegen) | typed SQL, joins | yes, typed | yes | relational data, many queries |
| hive_ce | 10 min | key lookups | adapters | yes | object boxes, caches |

**6. When not to use it.** SharedPreferences for lists or anything you can't lose. sqflite when the competition targets the **web** — use Drift, hive_ce, or a backend instead. Drift if you have no time for `build_runner`.

**7. Implementation.**
```dart
// onCreate: (db, _) => SqfliteRepository.createTable(db, 'tasks')
final tasks = SqfliteRepository<Task>(
  db, table: 'tasks', idOf: (t) => t.id, toJson: (t) => t.toJson(), fromJson: Task.fromJson,
);
await tasks.save(task);                    // upsert
tasks.watchAll().listen(render);           // current list now and after each write
```

**8. Interview questions.**
- Q1. Why not keep the task list in SharedPreferences as JSON?
- Q2. How do you handle a schema change?
- Q3. How would this work on the web?

**9. Model answers.**
- A1. "The package's own docs say not to use it for critical data — writes can be lost — and there's no querying. Settings yes, records no."
- A2. "I store each record as a JSON column, so adding a field needs no SQL migration; `fromJson` gives the new field a default. With real columns or Drift I'd bump the version and write `onUpgrade`."
- A3. "sqflite doesn't support web out of the box. Because screens depend on `Repository<T>`, I'd swap in a web-capable store such as Drift or hive_ce, or a backend repository, without touching the UI."

**10. Failure scenarios.**
- *Database opened twice / closed during a write* → open once at startup and inject it through a provider.
- *Large JSON parsing janks the UI* → paginate, or decode with `Isolate.run`.
- *Corrupt or old local data after a model change* → tolerant `fromJson` with defaults; never crash on a missing key.

---

### D5. Backend: local-only, Supabase, Firebase, custom REST

**1. Situation.** Data must leave the device: multiple users, multiple devices, shared content, server-side secrets, or files.

**2. Recommended default.** **Local-only** unless the brief needs sharing or cross-device sync; then **Supabase** if you know SQL, **Firebase** if you know it better. **[Preference]**

**3. Reasoning.** Local-only removes auth, network errors and setup — the biggest time sink in a competition. Supabase gives Postgres (relations, constraints, joins), row-level security, auth, storage, realtime and Edge Functions with one client; the toolkit already wraps it (`10_backend`). Firebase gives a document store with built-in offline persistence (on by default on Android and Apple, opt-in on the web) **[Official]**, plus FCM and Crashlytics.

**4. Alternatives.** Custom REST API (`ApiClient`), PocketBase/Appwrite, a public open-data API.

**5. Tradeoffs.**
| | Gain | Sacrifice |
|---|---|---|
| Local-only | zero setup, works offline, private | no sharing, data lost on uninstall |
| Supabase | SQL + RLS, relations, Edge Functions | must write RLS policies; offline is your job |
| Firebase | offline cache built in, mature SDKs | document modelling, denormalisation, query limits |
| Custom REST | full control, any existing API | you build auth, errors, retries (`ApiClient` helps) |

**6. When not to use it.** Supabase/Firebase when the app is single-user and offline — you'd add failure modes for no benefit. Local-only when users must collaborate or the judges' brief mentions accounts/sharing.

**7. Implementation.** Same interface, different storage:
```dart
final taskRepositoryProvider = Provider<Repository<Task>>((ref) => SupabaseRepository<Task>(
  ref.watch(supabaseClientProvider),
  table: 'tasks', fromRow: Task.fromJson, toRow: (t) => t.toJson(), idOf: (t) => t.id,
  orderBy: 'updated_at',
));
// REST: final api = ApiClient(baseUrl: 'https://api.example.com/v1', authToken: token);
```
Configuration is injected at build time: `flutter run --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_PUBLISHABLE_KEY=…`.

**8. Interview questions.**
- Q1. Your Supabase key is in the app. Isn't that a leak?
- Q2. Why Supabase over Firebase (or vice versa)?
- Q3. What happens when the backend is down during the demo?

**9. Model answers.**
- A1. "That's the publishable (anon) key — it's designed to ship. What protects data is row-level security on every table. The `service_role` key, or any model API key, never goes in the client."
- A2. "My data is relational — users, groups, memberships — so Postgres with foreign keys and RLS fits. If the data were document-shaped and offline was critical, Firestore's built-in cache would tip it the other way."
- A3. "Reads fall back to the local cache (`JsonCache`), writes are queued (`OfflineQueue`), and the UI shows an offline banner. For the demo I can also run on the in-memory repository."

**10. Failure scenarios.**
- *RLS off or too broad* → anyone with the anon key reads everything. Enable RLS on every table; policy `user_id = auth.uid()`.
- *Startup crash when config is missing* → `initializeSupabase()` returns an error instead of throwing; show a "can't connect" screen.
- *Demo Wi-Fi fails* → keep an offline/demo mode on in-memory data.

---

### D6. Authentication and authorization

**1. Situation.** Data belongs to users, or features differ by role.

**2. Recommended default.** Email/password (or magic link/OTP) via the backend's auth; authorization enforced **on the server** (RLS / security rules); the client only mirrors it in the UI. **[Preference; server-side enforcement is standard security practice]**

**3. Reasoning.** Authentication = who you are; authorization = what you may do. Client checks can be bypassed by anyone calling the API with the public key, so they are UX only. A session state machine handles launch, sign-in, sign-out and profile setup in one place.

**4. Alternatives.** Social sign-in (on iOS, App Store guideline 4.8 requires an equivalent privacy-focused login option alongside third-party logins — check the current wording), anonymous auth then upgrade, no auth (device-local data).

**5. Tradeoffs.** Auth adds screens, failure paths and test accounts; skipping it in a single-user app saves 30–60 minutes. Social sign-in is one tap for users but needs platform configuration you may not finish in time.

**6. When not to use it.** Don't add accounts to a single-device personal app "for realism" — judges notice wasted scope. Never implement your own password hashing/storage.

**7. Implementation.**
```dart
final auth = AuthService(Supabase.instance.client, redirectUrl: 'com.example.app://login-callback');
await auth.signIn(email: email, password: password);
```
```sql
-- Authorization lives in the database (sketch)
alter table tasks enable row level security;
create policy "own tasks" on tasks for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
```
`UserProviderScope` rebuilds all providers when the user changes, so user A's cached data never shows to user B. **[Toolkit]** `OtpVerificationScreen` covers the code-entry step.

**8. Interview questions.**
- Q1. Where is authorization enforced?
- Q2. A user signs out and another signs in on the same phone. What could leak?
- Q3. How do you model roles?

**9. Model answers.**
- A1. "In the database with RLS policies keyed on `auth.uid()`. The app hides admin buttons, but even a modified client can't read other users' rows."
- A2. "Cached providers, the offline queue and local caches. I scope providers per user (`UserProviderScope`), key queues and caches by user id, and clear them on sign-out."
- A3. "A `role` on a profile or membership row, checked in RLS policies; the UI reads it only to show or hide features. The client never sends its own role as truth."

**10. Failure scenarios.**
- *Profile row missing after sign-up* → a `needsSetup` session state routes to profile setup instead of crashing.
- *Session check fails offline at launch* → `SessionCheckFailed` state with retry (fixed bug from the Couple app).
- *Account deletion fails but user is signed out* → stay signed in and show the error (fixed in `AuthService.deleteAccount`).

---

### D7. Data modeling and relationships

**1. Situation.** More than one entity, or entities that reference each other (users ↔ groups, recipes ↔ ingredients, tasks ↔ projects).

**2. Recommended default.** Immutable Dart classes with `fromJson`/`toJson`/`copyWith`, string ids generated on the client (UUID), `createdAt`/`updatedAt` on every record; relations by id. **[Official: immutable models Strongly recommend; rest Preference]**

**3. Reasoning.** Immutable models make state changes explicit (a new list, not a mutated one), which is what unidirectional data flow and `==`-based rebuilds rely on. Client-side ids let you create records offline and link them before the server sees them. `updatedAt` enables last-write-wins sync and "recently changed" sorting.

**4. Alternatives.** `freezed`/`built_value` code generation (the guide *recommends* them for immutable models) **[Official]**; Dart records for small value types; embedding child objects (document style) instead of separate tables.

**5. Tradeoffs.** Hand-written models: no build step, fully explainable, more typing. freezed: less typing, `copyWith`/equality for free, but codegen in a time-boxed event. Relations by id (normalised): no duplication, needs joins; embedding (denormalised): one read, but updates touch many copies.

**6. When not to use it.** Embedding when children are shared or edited independently (ingredients reused across recipes). Separate tables when the child is never queried on its own (a task's checklist) — embed it as JSON.

**7. Implementation.** *(sketch, the shape every toolkit repository expects)*
```dart
@immutable
class Task {
  const Task({required this.id, required this.title, this.projectId, this.done = false, required this.updatedAt});
  final String id;            // generateLocalId() — a UUID, works offline
  final String title;
  final String? projectId;    // relation by id
  final bool done;
  final DateTime updatedAt;   // last-write-wins + sorting

  Task copyWith({String? title, bool? done}) => Task(
    id: id, title: title ?? this.title, projectId: projectId,
    done: done ?? this.done, updatedAt: DateTime.now(),
  );
  factory Task.fromJson(Map<String, dynamic> j) => Task(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    projectId: j['projectId'] as String?,
    done: j['done'] as bool? ?? false,                 // tolerant defaults
    updatedAt: DateTime.tryParse('${j['updatedAt']}') ?? DateTime(2000),
  );
  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'projectId': projectId, 'done': done,
    'updatedAt': updatedAt.toIso8601String(),
  };
}
```
Relations in Postgres: `project_id uuid references projects(id) on delete cascade`, plus an index on the foreign key. Many-to-many: a join table (`group_members(group_id, user_id, role)`).

**8. Interview questions.**
- Q1. Why immutable models?
- Q2. Why generate ids on the client?
- Q3. One-to-many vs many-to-many — how did you model them?

**9. Model answers.**
- A1. "State changes become new objects, so equality-based rebuilds and undo work, and no widget can mutate shared data behind the notifier's back."
- A2. "Offline creation and linking: I can create a task and its subtasks before any network call. UUID collisions are negligible."
- A3. "One-to-many with a foreign key on the child; many-to-many with a join table that can also carry data like `role`. Small, owned lists — a checklist — are embedded as JSON because they're never queried alone."

**10. Failure scenarios.**
- *`fromJson` crashes on an old or partial record* → defaults for every optional field; never use `!` on external data.
- *Timezone bugs* → store UTC ISO strings; convert to local only for display.
- *Orphans after deleting a parent* → `on delete cascade` server-side, or delete children in the same repository call locally.

---

### D8. Networking, retries, caching, and error handling

**1. Situation.** Any HTTP or backend call: slow networks, timeouts, rate limits, server errors, malformed responses.

**2. Recommended default.** One client per backend with a timeout, typed errors, retries only for idempotent requests, user-safe messages, and a cache fallback for reads. **[Toolkit; retry rules are standard HTTP semantics]**

**3. Reasoning.** Retrying a POST can create duplicates; retrying GET/PUT/DELETE is safe. 5xx bodies can leak internals, so show your own message; 4xx messages describe the user's request and are fine to show. Repositories own caching and retries (the Flutter guide puts "caching, error handling, retry logic" in repositories). **[Official]**

**4. Alternatives.** `dio` (interceptors, cancellation), Supabase/Firebase SDKs (their own error types), `http` directly.

**5. Tradeoffs.** A wrapper adds one file but removes copy-pasted try/catch. Exponential backoff improves success on flaky networks but delays the error the user sees — cap total wait.

**6. When not to use it.** Don't retry non-idempotent writes without an idempotency key. Don't cache personalised data across users without keying by user id.

**7. Implementation.**
```dart
final api = ApiClient(baseUrl: 'https://api.example.com/v1', authToken: token);
try {
  final items = await api.get('/items', query: {'page': 2, 'q': null});   // retried on 5xx/429/timeouts
} on ApiException catch (e) {
  context.showError(e.message);          // user-safe; e.kind tells you which UI to show
}
```
Reads with a cache fallback (`JsonCache`): try the network → save the result → on failure return the cached copy, or rethrow if nothing was ever cached. Every caught error goes through `AppException.from(e)` so the UI shows one consistent message and `isOffline`/`isAuth`/`isRetryable` drive behaviour. **[Toolkit]**

**8. Interview questions.**
- Q1. Which requests do you retry, and how?
- Q2. What does the user see on a 500?
- Q3. How do you test retries without a server?

**9. Model answers.**
- A1. "Idempotent methods only, on network errors, timeouts, 429 and 5xx — two retries with 0.5 s × 2ⁿ backoff, or the server's `Retry-After`, capped at 30 s. POST isn't retried unless the endpoint is idempotent."
- A2. "'Something went wrong on our side, please try again' with a Retry button. The raw body goes to the log, not the screen."
- A3. "The `http.Client` and the wait function are constructor parameters, so tests use `MockClient` and an instant wait — the retry tests run in milliseconds."

**10. Failure scenarios.**
- *Infinite spinner* → every request has a timeout; every loading state has an error branch.
- *Stale cache shown as fresh* → show "Last updated …" or an offline banner when serving cached data.
- *JSON shape changed* → parse failures become a `badResponse` error, not a crash.

---

### D9. Offline-first architecture and synchronization

**1. Situation.** Users must create or edit data without a connection, and it must reach the server later (field work, poor connectivity, travel).

**2. Recommended default.** Only if the brief demands it: local database as the source of truth for the UI, a durable outbound queue, and a `sync()` that pushes then pulls with last-write-wins. **[Toolkit; matches the Official offline-first pattern]**

**3. Reasoning.** Flutter's offline-first guide describes reading strategies (local fallback, local-first stream, local only), writing strategies (online-only vs offline-first) and synchronisation via a sync flag, background sync and server push. **[Official]** The toolkit's `OfflineFirstRepository` is the "offline-first write + sync" variant with a durable queue instead of a per-row flag.

**4. Alternatives.** Read-only offline (cache fallback, no queued writes); Firestore's built-in offline persistence; per-row `synchronized` flag; CRDTs for concurrent edits.

**5. Tradeoffs.** Gain: the app never blocks on the network. Sacrifice: conflict rules, more states to explain, more tests. Last-write-wins is simple but loses one side of concurrent edits to the same item.

**6. When not to use it.** Online collaboration where stale data is harmful (bookings, payments, inventory with limited stock) — those need server confirmation. Small online-only apps — the extra 60+ minutes won't pay off.

**7. Implementation.**
```dart
final notes = OfflineFirstRepository<Note>(
  name: 'notes',
  local: SqfliteRepository(db, table: 'notes', idOf: (n) => n.id, toJson: (n) => n.toJson(), fromJson: Note.fromJson),
  remote: SupabaseRepository(client, table: 'notes', fromRow: Note.fromJson, toRow: (n) => n.toJson(), idOf: (n) => n.id),
  queue: OfflineQueue(db),
  idOf: (n) => n.id,
  updatedAtOf: (n) => n.updatedAt,
  toJson: (n) => n.toJson(),
  fromJson: Note.fromJson,
  isOnline: () async => ref.read(isOnlineProvider),
  userId: uid,
);
ref.listen(isOnlineProvider, (was, now) { if (was == false && now) notes.sync(); });
```
`sync()` returns a `SyncReport(pushed, pulled, dropped, pending, …)`; show `pending` in an offline banner and `dropped` as an error.

**8. Interview questions.**
- Q1. Two devices edit the same note offline. What happens?
- Q2. Why a queue instead of re-uploading everything?
- Q3. What if the user signs out with unsynced changes?

**9. Model answers.**
- A1. "Last-write-wins by `updatedAt`, both directions: a newer server copy beats a queued push (reported as dropped), and a pull never overwrites an item with unsent local edits. One edit is lost — acceptable for notes; for shared lists I'd use per-item keys or the CRDT document."
- A2. "The queue preserves order — create before update before delete — and survives restarts. It replays only what changed and backs off on failure."
- A3. "Queued ops are keyed by user id. I'd warn before sign-out if `pendingCount() > 0`; the next account never replays them."

**10. Failure scenarios.**
- *Device clock is wrong* → set `updatedAt` on the server (trigger) when it matters.
- *A permanently invalid write blocks the queue* → classify it as permanent (`isPermanentError`) so it is dropped and reported.
- *Sync requested while a previous run is still checking connectivity* → overlapping calls must queue a follow-up run (a bug the toolkit's tests caught and fixed).

---

### D10. Real-time updates

**1. Situation.** Other users' changes must appear without a refresh: chat, shared lists, live scores, presence.

**2. Recommended default.** Backend change streams for server-owned data (Supabase `.stream()` / Firestore snapshots); broadcast + CRDT only for concurrent editing of the same document. **[Preference]**

**3. Reasoning.** Streams of table changes give "live" with almost no code. Concurrent editing needs a merge rule that every device applies identically; a last-writer-wins map CRDT with Lamport timestamps converges even with late, reordered or duplicated messages. **[Toolkit; CRDT convergence is tested]**

**4. Alternatives.** Polling with `Timer.periodic`; pull-to-refresh; push notifications (FCM) as a refresh signal; WebSockets to your own server.

**5. Tradeoffs.** Streams: instant, but every client holds a connection and you must handle reconnects. Polling: simple, cheap to explain, slower and wasteful. CRDT: robust merging, but per-key granularity (not text editing) and tombstones grow.

**6. When not to use it.** Real-time for data that changes daily (menus, timetables) — fetch on open. CRDTs for strictly ordered or validated operations (bank balances, seat booking) — those need server-side transactions.

**7. Implementation.**
```dart
// Server-owned data, live:
StreamBuilder(stream: supabaseRepo.watchAll(), builder: …);

// Concurrent editing:
final doc = CollaborativeDocument(
  replicaId: deviceId,
  transport: SupabaseBroadcastTransport(Supabase.instance.client, 'list:$listId'),
);
await doc.connect();
await doc.set('item:milk', {'title': 'Milk', 'done': false});
// Presence: PresenceRoom(...).onlineUserIds
```

**8. Interview questions.**
- Q1. How do you handle two users ticking the same item at the same time?
- Q2. What happens when the socket drops?
- Q3. Why not just poll every 5 seconds?

**9. Model answers.**
- A1. "Each change carries a Lamport counter plus the device id. Every device keeps the greatest stamp per key, so all devices agree on the winner without a server deciding, regardless of message order."
- A2. "Changes are applied locally first. On reconnect the device sends 'hello' and peers reply with their full state; applying it is idempotent. Broadcast keeps no history, so I also persist `exportState()`."
- A3. "Polling is a fine fallback and simpler to explain, but it's up to 5 s stale and costs requests even when nothing changes. For a shared list, push feels instant."

**10. Failure scenarios.**
- *Duplicate messages double-apply* → idempotent merge (CRDT) or upserts by id.
- *Subscriptions leak when leaving the screen* → cancel in `dispose` / `ref.onDispose`.
- *Realtime not enabled on the table* → the stream never emits; check backend settings first.

---

### D11. Performance and rendering

**1. Situation.** Long lists, images, charts, animations, large JSON, low-end demo devices.

**2. Recommended default.** Lazy lists (`ListView.builder`), `const` widgets, narrow rebuilds, sized images, heavy work off the UI isolate; measure in profile mode before optimising. **[Official performance guidance]**

**3. Reasoning.** Flutter's performance best practices: keep `build()` cheap, avoid rebuilding large subtrees, build lists lazily, use `saveLayer`-triggering effects (opacity, clipping) sparingly, and profile with DevTools rather than guessing. **[Official]**

**4. Alternatives.** `RepaintBoundary` around frequently animating parts; `compute`/`Isolate.run` for parsing; pagination (`PaginationController`); caching computed values in the notifier.

**5. Tradeoffs.** Premature optimisation costs time and readability. Profile one slow screen, fix the top cause, move on.

**6. When not to use it.** Don't add isolates for small JSON (spawn cost > parse cost). Don't wrap everything in `RepaintBoundary` (memory).

**7. Implementation.**
```dart
ListView.builder(
  itemCount: items.length,
  itemBuilder: (_, i) => TaskTile(key: ValueKey(items[i].id), task: items[i]),
);
final doneCount = ref.watch(tasksProvider.select((s) => s.value?.where((t) => t.done).length ?? 0));
final parsed = await Isolate.run(() => decodeBigJson(raw));         // only for large payloads
Image.network(url, cacheWidth: 300);                                // decode at display size
```
The toolkit's charts are `CustomPainter`s with pure geometry functions (`plotPoints`, `donutSweeps`), so painting does no allocation-heavy layout. **[Toolkit]**

**8. Interview questions.**
- Q1. Your list of 2,000 items is janky. What do you check first?
- Q2. Why `const`?
- Q3. How do you know it's fixed?

**9. Model answers.**
- A1. "That it's a lazy `ListView.builder`, that tiles don't do work in `build` (formatting, sorting), that images are decoded at display size, and that I'm not rebuilding the whole list when one item changes."
- A2. "A `const` widget is canonicalised and skipped on rebuild, so subtrees that never change cost nothing."
- A3. "DevTools performance view in profile mode — frame times under the budget — not debug mode, which is much slower."

**10. Failure scenarios.**
- *Sorting/filtering inside `build`* → compute once in the notifier or memoise.
- *Huge images* → `cacheWidth`/`cacheHeight`, thumbnails on upload.
- *Animations keep running off-screen* → dispose controllers; respect reduce-motion.

---

### D12. Async operations and lifecycle management

**1. Situation.** Futures, streams, timers and controllers that outlive (or under-live) the widgets that started them.

**2. Recommended default.** Own every resource and dispose it; check `context.mounted` / `ref.mounted` after every await; react to app resume with a lifecycle listener. **[Official lint: use_build_context_synchronously; Preference for the rest]**

**3. Reasoning.** Most async bugs are "something finished after its screen was gone": `setState` after dispose, navigation with a stale context, state set on a disposed notifier, timers firing forever.

**4. Alternatives.** `FutureBuilder`/`StreamBuilder` for display-only async; `AsyncNotifier` to keep async out of widgets; `AppLifecycleListener` for resume/pause.

**5. Tradeoffs.** `FutureBuilder` is quick but re-runs the future if created in `build`; notifiers cache and expose loading/error but need a provider.

**6. When not to use it.** Don't create futures inside `build` for `FutureBuilder` — store them in state or a provider.

**7. Implementation.**
```dart
// Timers that survive app suspension correctly — CountdownController computes
// remaining time from an end timestamp, not by counting ticks.
final _debouncer = Debouncer(delay: const Duration(milliseconds: 300));
TextField(onChanged: (q) => _debouncer.run(() => ref.read(searchProvider.notifier).search(q)));
@override
void dispose() { _debouncer.dispose(); super.dispose(); }

// After awaits:
final ok = await ref.read(saveNoteAction.notifier).run(() => repo.save(note));
if (ok && context.mounted) Navigator.pop(context);
```
Riverpod 3: inside notifiers, `if (!ref.mounted) return;` after awaits; `ref.onDispose(subscription.cancel)`.

**8. Interview questions.**
- Q1. What does `context.mounted` protect against?
- Q2. A countdown shows the wrong time after the phone sleeps. Why?
- Q3. How do you refresh data when the app returns to the foreground?

**9. Model answers.**
- A1. "Using a context whose widget was removed while I awaited — navigating or showing a snackbar from a dead screen throws or targets the wrong route."
- A2. "Counting `Timer.periodic` ticks drifts or pauses while suspended. Store the end time and compute `end - now` on each tick."
- A3. "`AppLifecycleListener(onResume: () => ref.invalidate(itemsProvider))`, or trigger `sync()` there."

**10. Failure scenarios.**
- *"setState() called after dispose()"* → check `mounted`; cancel timers and subscriptions in `dispose`.
- *Double submit* → disable the button while loading (`AppButton(isLoading: …)`); `ActionController` ignores re-entry.
- *Unhandled future error* → `unawaited(...)` only with a catch; log via `debugPrint`.

---

### D13. Responsive layout

**1. Situation.** Judges may run your app on a tablet, a desktop window or the web; phones vary from 320 to 430 logical pixels wide; users enlarge text.

**2. Recommended default.** Design for phone first; adapt at the Material 3 width classes — compact < 600, medium 600–839, expanded ≥ 840 — using the *available* width (`LayoutBuilder`), not the device type. **[Breakpoints: Material/Android window size classes; approach: Preference]**

**3. Reasoning.** Width-based layouts work in split screens and resizable windows; device-type checks don't. Two layouts (single column; list + detail / rail) cover nearly every competition app.

**4. Alternatives.** `MediaQuery.sizeOf(context)` for screen-level decisions; `flutter_screenutil`-style scaling (the toolkit deliberately avoids it: scaling text by screen size fights the user's text-size setting); fixed max-width centred content (`MaxWidthFrame`).

**5. Tradeoffs.** Adaptive layouts cost test time per breakpoint. Max-width-only is fastest but wastes tablet space.

**6. When not to use it.** Don't build three bespoke layouts for a phone-only brief — constrain width and move on.

**7. Implementation.**
```dart
ResponsiveBuilder(
  compact: (_) => const TaskList(),
  expanded: (_) => const Row(children: [SizedBox(width: 360, child: TaskList()), Expanded(child: TaskDetail())]),
);  // falls back to the next smaller builder when one is missing
ResponsiveGrid(minItemWidth: 160, children: statCards);   // 2 columns on phones, more on tablets
// TabShell switches its bottom bar to a NavigationRail at ≥ 840 px; ListDetailScaffold
// pushes a page on phones and shows two panes on wide screens.
```

**8. Interview questions.**
- Q1. Why `LayoutBuilder` instead of checking `isTablet`?
- Q2. How do you test layouts?
- Q3. What breaks at 200% text size?

**9. Model answers.**
- A1. "What matters is the space my widget has. A tablet in split view is phone-width; a desktop window can be any width."
- A2. "Widget tests set `tester.view.physicalSize` to phone and tablet sizes; overflows fail the test. The showcase gallery test runs every demo at 390×844."
- A3. "Fixed-height rows and single-line labels. I avoid fixed heights for text, allow wrapping, and test with a larger `textScaler`."

**10. Failure scenarios.**
- *RenderFlex overflow on small phones* → `Expanded`/`Flexible`, `Wrap`, scrollable bodies.
- *Keyboard covers the input* → scrollable form; sheets add `viewInsets` (as `showAppBottomSheet` does).
- *Unreadable line lengths on desktop* → cap content width (~640–840 px).

---

### D14. Security, secrets, and input validation

**1. Situation.** Any app with a backend, user input, files or third-party APIs.

**2. Recommended default.** No secrets in the client; server-side authorization; validate on the client for UX **and** on the server for safety; least-privilege keys. **[Standard security practice]**

**3. Reasoning.** Anything in the app binary — including `--dart-define` values — can be extracted. Publishable keys (Supabase anon, Firebase config) are designed to be public and rely on RLS/security rules. Secret keys (service role, payment, model API keys) belong in server functions. **[Toolkit docs; standard practice]**

**4. Alternatives.** `flutter_secure_storage` for tokens on device (Keychain/Keystore); App Check / attestation to reduce abuse; rate limiting at the server.

**5. Tradeoffs.** A server function adds a deploy step and latency; it's the only way to keep a secret secret.

**6. When not to use it.** Don't put user passwords or tokens in SharedPreferences; don't roll your own crypto or password storage.

**7. Implementation.**
```dart
AppTextField(label: 'Email', isRequired: true, validator: Validators.email());
AppTextField(label: 'Age', validator: Validators.number(min: 13, max: 120));
AppTextField(label: 'Website', validator: Validators.url());
// Files: check size, extension AND content before upload
final problem = const FileRules(maxBytes: 5 * 1024 * 1024, allowedExtensions: {'jpg', 'png', 'pdf'})
    .check(picked.name, picked.bytes);     // a renamed .exe → .jpg fails the content sniff
```
Server side: RLS on every table; the `ai-complete` function validates input length, verifies the JWT and keeps `GEMINI_API_KEY` in secrets.

**8. Interview questions.**
- Q1. Where's your API key?
- Q2. Client-side validation is enough, right?
- Q3. How do you stop prompt injection?

**9. Model answers.**
- A1. "The public Supabase key is in the build via `--dart-define`; it's designed to be public and RLS protects the data. The model API key is only in the Edge Function's secrets — the app sends the user's JWT."
- A2. "No. Client validation is for fast feedback. A modified client or direct API call skips it, so constraints and policies live in the database or server too."
- A3. "You can't fully. I wrap user text as data, accept only outputs from an allowed set (labels, a JSON schema), and never let model output trigger an action without user confirmation."

**10. Failure scenarios.**
- *Secret key committed to Git* → rotate it immediately; removing the commit isn't enough.
- *Unbounded input* → length limits in the form and on the server; the Edge Function caps prompt size.
- *Error messages leak internals* → user-safe messages via `AppException`; details only in logs.

---

### D15. Testing strategies

**1. Situation.** You need confidence that the core flows work, and evidence for the judges, in very little time.

**2. Recommended default.** Unit tests for pure logic and repositories/view models; one or two widget tests for the main flow; fakes over mocks. **[Official: test components separately and together — Strongly recommend; use fakes — Strongly recommend]**

**3. Reasoning.** Pure functions (scoring, validation, parsing) are fastest to test and most likely to hide bugs. Fakes injected through providers test behaviour (inputs → outputs) rather than which methods were called, so they survive refactors. **[Official]**

**4. Alternatives.** `mocktail` mocks; golden tests (fragile across platforms); `integration_test` on a device for end-to-end flows.

**5. Tradeoffs.** Each test costs minutes; pick the ones that protect your demo. Integration tests are the most convincing and the slowest.

**6. When not to use it.** Don't chase coverage. Don't test framework behaviour (that `Text` shows text).

**7. Implementation.**
```dart
test('overdue and important is critical', () {
  final p = scorePriority(PriorityInput(due: yesterday, importance: 5), now: now);
  expect(p.band, PriorityBand.critical);
});

testWidgets('adds a task', (tester) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [taskRepositoryProvider.overrideWithValue(InMemoryRepository(idOf: (t) => t.id))],
    child: const MaterialApp(home: TasksScreen()),
  ));
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  expect(find.text('New task'), findsOneWidget);
});
```
The toolkit uses an in-memory SQLite (`sqflite_common_ffi`), `http/testing`'s `MockClient`, `fake_async` for timers, and labelled fakes (`FakeMediaPicker`, `FakeSpeechInput`, `FakeAiTextClient`, `InMemoryCollabHub`).

**8. Interview questions.**
- Q1. What did you test, and why those?
- Q2. Mocks or fakes?
- Q3. How do you test code that uses the current time?

**9. Model answers.**
- A1. "The rules the judges will see — priority scoring and validation — plus the main add/delete flow as a widget test. They protect the demo; UI cosmetics aren't worth the minutes."
- A2. "Fakes: a real in-memory implementation of the interface. Tests assert on results, not on call sequences, so refactoring internals doesn't break them. Flutter's guide recommends the same."
- A3. "Inject a clock (`now:` parameters, `clock:` constructor args) or use `fake_async` to advance time instantly."

**10. Failure scenarios.**
- *Flaky tests from real time or network* → inject clocks and clients.
- *`pumpAndSettle` times out* → an infinite animation (spinner) is running; use `pump(duration)`.
- *Tests pass, app crashes on device* → plugin code isn't exercised by unit tests; run the real device path once before the demo.

---

### D16. Scalability and maintainability

**1. Situation.** The judges ask "how would this grow?" — more features, users, developers, data.

**2. Recommended default.** Scale by adding features, not layers: the same feature folder shape, one repository per data type, rules as data, interfaces at every external boundary. **[Preference, grounded in the Official layering]**

**3. Reasoning.** Repositories that never depend on each other, view models per screen and dependency injection keep change local. **[Official]** Business rules as JSON (`rule_conditions.dart`) change without a release. Pagination and server-side filtering handle data growth.

**4. Alternatives.** Packages per feature (melos monorepo); use-case layer; generated code (freezed, drift, riverpod_generator).

**5. Tradeoffs.** Each abstraction is a cost now for flexibility later. In five hours, add one where you can name the change it enables.

**6. When not to use it.** Don't build plugin systems, generic base classes for one subclass, or microservices.

**7. Implementation.** Rules as data instead of code:
```dart
final model = RiskModel.fromJson(await loadJson('assets/risk_rules.json'));  // or a table / remote config
final result = model.assess({'attendance': 0.7, 'lateSubmissions': 4});
// result.level, result.reasons — change thresholds without shipping a new build
```
Growth path for data: `CrudController` (whole list) → `PaginationController` (pages) → server-side search.

**8. Interview questions.**
- Q1. What breaks first with 100× users?
- Q2. A new developer joins. Where do they start?
- Q3. How would you add a feature without touching others?

**9. Model answers.**
- A1. "Loading whole lists. I'd paginate (`PaginationController`), filter on the server, add database indexes on foreign keys and sort columns, and move heavy aggregation into SQL or a function."
- A2. "The README's architecture section, then one feature folder — they all have the same shape: model, repository, controller, screen, rules."
- A3. "A new folder with its own repository and providers; the shell gets one new tab or route. Cross-feature effects go through events (the automation engine) rather than direct calls."

**10. Failure scenarios.**
- *God notifier* holding the whole app's state → split by feature.
- *Copy-pasted widgets drift apart* → shared components (the toolkit's `02_ui_elements`).
- *Magic numbers in widgets* → rules objects (`PriorityRules`, `InsightConfig`) or JSON.

---

### D17. Accessibility

**1. Situation.** Every app; it's also an easy differentiator that strict judges check.

**2. Recommended default.** Semantic labels on custom controls, 48×48 tap targets, contrast ≥ 4.5:1 for body text, support text scaling and reduce-motion, test with the `flutter_test` accessibility guidelines. **[Official: Flutter accessibility docs and flutter_test guidelines; WCAG 2.x thresholds]**

**3. Reasoning.** Material widgets are mostly accessible by default; custom painters, gesture detectors and icon-only buttons are where apps fail. The guideline matchers catch tap-target, label and contrast problems automatically.

**4. Alternatives.** Manual TalkBack/VoiceOver passes (best, slowest); the Semantics debugger.

**5. Tradeoffs.** 20 minutes of work buys a credible answer to a common judge question. Full screen-reader testing of every flow is rarely possible in five hours — test the main flow.

**6. When not to use it.** Never skip it entirely; at minimum label icon buttons (`tooltip:`) and check contrast.

**7. Implementation.**
```dart
IconButton(tooltip: 'Delete task', icon: const Icon(Icons.delete), onPressed: delete);  // tooltip = label
AccessibleTapTarget(label: 'Remind me', onTap: remind, child: const Icon(Icons.alarm, size: 18));
announce(context, '3 results found');                         // screen-reader announcement
meetsWcag(foreground, background);                            // 4.5:1 normal text
MaterialApp(builder: (context, child) => AccessibilityScope(preferences: prefs, child: child!));

testWidgets('meets accessibility guidelines', (tester) async {
  final handle = tester.ensureSemantics();
  await tester.pumpWidget(const MyApp());
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  handle.dispose();
});
```

**8. Interview questions.**
- Q1. How does a screen-reader user know what your chart shows?
- Q2. What's the minimum tap target?
- Q3. How do you support users who are sensitive to motion?

**9. Model answers.**
- A1. "The chart has a semantic summary — 'Line chart, from 30 to 64, high 70' — and the same numbers appear as text nearby."
- A2. "48×48 logical pixels on Android (44×44 points on iOS). Small icons get a larger hit area without growing visually."
- A3. "Animations check `MediaQuery.disableAnimations` and jump to the end state; the app also has an in-app reduce-motion setting."

**10. Failure scenarios.**
- *Icon-only buttons read as "button"* → add `tooltip` or `Semantics(label:)`.
- *Colour as the only signal* (red = overdue) → add text or an icon.
- *Layout breaks at large text* → wrap, scroll, avoid fixed heights; test at 2×.

---

### D18. Integration of AI or external services

**1. Situation.** The brief invites "smart" features, or an external API (maps, weather, payments, AI) is central.

**2. Recommended default.** Algorithmic first; AI only where rules can't cope (free text), always through your own server, with validated output, an honest label and a rule-based fallback. External APIs behind an interface with a fake. **[Toolkit; Preference]**

**3. Reasoning.** Rule-based features run offline, are deterministic, testable and explainable — exactly what a strict interviewer probes. AI adds latency, cost, quota, nondeterminism and injection risk; a fallback keeps the demo alive when the Wi-Fi or quota dies.

**4. Alternatives.** On-device ML (ML Kit for OCR/labels — no key, no network); calling a model API directly from the app (never with a secret key); third-party SDKs with their own auth.

**5. Tradeoffs.**
| | Rule-based (13) | AI via server (14) |
|---|---|---|
| Offline | yes | no |
| Same input → same output | yes | no |
| Explainable | fully | partly |
| Handles messy free text | poorly | well |
| Cost / setup | none | key, function, quota |

**6. When not to use it.** AI for anything safety-critical (dosage, money) without human confirmation; AI where a formula exists (priority, risk, totals); "AI" labels on rules.

**7. Implementation.**
```dart
final ai = AiAssistant(ref.read(aiTextClientProvider));
final category = await ai.classify(expense.note,
    labels: {'food': ['lunch', 'cafe'], 'transport': ['bus', 'uber']}, fallbackLabel: 'other');
Text(category.value);
if (!category.usedFallback) const Chip(label: Text('AI'));   // honest labelling
// Rephrase is rejected if any number changed:
final nicer = await ai.rephrase(insight.message);
```
Server: `supabase/functions/ai-complete` verifies the JWT, validates and caps input, holds the key, and maps provider failures to stable error codes.

**8. Interview questions.**
- Q1. Is this AI?
- Q2. What if the model returns something invalid?
- Q3. What does it cost and what if you hit the quota mid-demo?

**9. Model answers.**
- A1. "The scoring and insights are rule-based statistics — deterministic and explainable. Only the summary and the free-text classification use a language model, and the UI labels which is which."
- A2. "The reply must be one of my labels, valid JSON with my keys, or keep every number from the source. Anything else falls back to the rule-based result, so the user never sees a broken answer."
- A3. "Small per call with a lite model, but I'd add per-user daily caps in the function before launch. If the quota runs out, every feature degrades to its fallback."

**10. Failure scenarios.**
- *Network or quota failure during the demo* → fallbacks; keep `FakeAiTextClient` for an offline demo build and **say it is scripted**.
- *Model invents numbers* → validation (`numbersIn`) rejects the reply.
- *API key leaked in the app* → rotate; move the call server-side.

---

## 5. Rapid-fire interview drill

Short answers you should be able to give without notes.

| Question | Answer |
|---|---|
| What's the difference between `StatelessWidget` and `StatefulWidget`? | Stateless rebuilds only from its inputs; Stateful owns mutable state across rebuilds via `State` and `setState`. |
| What triggers a rebuild? | `setState`, an `InheritedWidget`/provider the widget depends on changing, or a parent rebuilding it with new arguments. |
| `const` constructors — why? | Canonical instances; Flutter can skip rebuilding them. |
| Keys — when? | When widgets of the same type move/reorder in a list (`ValueKey(id)`), so state follows the item. |
| `Future` vs `Stream`? | One value later vs many values over time. |
| What is an isolate? | A separate thread of Dart execution with its own memory; use `Isolate.run` for CPU-heavy work. |
| Why immutable state? | Changes are explicit and comparable; no hidden mutation. |
| `ref.watch` vs `ref.read`? | Subscribe in build vs one-off in callbacks. |
| `autoDispose`? | Provider state is freed when nothing listens — good for screen-scoped state. |
| How is your data protected? | Row-level security on the server; the client key is public by design. |
| Where are secrets? | Only on the server (function secrets). Nothing secret is in the app. |
| Offline? | Local DB is the UI's source; writes queue and sync with last-write-wins. |
| Conflicts? | Newest `updatedAt` wins per item; concurrent list edits use a CRDT per key. |
| Why not Bloc? | Valid choice; Riverpod gave me DI + async with less code and I know it well. |
| Why not go_router? | No deep links or web URLs in this brief; Navigator is simpler. I'd switch if those appear. |
| What did you test? | Business rules (unit), main flow (widget), repository with an in-memory DB. |
| What would you do with another day? | Name the top 3 honestly: e.g. server-side caps, pagination, device test of the camera flow. |

### Phrases that defend well  **[Preference]**
- "I chose X **because** of requirement Y; I'd switch to Z **if** W."
- "That's rule-based, not AI — here's the rule."
- "The client check is for UX; the server enforces it."
- "That's a fake for the demo; the real implementation is behind the same interface — here."
- "I haven't verified that on a device; here's how I'd test it."

### Phrases that lose points
- "It's the best practice." (Whose? Under what conditions?)
- "Our AI predicts…" for a weighted formula.
- "It's secure because the key is hidden." (It isn't hidden.)
- "We didn't need error handling for the demo."

---

## 6. Failure-scenario playbook (during the competition)

| Symptom | Likely cause | Fix in minutes |
|---|---|---|
| Spinner never ends | Missing timeout / error branch | Add a timeout; render `AsyncValueView` with error + retry |
| "setState() called after dispose()" | Async work outlived the widget | `if (!mounted) return;` / cancel timers in `dispose` |
| Riverpod "state modified during build" | Assigning `state` in `build()` | Return the initial value; move work to a method |
| RenderFlex overflow | Fixed sizes on small screens / large text | `Expanded`, `Flexible`, `Wrap`, scroll view |
| Data disappears on restart | Kept in memory or SharedPreferences cache | Use `SqfliteRepository` / backend repository |
| Other user's data visible | RLS off or wrong policy | Enable RLS; `user_id = auth.uid()` |
| Works in debug, slow on device | Debug mode or heavy `build` | Profile mode; move work out of `build`; lazy lists |
| Backend down at demo | Network/venue Wi-Fi | Offline banner, cached reads, in-memory demo mode |
| AI call fails at demo | Quota/network | Rule-based fallback; labelled fake demo client |
| Web build crashes on storage | sqflite on web | Swap repository implementation (interface already there) |
| Icons show as boxes | Font package missing (e.g. `cupertino_icons`) | Add the package; rebuild (the toolkit hit this on the web build) |

---

## 7. Your 15-minute decision worksheet

Copy into the README at the start and fill it in; it becomes your defence script.

```
Problem in one sentence:
Users & roles:              single / multi (same person, group, public)
Core flows (max 3):         1.            2.            3.
Data types & relations:
Connectivity requirement:   online / offline / offline-first
Real-time requirement:      none / refresh / live / co-editing
Platforms:                  mobile / web / tablet
Stack:   state ___  navigation ___  local storage ___  backend ___  auth ___
Differentiator:             rule-based ___ (AI only for ___ with fallback ___)
Out of scope (say it):
Tests I will write:
```

---

## 8. Sources (checked October 2026)

Official and package documentation used for **[Official]** / **[Package docs]** tags:
- Flutter — Architecture recommendations (strength labels, go_router "preferred way to write 90%", fakes, DI): <https://docs.flutter.dev/app-architecture/recommendations>
- Flutter — Guide to app architecture (views, view models, repositories, services, optional domain layer): <https://docs.flutter.dev/app-architecture/guide>
- Flutter — Offline-first design pattern (read/write strategies, synchronisation): <https://docs.flutter.dev/app-architecture/design-patterns/offline-first>
- Flutter — State management options (`setState` for ephemeral state; choice depends on complexity and preference): <https://docs.flutter.dev/data-and-backend/state-mgmt/options>
- Flutter — Performance best practices: <https://docs.flutter.dev/perf/best-practices>
- Flutter — Accessibility: <https://docs.flutter.dev/ui/accessibility-and-internationalization/accessibility>
- go_router (flutter.dev, feature-complete, bug fixes and stability): <https://pub.dev/packages/go_router>
- shared_preferences (legacy API to be deprecated; not for critical data): <https://pub.dev/packages/shared_preferences>
- drift (typed SQL, all platforms including web): <https://pub.dev/packages/drift>
- hive (2.2.3, last published ~4 years ago) and hive_ce ("spiritual continuation of Hive v2"): <https://pub.dev/packages/hive>, <https://pub.dev/packages/hive_ce>
- flutter_riverpod 3.x: <https://pub.dev/packages/flutter_riverpod> · flutter_bloc 9.x: <https://pub.dev/packages/flutter_bloc>
- Cloud Firestore offline persistence (on by default on Android/Apple, opt-in on web): <https://firebase.google.com/docs/firestore/manage-data/enable-offline>
- Window size classes (compact < 600, medium 600–839, expanded ≥ 840; newer large/extra-large classes above 1200): <https://developer.android.com/develop/ui/compose/layouts/adaptive/window-size-classes>
- WCAG 2.x contrast minimum (4.5:1 normal text, 3:1 large text).

Toolkit references (**[Toolkit]**): `CATALOG.md` for every component; `lib/13_smart_features/README.md` for the 8-point write-ups of the smart features; `lib/14_ai/README.md` for the AI layer; `example/` for a runnable gallery.

Package versions move quickly. Re-check pub.dev on competition day if a choice depends on a specific version.
