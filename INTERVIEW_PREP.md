# Interview prep — simulated senior Flutter interview

A strict interviewer reviewing this toolkit's architecture. Each question has a model answer, the follow-up probe a senior engineer would use, and a **risk rating**: how likely you are to struggle. Ratings are a judgement based on how hard the concept is and whether the code came from your own four apps (familiar) or was written new in phase 2 (likely unfamiliar). Study notes for every high-risk area follow the transcript.

---

## Part 1 — The interview

### Q1. "Walk me through the architecture. Where does a tap on Save go?"
**Model answer.** "View → notifier → repository → storage. The screen calls `ref.read(tasksProvider.notifier).save(task)`. `CrudController` updates `state` optimistically, then awaits `repository.save`. On failure it restores the previous list and rethrows so the screen shows an error. The screen only *watches* the provider; it never touches storage. This is the layering Flutter's architecture guide strongly recommends."
**Probe.** "Why rethrow after rolling back?" → "So the caller decides the UX — snackbar with retry — while state stays consistent."
**Risk: Low** (you used this shape in your apps).

### Q2. "Why a `Repository<T>` interface? You only have one storage."
**Model answer.** "It's the seam. The starter uses `PrefsRepository`; switching to SQLite or Supabase is one provider line, and tests inject `InMemoryRepository`. It's also where caching, error mapping and sync live."
**Probe.** "What broke when you first wrote it?" → "`repository.dart` also contained the SQLite implementation, so anything using the interface imported sqflite — which doesn't run on the web. I split `SqfliteRepository` into its own file; the module graph check shows the interface now has zero dependencies."
**Risk: Low–Medium.**

### Q3. "In Riverpod 3, why must you never assign `state` inside `build()`?"
**Model answer.** "`build` computes the initial state; assigning during it throws in Riverpod 3 because the provider is mid-initialisation. Return the initial value and trigger follow-up work outside build. After any `await` in a notifier, check `ref.mounted` — an `autoDispose` provider can be disposed while waiting."
**Probe.** "What's `ref.watch` vs `ref.read`?" → "`watch` in build subscribes and rebuilds; `read` in callbacks is a one-off."
**Risk: Medium.**

### Q4. "The volunteer mini-app crashed with 'No ProviderScope found'. Explain."
**Model answer.** "The mini-app created its own `ProviderScope` *inside* a route. `ListDetailScaffold` pushes the detail page on the root `Navigator`, and pushed routes are children of the Navigator, not of the widget that pushed them, so the detail page couldn't see that scope. The fix is one `ProviderScope` above `MaterialApp`; tests override providers there."
**Probe.** "So how do you scope state per screen?" → "`autoDispose` providers, or families keyed by id — not nested scopes. `UserProviderScope` is the one deliberate exception: it wraps the whole app per account."
**Risk: High** (subtle; widget tree vs route tree).

### Q5. "How does offline-first sync handle conflicts?"
**Model answer.** "Last-write-wins by `updatedAt`, applied in both directions. Writes go to the local DB and a durable queue. `sync()` pushes queued ops oldest first; before a save it fetches the server copy and drops the op if the server's is newer, reported in `SyncReport.dropped`. Then it pulls, but skips items with unsent local edits so a stale server copy never overwrites them."
**Probe 1.** "What's lost with LWW?" → "Concurrent edits to different fields of the same item — the whole item wins. For lists edited concurrently I use per-key CRDT instead."
**Probe 2.** "What if device clocks are wrong?" → "LWW trusts `updatedAt`; set it in a database trigger when correctness matters."
**Probe 3.** "Two syncs at once?" → "Coalesced: while one runs, later calls share one follow-up run. A test caught the original bug — a call made right after reconnecting got the stale 'skipped offline' result of a run that started offline."
**Risk: High.**

