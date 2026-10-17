# Competition playbook

How to turn an unknown problem statement into a finished, defensible Flutter app in 4–5 hours with this toolkit. Component numbers (#) refer to [CATALOG.md](CATALOG.md); architecture reasoning lives in [ARCHITECTURE_HANDBOOK.md](ARCHITECTURE_HANDBOOK.md); the mechanics of assembling an app are in [QUICK_START.md](QUICK_START.md).

**The one rule:** a small app that works end to end, handles its unhappy paths and that you can explain beats a large app that half-works. Every section below protects that.

---

## 1. Problem-statement analysis checklist (first 10 minutes)

Read the brief twice. Then answer each question in writing — the answers become your README's first section and your interview script.

**Users and value**
- [ ] Who is the primary user? (one sentence: "A student who…", "A volunteer coordinator who…")
- [ ] What is their problem, in their words? What do they do today instead?
- [ ] What single outcome must the app deliver? ("knows what to revise next", "finds a match within 2 km")
- [ ] Are there secondary users or roles (admin, teacher, partner)? Do they need *their own screens* or only data?

**Judging and constraints**
- [ ] What are the judging criteria and their weights? (innovation, UX, technical quality, impact, presentation…) → write them down; they drive prioritisation.
- [ ] Mandatory technologies, platforms or APIs? Target device (phone, tablet, web)?
- [ ] Is offline use, accessibility, privacy or real-time explicitly mentioned? (each changes architecture — see §3)
- [ ] Is there provided data or an API? Its format, rate limits, keys?
- [ ] What is the demo format? (live device, emulator, browser, video, slides; how many minutes)

**Data**
- [ ] List the nouns → candidate models (Task, Booking, Expense, Volunteer…). Keep ≤ 3 for 5 hours.
- [ ] For each: key fields, which are required, which are user-entered vs computed.
- [ ] Relationships (one-to-many? many-to-many?) and who owns each record.
- [ ] Does data need to leave the device (sharing, multiple devices, other users)?

**Flows**
- [ ] The 3 core user flows, each as "user does X → sees Y". Example: "adds an expense → sees it in the list and in this week's total".
- [ ] The *demo path*: the exact sequence you will show judges (it must be the first thing that works).
- [ ] Unhappy paths per flow: empty, invalid input, failure, offline, no permission.

**Risk scan**
- [ ] Anything that needs a device feature (camera, GPS, mic, notifications)? → plan a fake for the demo fallback.
- [ ] Anything that needs a backend or keys? → decide now if it is in or out (see §3).
- [ ] Anything ethically or legally sensitive (health, money, minors, location)? → plan the disclaimer and the "rule-based, not a diagnosis" wording.

---

## 2. Requirements prioritisation method

Use **MoSCoW + a 1–5 value/effort score**, anchored on the demo path.

1. List every candidate feature from §1 on one page.
2. Score each: **Value** (1–5: how much it serves the core outcome *and* the judging criteria) and **Effort** (1–5: from the toolkit's complexity — Low ≈ 1–2, Medium ≈ 3, High ≈ 4–5; +1 if it needs external setup).
3. Compute **Priority = Value × 2 − Effort**, then bucket:

| Bucket | Rule | Typical content |
|---|---|---|
| **Must** | The demo path cannot be shown without it | The 3 core flows, one model end to end, persistence (if data must survive), empty/error states |
| **Should** | Priority ≥ 5 and it reuses a toolkit component | Search/filter, dashboard stats, edit/delete, validation details, settings |
| **Could** | Nice, cheap, and isolated | One differentiator (§5), charts, export, accessibility extras |
| **Won't (say so)** | High effort, external setup, or off the demo path | Payments, real auth when single-user, complex admin panels, push notifications |

4. Build strictly **Must → one Should at a time → one Could**. Re-score after each checkpoint (§6): if you are behind, promote nothing.
5. Keep a visible "Out of scope" list in the README — judges reward knowing what you left out and why.

**Tie-breakers:** prefer features that (a) appear in the judging criteria, (b) are visible in the demo, (c) can be tested, (d) reuse a ✅ fully-tested component.

---

## 3. Starter architecture selection guide

Start every project from the starter (`dart run tool/create_app.dart`), then choose one of three shapes. Decision trees and tradeoffs: ARCHITECTURE_HANDBOOK §3.

| Shape | Choose when | Storage | Auth | Extra time | Pieces |
|---|---|---|---|---|---|
| **A. Local-only** (default) | Single user, personal data, offline is fine, no sharing | `PrefsRepository` (all platforms) → `SqfliteRepository` (mobile, more data) | none | 0 | Starter as is |
| **B. Cloud** | Accounts, sharing, several devices, other users' data, server secrets (AI keys) | `SupabaseRepository` | `AuthFormScreen` + `AuthService` + `SessionGate` | +45–90 min | #53–56, #99, #40, #37 |
| **C. Offline-first** | Brief says field work / poor connectivity / rural *and* data must reach a server | `OfflineFirstRepository(local: Sqflite, remote: Supabase)` | as B | +90–120 min | B + #51, #124, #23–24 |

Add-ons, independent of the shape:
- **Real-time** (live shared edits) → `CollaborativeDocument` #125 (or Supabase `.stream()` via `SupabaseRepository.watchAll` for server-owned data).
- **Web/tablet target** → `ResponsiveBuilder` / `ListDetailScaffold`; TabShell already adapts. Avoid sqflite on the web.
- **Deep links / web URLs / role-based routes** → go_router with `guardRedirect` #42 (the toolkit stays router-agnostic).

**State management:** Riverpod throughout (starter default); `setState` for widget-local state. **Navigation:** TabShell + `Navigator.push`; go_router only if the add-on above applies.

If unsure between A and B: **build A**, keep the `Repository` seam, and switch to B only once the Must list works. The swap is one provider line.

---

## 4. Component selection checklist

Go down the list; tick what the brief needs; use the numbered component instead of writing your own.

**Every app (already in the starter)**
- [ ] Theme + dark mode — #4, #5 · Tabs — #39 · Dashboard — #87 · CRUD list — #88 + #95 · Form — #82 · Settings — #93
- [ ] Loading / empty / error — #21, #22, #80 · Snackbars — #20 · Confirm dialogs — #26 · Validation — #32, #83

**Data shape**
- [ ] Browse → read details → #89 ListDetailScaffold · Dates/agenda → #90, #31 · Search/filter/sort → #96 (built into #88)
- [ ] Large/remote lists → #46 PaginationController · Offline cache for reads → #52 JsonCache

**Input**
- [ ] Long forms / surveys → #82 DynamicForm (JSON-driven) · Tags → #76 · Quantities → #30 · Consent → #34 · OTP → #86

**Output**
- [ ] Stats → #77 StatCard, #79 charts, #11 gauge, #16 heatmap, #17 bars · Analytics screen → #91
- [ ] Export / share → #106, #105 · Rich text → #19

**Device**
- [ ] Photos / files → #101 + #100 · QR → #102 · OCR → #103 · Location → #104 · Reminders → #71, #107 · Permissions → #72 · Voice → #123

**Backend**
- [ ] REST API → #98 · Supabase → #53–57, #99 · Presence → #58 · Connectivity → #59 · Payments → #60 (avoid in a competition)

**Quality**
- [ ] Accessibility → #122 (+ label icon buttons) · Responsive → #85 · Errors → #54 AppException

For each ticked component, check its **Status** in the catalog: ✅ drop in; 🟡 plan a device test; 🔌 budget setup time and keep a fake for the demo.

---

## 5. Differentiation feature selection matrix

Pick **one** differentiator that matches the domain and can be explained in one sentence. All of these run offline and are rule-based or statistical unless marked AI.

| Feature (#) | Best for domains | Wow | Effort | Risk | Data it needs | One-line defence |
|---|---|---|---|---|---|---|
| Smart priority scoring (#111) | tasks, tickets, maintenance, triage | ★★ | Low | Low | due date, importance | "Weighted, normalised factors with reasons; deterministic." |
| Insights (#115) + trends (#113) | habits, spending, health, study, energy | ★★★ | Low | Low | ≥ 7 days of logs | "Statistics that pass thresholds, written as sentences; every number is from the data." |
| Predictions / pace (#114) | goals, savings, syllabus, stock | ★★★ | Low | Med (needs history) | cumulative series, deadline | "Linear extrapolation, phrased 'at your current pace'." |
| Smart matching (#109) | mentoring, volunteering, roommates, tutoring, jobs | ★★★ | Med | Low | two lists with attributes | "Weighted criteria with hard constraints and a per-criterion explanation." |
| Recommendations (#110) | recipes, courses, events, products | ★★ | Med | Med (needs tags) | tags + likes | "Cosine similarity on tags + co-occurrence, with a reason per pick." |
| Risk scoring (#112) | wellbeing, at-risk students, safety, budgets | ★★★ | Low | Med (sensitive) | a few metrics | "Transparent JSON scorecard — screening, not diagnosis." |
| Smart scheduling (#117) | study planners, shifts, appointments | ★★★ | Med | Med | busy slots + tasks | "Greedy earliest-deadline-first with reasons for what didn't fit." |
| Gamification (#118) | habits, learning, recycling, volunteering | ★★ | Low | Low | completed actions | "Level curve and rule-based badges; fair ranks for ties." |
| Automation rules (#116) | inventory, budgets, reminders | ★★ | Med | Low | events | "IFTTT-style JSON rules, cooldowns, isolated handlers." |
| Contextual actions (#120) | home screens, daily routines | ★★ | Low | Low | time + a few facts | "Rules over context; dismissals respected." |
| Personalization (#121) | feeds, catalogues, reminders | ★★ | Low | Low | interactions | "Decayed preference scores, transparent and resettable." |
| Voice commands (#123) | cooking, accessibility, quick capture | ★★★ | Med | High (device, noise) | — | "OS speech-to-text + readable rules for meaning." |
| Real-time collaboration (#125) | shared lists, families, teams | ★★★ | High | High (backend) | — | "A last-writer-wins CRDT; converges despite reordering." |
| Offline-first sync (#124) | field work, rural, clinics | ★★ | High | High | backend | "Local source of truth, durable queue, last-write-wins." |
| Accessibility (#122) | public services, older users, health | ★★ | Low | Low | — | "WCAG contrast, text scaling, reduce motion, announcements." |
| AI assistant (#127, AI) | free-text summarise/classify/extract | ★★★ | Med | High (network, quota) | text | "Validated model output with a rule-based fallback, labelled honestly." |

**Choosing:** filter by domain → keep Low/Med effort → prefer Low risk → prefer what you can explain without notes. If the brief rewards "innovation", combine two Low-effort features (e.g. insights + predictions) rather than one High-risk one.

---

## 6. Development schedules

Times are cumulative. **Checkpoints** are hard: if a checkpoint is missed, cut the next optional block, not the polish block.

### 4-hour schedule

| Time | Block | Output | Checkpoint |
|---|---|---|---|
| 0:00–0:10 | Analyse (§1), prioritise (§2), choose shape (§3) | README top section: user, outcome, 3 flows, stack, out-of-scope | Written decisions |
| 0:10–0:20 | `create_app.dart`, run tests, rename model, palette | App runs with your model name | `flutter test` green |
| 0:20–1:30 | Core flows 1–2 on the starter (model fields, form, list, dashboard) | Demo path half works | Commit |
| 1:30–2:15 | Core flow 3 + detail/edit + persistence check | Demo path works end to end | **CP1: full demo path works** |
| 2:15–2:50 | One differentiator (§5, Low effort) | Visible on dashboard/detail | Commit |
| 2:50–3:20 | Unhappy paths: empty, invalid, error, offline; accessibility pass (labels, contrast, text scale) | §7 checklist mostly ticked | **CP2: nothing crashes** |
| 3:20–3:40 | Tests for your rules + one flow test; `flutter analyze` clean | Green tests | Commit |
| 3:40–4:00 | Build for the demo target, rehearse demo (§8), README decisions | Demo script | **CP3: build installed** |

### 5-hour schedule

| Time | Block | Output | Checkpoint |
|---|---|---|---|
| 0:00–0:15 | Analyse, prioritise, choose shape | README top section | Written decisions |
| 0:15–0:30 | `create_app.dart`, rename, palette, tabs | App runs | Tests green |
| 0:30–1:45 | Core flows 1–2 | Demo path half works | Commit |
| 1:45–2:30 | Core flow 3 + persistence (or swap to backend if shape B) | Demo path works | **CP1** |
| 2:30–3:00 | Should-haves: search/filter, edit, settings | | Commit |
| 3:00–3:45 | Differentiator (Low/Med effort), with its own unit tests | | **CP2: differentiator works and is tested** |
| 3:45–4:15 | Unhappy paths + accessibility + responsive check (phone + tablet width) | §7 ticked | Commit |
| 4:15–4:35 | Tests + analyze + fix | Green | **CP3** |
| 4:35–5:00 | Build, rehearse, README "Architecture decisions" + "Out of scope" | Demo ready | Installed build |

**Recovery rules:** stuck > 15 min on one bug → switch to the fake/in-memory version and note it; backend down → `InMemoryRepository`/`PrefsRepository`; device feature failing → its labelled fake (and say so in the demo).

---

## 7. Testing checklist

Automated (write these; the starter already covers the first six):
- [ ] **Forms:** required field empty → message; invalid format (email, number bounds) → message; valid → saved
- [ ] **Loading:** a slow action shows a spinner/disabled button; no double submit
- [ ] **Errors:** a failing repository shows an error *with* "Try again" (pass `onRefresh` to CrudListScreen)
- [ ] **Empty states:** first launch shows guidance, not a blank screen; "no matches" differs from "nothing yet"
- [ ] **Persistence:** add → rebuild the app → item still there
- [ ] **Navigation:** tabs switch; detail opens and back returns; dialogs/sheets return values
- [ ] **Your differentiator's rules:** 2–4 unit tests on the pure function (edge cases: empty data, ties, boundaries)

Manual (5 minutes before the demo):
- [ ] Phone width (360–390 px) and tablet width (≥ 840 px): no overflow stripes
- [ ] Text size at 200% (OS setting or `AccessibilityScope`): still readable
- [ ] Dark mode
- [ ] Rotate / resize (web)
- [ ] Airplane mode (if offline matters): banner shows, app doesn't hang
- [ ] Deny a permission once: the app explains and continues
- [ ] Kill and relaunch: data still there
- [ ] Screen reader quick pass on the demo path: buttons have names

Commands: `flutter analyze` · `flutter test` · build for the demo target.

---

## 8. Final demo checklist

**30 minutes before**
- [ ] Release/profile build installed on the demo device (or web build served); debug banner off
- [ ] Seed realistic demo data (not "test test"); clear embarrassing test entries
- [ ] Charge device; disable notifications; brightness up; screen mirroring tested
- [ ] Offline fallback ready: in-memory/demo mode or labelled fakes, in case Wi-Fi fails
- [ ] Backup: screen recording of the demo path

**The 3-minute story**
1. **Problem** (20 s): the user and their pain, in one sentence.
2. **Demo path** (90 s): the 3 core flows, live, no detours.
3. **Differentiator** (30 s): show it, then name it honestly ("rule-based priority score", "statistical insight").
4. **Quality** (20 s): one unhappy path (empty/error/offline), accessibility or responsive view.
5. **Architecture** (20 s): "screens → notifiers → repository → storage; I swapped storage in one line".

**During questions**
- [ ] Answer, then give the tradeoff: "I chose X because Y; I'd switch to Z if W."
- [ ] Never claim AI for rules; never claim a fake is real; say "not verified on a device" when true.
- [ ] Have `CATALOG.md` / your README open for exact names.

---

## 9. Technical interview preparation checklist

Be able to explain each of these **in two sentences** without notes (study notes in [INTERVIEW_PREP.md](INTERVIEW_PREP.md)):

**Architecture**
- [ ] The layers (view → view model/notifier → repository → service) and why logic isn't in widgets
- [ ] Why the repository interface exists and how you swapped storage
- [ ] Why one `ProviderScope` above `MaterialApp` (and the crash a nested one causes)

**State**
- [ ] `ref.watch` vs `ref.read`; `AsyncValue` states; optimistic update + rollback in `CrudController`
- [ ] Why `state` is never set in `build()`; `ref.mounted` / `context.mounted` after awaits

**Data**
- [ ] Your model, ids generated on the client, `updatedAt` and why
- [ ] Storage choice and its limits (PrefsRepository small data; sqflite not on web)
- [ ] Offline behaviour; conflicts (last-write-wins) if relevant

**Security**
- [ ] Where secrets live (nowhere in the app); publishable key + RLS; client validation is UX only

**Your differentiator**
- [ ] The exact rule/formula, its configurable parameters, two edge cases, and one limitation
- [ ] Why rule-based (deterministic, offline, explainable) instead of AI — or, if AI, the validation and fallback

**Testing**
- [ ] What you tested and why those; fakes vs mocks; what is *not* tested (device paths) and how you'd test it

**Honesty**
- [ ] Which parts are fakes in the demo, and what the real integration needs
- [ ] One thing you'd do with another day