### Q6. "Explain your real-time collaboration. Why is it correct?"
**Model answer.** "Each change is an op `(key, value, stamp)` where stamp = Lamport counter + replica id. Every replica keeps, per key, the op with the greatest stamp, compared counter-first then id. That comparison is a total order every device agrees on, and 'keep the max' is commutative, associative and idempotent — so applying the same ops in any order, any number of times, gives the same map. That's a last-writer-wins map CRDT. Deletes are tombstones so a late, older set can't resurrect a key."
**Probe 1.** "Why Lamport counters, not timestamps?" → "Clocks drift. On receiving an op, a replica sets its counter to max(local, received), so its next write is guaranteed 'later' than anything it has seen."
**Probe 2.** "Late joiner?" → "It sends hello; peers reply with their full state; applying it is idempotent. Broadcast has no history, so persist `exportState()` if nobody might be online."
**Probe 3.** "Text editing?" → "No — per-key granularity. Character-level editing needs a sequence CRDT like Yjs."
**Risk: High** (new concept).

### Q7. "Your API client retries. Which requests, and why not POST?"
**Model answer.** "Only idempotent methods — GET, PUT, DELETE — on network errors, timeouts, 429 and 5xx, with 0.5 s × 2ⁿ backoff or the server's Retry-After, capped at 30 s. Retrying a POST can create duplicates unless the endpoint supports idempotency keys. 5xx bodies aren't shown to users because they can leak internals; 4xx messages describe the user's request and are shown."
**Probe.** "How did you test it without a server?" → "`http.Client` and the wait function are injected: `MockClient` plus an instant wait."
**Risk: Medium.**

### Q8. "Is your 'smart' stuff AI?"
**Model answer.** "No. Priority, risk, insights, matching, recommendations and scheduling are rules and statistics: deterministic, offline, explainable, unit-tested. Only `14_ai` calls a model, through my own Edge Function, and every AI result is validated and falls back to the rule-based result. The UI labels which is which."
**Probe.** "How do you stop the model inventing numbers?" → "`rephrase` rejects any reply that doesn't contain every number from the source sentence; `classify` only accepts one of my labels; `extractFields` keeps only my keys."
**Risk: Low** — if you say it exactly this way.

### Q9. "Explain the priority score as if I'm a product manager, then as an engineer."
**Model answer.** PM: "Due soon, important, quick, or waiting long → higher, with the reasons shown." Engineer: "Four factors normalised to 0–1 — urgency rises linearly over a 7-day window and is 1 when overdue; importance (1–5) maps to 0–1; quick win is 1 when effort ≤ 1 h; age grows to 1 over 30 days. Weighted sum divided by the total weight, ×100. Overdue and importance ≥ 4 is forced to critical. Ties keep input order."
**Probe.** "Why normalise weights?" → "So people can tune them without making them add up to 1."
**Risk: Low–Medium.**

### Q10. "Recommendations — what's cosine similarity here?"
**Model answer.** "Tags as binary vectors: |A ∩ B| / √(|A|·|B|). It rewards shared tags but doesn't let items with many tags dominate. I blend it with co-occurrence ('people who liked X also liked Y', weighted by overlap / history size so heavy users count less) and popularity for cold start, and report the biggest contributor as the reason."
**Probe.** "Cold start?" → "No likes → only popularity contributes; no histories → only tags."
**Risk: Medium–High.**

### Q11. "Your insights say 'trending up'. On what basis?"
**Model answer.** "A least-squares line through the daily values. 'Flat' if the slope is under 2% of the average per day, or fewer than 3 points. I only state a trend when r² ≥ 0.3 — r² is the share of variance the line explains, so below that the 'trend' is mostly noise. Anomalies are values more than 2 standard deviations from the mean (z-score), needing at least 4 points."
**Probe.** "Forecast band?" → "± one residual standard error: √(Σ residual² / (n − 2))."
**Risk: High** (statistics vocabulary).

### Q12. "How do you schedule tasks? Is it optimal?"
**Model answer.** "Greedy: sort by earliest deadline, then priority, then longer first, and give each the earliest free slot that ends before its deadline, leaving a buffer. Not optimal — optimal placement is a constraint-satisfaction problem — but fast, predictable and explainable, and it reports why a task didn't fit."
**Risk: Medium.**

### Q13. "Where are your secrets? Your Supabase key is in the app."
**Model answer.** "That's the publishable key, designed to ship; row-level security protects the data. Config comes from `--dart-define`, nothing is hard-coded — I scanned the code for keys and tokens and found none. Model API keys live only in the Edge Function's secrets; the function verifies the user's JWT against `/auth/v1/user` before calling Gemini. CORS is open but every call still needs a valid user token."
**Probe.** "What's missing before launch?" → "Per-user usage caps and moderation in the AI function."
**Risk: Medium.**

### Q14. "How did you test platform features like the camera or GPS?"
**Model answer.** "Each sits behind an interface with a device implementation and a labelled fake. Logic — QR encode/parse, OCR extraction rules, geofences, file sniffing — is pure and unit-tested; the fakes test the flows. The device implementations themselves are marked 🔶 in the catalog: not unit-testable in `flutter test`. I built the showcase for Android, Windows and the web, but I haven't exercised the camera, GPS or microphone on a physical device."
**Risk: Low** — as long as you don't overclaim.

### Q15. "Why did you build a generator for your catalog?"
**Model answer.** "Docs drift. `tool/build_catalog.py` verifies that every card's source file defines the component, every cited test file exercises it, and **counts the tests itself**; `tool/check_docs.py` checks that every type and function named in the docs exists. They caught real mismatches — a form field documented as chips that's actually a dropdown, and a stat card example that passed 12 instead of 0.12."
**Risk: Low.**

### Q16. "Android build failed. Why, and how did you fix it?"
**Model answer.** "Two causes. First, Gradle couldn't open its local sockets — on Windows the JDK uses Unix-domain sockets in the temp folder, and the path was too long; pointing `jdk.net.unixdomain.tmpdir` at a short folder fixed it. Second, `flutter_local_notifications` requires core library desugaring in the app's Gradle file; I added it to the example and `create_app.dart` now adds it automatically."
**Risk: Medium.**

---

## Part 2 — Where you are most likely to struggle

| Area | Risk | Why | Study note |
|---|---|---|---|
| CRDT / Lamport clocks (#125) | **High** | New concept; "why is it correct" needs the algebra | N1 |
| Offline-first sync semantics (#124) | **High** | Several interacting rules (queue, LWW both ways, dirty items, coalescing) | N2 |
| Route tree vs widget tree (ProviderScope crash) | **High** | Subtle Flutter internals | N3 |
| Statistics vocabulary (#113–115) | **High** | r², residuals, z-scores | N4 |
| Recommendation maths (#110) | Medium–High | Cosine + normalised co-occurrence | N5 |
| Riverpod 3 lifecycle | Medium | build vs methods, mounted, autoDispose | N6 |
| Retry/idempotency (#98) | Medium | HTTP semantics | N7 |
| Security boundaries (#53, #128) | Medium | Publishable key vs secret, RLS, JWT check | N8 |
| Greedy scheduling (#117) | Medium | "Why not optimal?" | N9 |
| AI validation (#127) | Low–Medium | Why each check exists | N10 |

---

## Part 3 — Concise study notes

**N1 · LWW-map CRDT in five lines**
- An op = `(key, value or tombstone, stamp)`; stamp = `(counter, replicaId)`, compared counter first, then id.
- Each replica keeps, per key, the op with the **largest** stamp. "Max" is commutative + associative + idempotent ⇒ any delivery order, any duplicates → same result.
- Lamport rule: on receive, `counter = max(counter, op.counter)`; on local write, `counter + 1`. Your new write always beats what you've seen.
- Tombstones: deletes are ops too, so an older late "set" loses.
- Limits: per-key last-writer-wins (one concurrent edit to the same key is lost); tombstones grow; not for text.
*Say it in 30 s:* "Every change carries a logical timestamp plus device id; everyone keeps the biggest per key; that rule doesn't care about order or duplicates, so all devices converge."

**N2 · Offline-first sync rules**
1. Write: local DB + queue (durable, ordered, per user).
2. Push oldest first; transient error → stop and back off; permanent error → drop + report.
3. Before pushing a save, if the server copy is newer → drop (conflict lost) + report.
4. Pull: skip items with unsent edits; otherwise take the newer `updatedAt`.
5. Overlapping `sync()` calls → one follow-up run.
*Weak spots to admit:* trusts device clocks; pulls everything; whole-item conflicts.

**N3 · Why nested ProviderScopes break**
- `Navigator.push` / `showModalBottomSheet` insert the new route **under the Navigator**, not under the widget that called push.
- `ProviderScope.containerOf(context)` walks *up the element tree* → from a pushed route it never reaches a scope that lives inside another route.
- Rule: one `ProviderScope` above `MaterialApp`; per-screen state via `autoDispose`/families; per-account via `UserProviderScope` around the whole app.

**N4 · Statistics you'll be asked about**
- **Least squares:** the line minimising Σ(actual − predicted)²; slope = Σ(dx·dy)/Σ(dx²).
- **r² (0–1):** share of the variation the line explains; < 0.3 → don't claim a trend.
- **Residual standard error:** √(Σ residual² / (n − 2)) → the forecast's ± band.
- **z-score:** (value − mean) / standard deviation; |z| > 2 → "unusual".
- **% change from 0** is undefined → the code returns null rather than ∞.

**N5 · Recommendation score**
- Content: cosine(tags, liked item's tags) = shared / √(sizeA·sizeB) — best match across your likes.
- Together: for each other user's history that overlaps your likes, add overlap/historySize to items you haven't liked; normalise by the max.
- Popularity: likes count / max.
- Score = 0.6·content + 0.3·together + 0.1·popularity (configurable); reason = largest term.

**N6 · Riverpod 3 rules you must recite**
- `build()` returns initial state; never assign `state` in it.
- After `await` in a notifier: `if (!ref.mounted) return;`; in widgets: `if (!context.mounted) return;`.
- `watch` in build, `read` in callbacks, `listen` for side effects (navigation, snackbars, sync on reconnect).
- `autoDispose`: freed when unwatched — good for screen state, bad for caches.
- Tests: `ProviderScope(overrides: [repoProvider.overrideWithValue(InMemoryRepository(...))])`.

**N7 · Retries**
- Idempotent (safe to repeat): GET, PUT, DELETE. Not: POST (creates), PATCH (often).
- Retry on: network error, timeout, 429, 5xx. Never on 4xx (the request itself is wrong).
- Backoff: 0.5 s × 2ⁿ (exponential) or `Retry-After`; cap the total wait.

**N8 · Security boundaries**
- Anything in the app binary is public (including `--dart-define` values). Publishable/anon keys are meant to be public.
- Data protection = row-level security (`user_id = auth.uid()`), enforced in the database.
- Secrets (service role, model keys, payment keys) → server functions only.
- The `ai-complete` function: verifies JWT via `/auth/v1/user`, validates/caps input, holds the key, maps errors; open CORS is acceptable because a user token is required.
- Client validation = UX; server validation = safety.

**N9 · Greedy scheduling**
- Sort: deadline ↑, priority ↓, duration ↓ → each task takes the earliest fitting free slot before its deadline, + buffer.
- Why not optimal: an early long task can block two short ones that together matter more; optimal = constraint solving (exponential in the worst case).
- Why acceptable: fast, deterministic, explains failures ("longer than a working day", "deadline passed").

**N10 · AI validation**
- `classify` → must equal exactly one of your labels (else keyword fallback).
- `extractFields` → must parse as a JSON object; unknown keys dropped.
- `rephrase` → every number in the source must appear in the reply (catches invented/changed data).
- `summarize` → non-empty and shorter than the input (else extractive summary).
- Always label the source; never let model output trigger actions without confirmation.

---

## Part 4 — 30-minute drill before the competition

1. (5 min) Say N1 and N2 out loud without notes.
2. (5 min) Draw the layer diagram and the route-vs-widget tree (N3) on paper.
3. (5 min) Compute one priority score by hand from the formula (Q9).
4. (5 min) Answer Q8 and Q13 word for word — the two questions most likely to come first.
5. (10 min) Open `CATALOG.md`, pick three random cards, read only the title, and recite: use when, inputs/outputs, one edge case, one limitation.
