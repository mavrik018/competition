# 13 · Smart features

The "differentiation" layer: features that make a competition app feel intelligent — matching, recommendations, scoring, predictions, insights, automation, scheduling, gamification, personalization, accessibility, voice, offline sync and live collaboration.

**Everything in this folder is rule-based or statistical. None of it is AI.** It runs offline, gives the same answer for the same input, explains itself, and can be unit-tested. Where a language model would genuinely help (free-text summaries, classifying messy input, friendlier wording), use `14_ai`, which always keeps one of these rule-based results as its fallback.

Say it the same way to judges: "rule-based scoring with configurable weights", "linear-trend forecast" — not "our AI predicts". Overclaiming is easy to spot and costs credibility.

## At a glance

| Module | Nature | Config as data | External services | Difficulty | Tests |
|---|---|---|---|---|---|
| `rule_conditions.dart` | rules | JSON conditions | — | ★ | ✅ |
| `smart_matching.dart` | weighted scoring | criteria + weights | — | ★★ | ✅ |
| `recommendations.dart` | statistics (cosine, co-occurrence) | weights | — | ★★ | ✅ |
| `priority_scoring.dart` | weighted scoring | `PriorityRules` | — | ★ | ✅ |
| `risk_scoring.dart` | points scorecard | JSON rules + levels | — | ★ | ✅ |
| `trends.dart` | statistics | thresholds | — | ★ | ✅ |
| `predictions.dart` | statistics + rules | JSON-able rules | — | ★★ | ✅ |
| `insights.dart` | statistics → sentence templates | `InsightConfig` | — | ★ | ✅ |
| `automation.dart` | event → condition → action rules | JSON rules | — (handlers may call any) | ★★ | ✅ |
| `smart_scheduling.dart` | greedy algorithm | working hours, buffer | — (calendar import optional) | ★★ | ✅ |
| `gamification.dart` | rules + formulas | points table, JSON badges | — | ★ | ✅ |
| `activity_timeline.dart` | grouping | — | — | ★ | ✅ |
| `contextual_actions.dart` | rules over context facts | JSON actions | — | ★ | ✅ |
| `personalization.dart` | decayed counters | weights, half-life | — | ★ | ✅ |
| `accessibility.dart` | WCAG formulas + settings | user preferences | — | ★ | ✅ |
| `voice_input.dart` | OS speech engine (ML in the OS) + rule-based parser | intent patterns | OS speech service, mic permission | ★★ | ✅ parser, button, fake · 🔶 device engine |
| `offline_first_repository.dart` | queue + last-write-wins | prune / permanent-error rules | your backend (any `Repository`) | ★★★ | ✅ |
| `realtime_collaboration.dart` | CRDT (LWW map + Lamport clock) | — | Supabase Realtime (or any transport) | ★★★ | ✅ CRDT, docs, hub · 🔶 Supabase transport |

★ drop-in · ★★ an afternoon of wiring · ★★★ needs care with your data model. Tests: `test/13_smart_features/` (`rules_and_scoring_test.dart`, `analytics_and_engagement_test.dart`, `context_and_sync_test.dart`), 79 tests.

## Shared foundation — `rule_conditions.dart`

A tiny JSON condition language used by risk rules, automations, badges, predictions and contextual actions, so business rules can live in a JSON asset, a Supabase table or remote config instead of code.

```json
{"all": [
  {"field": "age", "op": ">=", "value": 65},
  {"any": [
    {"field": "conditions", "op": "contains", "value": "diabetes"},
    {"field": "bmi", "op": ">", "value": 30}
  ]}
]}
```
* Operators: `== != > >= < <= contains not_contains in not_in between exists not_exists`; combinators `all`, `any`, `not`, `always`.
* `field` can be a dotted path (`user.address.city`). Strings compare case-insensitively; DateTimes compare with ISO strings.
* `describe()` turns any condition into readable text ("age ≥ 65 and (…)") for "why was this flagged?" screens.
* **A missing fact makes every operator false except `not_exists`**, so rules never fire on data you do not have. Careful: `not` inverts that (`not (x < 3)` is true when `x` is missing) — add `exists` when it matters.
* Bad JSON (unknown operator, wrong shape) throws `FormatException` at load time, not silently at evaluation time.

---

Each module below answers the same eight questions: **(1) suits**, **(2) what it does**, **(3) rule-based vs AI**, **(4) configurable rules**, **(5) data & UI wiring**, **(6) example application**, **(7) integration difficulty & services**, **(8) limitations & failure cases**.

## Smart matching — `smart_matching.dart`
1. **Suits:** mentor ↔ mentee, tutor ↔ student, volunteer ↔ task, roommates, study buddies, hackathon teammates, donor ↔ request, job ↔ candidate shortlists.
2. **Does:** `SmartMatcher<A, B>(criteria, minScore)` scores each candidate as a weighted average of `MatchCriterion` scores (0–1), drops candidates failing a `required` criterion, ranks them (stable), and can pair two groups one-to-one (`assignOneToOne`, greedy). Every `MatchResult` has a per-criterion `breakdown`, an `explanation` ("Subjects 100%, Distance 72%") and `strengths()`. Ready-made scores: `jaccard`, `coverage`, `proximityScore`, `closeness`, `rangeOverlap`, `textSimilarity` / `levenshtein` (typo-tolerant).
3. **Rule-based.** Deterministic weighted sum; no learning. An AI version would embed profiles and compare vectors — only worth it for free-text bios (use `14_ai` to extract structured fields first, then match with this).
4. **Config:** criteria list, weights, `required` flags, `minScore`, the `maxKm`/tolerance inside each score.
5. **Wiring:** map your models to criteria lambdas; show `rank(...)` in a list with `percent` as a badge and `strengths()` as chips; persist chosen pairs.
6. **Example:** "Find a tutor" — subjects (required, weight 3), distance (2), budget (1).
7. **Difficulty ★★, no services.** Distance needs coordinates (`GeoPoint.distanceKmTo`, 12).
8. **Limits:** greedy one-to-one is not globally optimal (use the Hungarian algorithm for fairness-critical pairing); weights are your judgement, not learnt; O(n·m) — fine for thousands, not millions. Two empty sets give `jaccard` 0 (nothing to go on).

## Recommendations — `recommendations.dart`
1. **Suits:** recipes, courses, articles, events, products, study resources, exercises, places, people to follow.
2. **Does:** `Recommender<T>.recommend(catalog, liked, histories, exclude, limit)` blends content similarity (cosine over tags vs. liked items), co-occurrence ("people who liked X also liked Y", normalised so heavy users count less) and popularity (cold start). Each `Recommendation` has a `reason` ("Similar to Lentil soup", "Often liked together…", "Popular right now"). `similarTo(item)` gives "More like this".
3. **Statistical, not AI.** Counting and cosine similarity; reproducible; explainable. ML recommenders (matrix factorisation, embeddings) need far more data than a competition demo has.
4. **Config:** `RecommenderWeights(content, together, popularity)`, the tag function (add `cuisine:`, `diet:`, `level:` prefixes to tags to make them distinct).
5. **Wiring:** `liked` = the user's favourites ids; `histories` = everyone's favourites (a Supabase query or a seeded JSON); show a horizontal carousel with the reason as a subtitle.
6. **Example:** Cookly-style "Because you liked…" row on the home screen.
7. **Difficulty ★★, no services** (histories come from your own backend if you have one).
8. **Limits:** quality depends entirely on tags; new items with no likes rely on tags only; scores are relative within one call; no diversity control (similar items cluster — interleave categories if needed).

## Priority scoring — `priority_scoring.dart`
1. **Suits:** to-do and study planners, ticket triage, maintenance requests, assignment trackers, volunteer boards, bug lists.
2. **Does:** `scorePriority(PriorityInput(due, importance 1–5, effortHours, createdAt))` → 0–100 score, band (critical/high/medium/low) and reasons ("Due in 2 days", "Importance 4/5", "Quick win", "Waiting 40 days"). Overdue + important is always critical. `rankByPriority` sorts (stable); `eisenhowerQuadrant` classifies do-first / schedule / delegate / eliminate.
3. **Rule-based** weighted sum of normalised factors.
4. **Config:** `PriorityRules` — four weights (normalised), urgency window, quick-win hours, stale days, band thresholds.
5. **Wiring:** convert your task to `PriorityInput`; sort the list; colour a chip by band; show reasons in the detail view or as a tooltip.
6. **Example:** a "What should I do next?" card on a study dashboard.
7. **Difficulty ★, no services.**
8. **Limits:** importance is self-reported; no dependencies between tasks; the score ignores how much time is actually free (combine with smart scheduling).

## Risk scoring — `risk_scoring.dart`
1. **Suits:** at-risk student alerts, elderly/patient check-ins, wellbeing and burnout check-ins, budget overspend, unusual-activity flags, safety inspections, plant/crop health.
2. **Does:** `RiskModel(rules, moderateAt, highAt, severeAt).assess(facts)` → points, level, matched rules (biggest first) as reasons, and a 0–1 `fraction` for a gauge. Rules can have negative points (protective factors).
3. **Rule-based scorecard** — how many real screening checklists work. **Not a validated predictive model**: say "screening", never "diagnosis".
4. **Config:** the whole model is JSON (`RiskModel.fromJson({'levels': …, 'rules': […]})`), so experts can tune it without a release.
5. **Wiring:** build the facts map from your data (attendance %, late count, trend from `trends.dart`); show the level as a coloured banner (`StatusBanner`, 03) and the reasons as a list; trigger `automation.dart` on "high".
6. **Example:** a teacher dashboard flagging students with "Attendance under 75%, Grade average dropping".
7. **Difficulty ★, no services.**
8. **Limits:** points are additive (no interactions unless you write a combined rule); thresholds are opinions — document where they came from; missing data scores 0, which can hide risk (add `not_exists` rules for "no data in 14 days").

## Trends — `trends.dart`
1. **Suits:** anything logged daily — study minutes, spending, steps, sleep, mood, sales, energy, water.
2. **Does:** `linearFit` (slope, intercept, r²), `mean`, `standardDeviation`, `movingAverage`, `percentChange` (null from zero), `anomalies` (z-score), `analyzeTrend` → `TrendSummary(direction, slope, fit, average, latest, min, max, volatility, changePercent)`, `dailySeries` (events → one value per day, gaps filled with 0), `weekdayAverages`.
3. **Statistical** (textbook formulas).
4. **Config:** `flatThreshold` (default 2% of the average per step), anomaly `threshold` (default 2σ).
5. **Wiring:** `dailySeries` from your log → `SimpleLineChart` (02) + `analyzeTrend` for an arrow/label → `generateInsights` for sentences.
6. **Example:** "Spending is trending down, 12% less than the first half of the month".
7. **Difficulty ★, no services.**
8. **Limits:** a straight line misses seasonality (check `fit`: below ~0.3 the trend is weak — say so); fewer than 3 points → flat; anomalies need ≥ 4 points and are skewed by the anomaly itself in tiny samples.

## Predictions — `predictions.dart`
1. **Suits:** goal ETA ("you'll reach 10 km by…"), syllabus completion, stock run-out, habit forecasts, deadline-risk warnings, simple rule-based classification (likely late / likely tired).
2. **Does:** `forecastLinear(values, steps)` with a ±1 standard-error band, `exponentialSmoothing`, `predictWhenReached(cumulative, target)` using the recent window, `checkPace(done, total, start, due, now)` → ahead / on track / behind / not started / done + projected finish, and `RulePredictor<R>` (first matching `PredictionRule` wins, with stated confidence and reason).
3. **Statistical + rules.** Present every output as "at your current pace…", never as certainty. `confidence` in `PredictionRule` is *your* stated confidence, not a learnt probability.
4. **Config:** window size, tolerance, smoothing alpha, and the rule list (conditions are JSON).
5. **Wiring:** feed `dailySeries` values; show the ETA under a progress bar; colour the pace status; use `RulePredictor` to pick a message or an icon.
6. **Example:** "At this pace you'll finish the syllabus on 12 May — 3 days after the exam. Add 20 min/day to finish on time."
7. **Difficulty ★★, no services.**
8. **Limits:** cannot know about future events (holidays, illness); linear extrapolation diverges quickly beyond the data range; a flat or falling series returns null ETA — handle it in the UI.

## Insights — `insights.dart`
1. **Suits:** weekly reviews, analytics screens, dashboards, end-of-session summaries, coaching apps.
2. **Does:** `generateInsights(days, config, now)` returns ranked `Insight`s: week-over-week change, overall trend, best weekday, unusually high/low latest day, goal streak, and "goal within reach?" when the goal is rarely met. Fewer than `minDays` of data → one "Keep logging" message. `InsightCard` shows one, coloured by tone.
3. **Rule-based templates over statistics.** Every number in the text comes from the data; nothing is invented. For warmer wording, pass the sentence to `AiAssistant.rephrase` (14), which rejects any reply that changes a number.
4. **Config:** `InsightConfig(metric, unit, higherIsBetter, goalPerDay, minChangePercent, anomalyThreshold, minDays)`.
5. **Wiring:** `dailySeries(...)` → `generateInsights` → `InsightCard`s in `AnalyticsTemplate.insights` or a dashboard section; use the stable `id` to let users dismiss a type.
6. **Example:** "Your study time is 23% higher than last week (140 min vs 114 min)."
7. **Difficulty ★, no services.**
8. **Limits:** English templates (translate the strings); the best-weekday rule needs two full weeks; insights are only as good as the logging (a forgotten day looks like a zero).

## Automation — `automation.dart`
1. **Suits:** "when X happens and Y is true, do Z": award XP on completion, notify at 80% of budget, add to the shopping list when stock < 3, flag a grade under 50, start a timer on arrival.
2. **Does:** `AutomationRule(trigger, when, actions, enabled, cooldown)` (JSON round-trip, `describe()` for a rules list), `AutomationEngine(rules, handlers).handle(AppEvent)` runs every matching enabled rule, respects cooldowns, and logs each action as an `AutomationRun`. A failing or missing handler is logged and does not stop the others. `upsertRule`, `removeRule`, `setEnabled` support a rules editor.
3. **Rule-based.** Nothing runs unless a rule says so.
4. **Config:** rules as JSON (user-created or admin-provided); handlers are your code (`notify`, `add_to_list`, `award_xp`, …).
5. **Wiring:** call `engine.handle(AppEvent('task_completed', task.toJson()))` after each write (e.g. from `CrudController` callers); handlers call `ReminderScheduler`, repositories, `XpRules`; show `engine.log` in an activity screen.
6. **Example:** a pantry app's "Restock reminder" rule (demo in the showcase).
7. **Difficulty ★★, no services** (handlers may call notifications, APIs, etc.).
8. **Limits:** in-process only — rules run while the app is open (server-side automation needs database triggers or scheduled Edge Functions); cooldown state is in memory (persist `_lastRun` if it must survive restarts); no loops protection if a handler emits events that retrigger rules — keep handlers from calling `handle` on the same trigger.

## Smart scheduling — `smart_scheduling.dart`
1. **Suits:** study planners (revision blocks before exams), auto-planning a to-do list, shift/appointment slotting, "first time we're all free", chore or meal-prep plans.
2. **Does:** `findFreeSlots(busy, from, until, hours, minLength)`, `scheduleTasks(tasks, busy, …, buffer)` → `ScheduleResult(placed, unplaced with reasons)`, `findConflicts`, `firstCommonSlot(calendars, length)`. `WorkingHours(startHour, endHour, days)`.
3. **Rule-based greedy algorithm:** earliest deadline first, then priority, then longer tasks; each gets the earliest slot that ends before its deadline. Fast and explainable; not guaranteed optimal (that is a constraint-solver problem).
4. **Config:** working hours and days, buffer between tasks, task priority and `earliestStart`.
5. **Wiring:** busy slots from your events table (or device calendar via a plugin); show placed tasks in `AgendaCalendar` (06) and unplaced ones with their reason and a "split it" action.
6. **Example:** "Plan my week" button that fills revision sessions around lectures.
7. **Difficulty ★★, no services** (device calendar import would need `device_calendar` + permissions).
8. **Limits:** tasks longer than a working day are never split automatically; local times only (DST shifts can make a slot an hour off — keep everything in one zone); a full schedule reports tasks as unplaced rather than bumping lower-priority ones.

## Gamification — `gamification.dart`
1. **Suits:** habit, study, fitness, language, volunteering, recycling and reading apps; classroom leaderboards; onboarding checklists.
2. **Does:** `LevelCurve(baseXp, growth)` (geometric levels, `progressFor(totalXp)`), `XpRules(points, streakBonusPerDay, maxStreakBonus)`, JSON `AchievementBadge`s with `newlyUnlocked`, `leaderboard` with standard competition ranking (1, 2, 2, 4), `Challenge.progress`, plus `XpProgressBar` and `BadgeGrid` widgets.
3. **Rule-based** tables and formulas.
4. **Config:** points per action, curve parameters, badges as JSON conditions over stats.
5. **Wiring:** award XP in automation handlers; store `totalXp` and earned badge ids with the user; call `newlyUnlocked` after each stat change and celebrate (`SuccessCheckmark`, 02).
6. **Example:** "+25 XP — Level 3 unlocked — badge: High five".
7. **Difficulty ★, no services** (a shared leaderboard needs a backend table).
8. **Limits:** client-side XP is trivially cheatable — compute it server-side for competitive leaderboards; badge conditions only see the stats you pass.

## Activity timeline — `activity_timeline.dart`
1. **Suits:** history/audit screens, shared-space feeds (couple, team, class), order or case tracking, weekly reviews, notification centres.
2. **Does:** `groupActivityByDay(events, now)` (Today / Yesterday / weekday / "Sep 14" / "Dec 31, 2025", newest first) and `ActivityTimeline` (icon column with a connecting line, title, subtitle, time; tappable).
3. **Not AI** — grouping and labels.
4. **Config:** icons, colours and types per event.
5. **Wiring:** create `ActivityEvent`s from your own writes or from `AutomationEngine.log`; put the widget in a `DashboardSection` (06).
6. **Example:** "Completed 'Essay draft' · 2:00 PM", "Ana joined Biology 101 · Yesterday".
7. **Difficulty ★, no services.**
8. **Limits:** renders all events in a `Column` — paginate long histories; labels are English.

## Contextual actions — `contextual_actions.dart`
1. **Suits:** home screens ("what next?"), smart reminders, quick-add bars, kiosk/field apps that adapt to time and place.
2. **Does:** `contextFacts(now, extra)` (hour, weekday, isWeekend, partOfDay + your facts), `ContextualActionEngine(actions, maxSuggestions).suggest(facts)` (matching actions by priority, hiding dismissed ones for `dismissFor`), and `ContextualActionBar` (chips with a hide button).
3. **Rule-based** conditions over context.
4. **Config:** actions as JSON (`id`, `label`, `icon`, `priority`, `when`, `dismissForMinutes`).
5. **Wiring:** add facts from your data (`lowStockCount`, `minutesStudiedToday`, distance to a geofence from `location_service.dart`); map `action.id` to navigation or a command; persist `dismissedAt` in `PrefsStore` if dismissals should survive restarts.
6. **Example:** morning → "Start focus session"; evening → "Log dinner"; low stock → "Restock milk".
7. **Difficulty ★, no services.**
8. **Limits:** suggestions are only as smart as the facts you provide; too many rules → noisy bar (keep `maxSuggestions` at 2–3).

## Personalization — `personalization.dart`
1. **Suits:** feeds and catalogues, "your subjects first", default filters, home ordering, best time for a reminder.
2. **Does:** `PreferenceProfile(halfLife)` — `record(key, weight)` with exponential decay, `affinity`, `topKeys`, `orderByAffinity(items, keysOf)` (stable for ties), `recordActiveAt` / `preferredHour(minSamples)`, `reset`, tolerant JSON round trip. `InteractionWeight` suggests view +1, complete +2, favourite/share +3, skip −1, hide −3.
3. **Statistical** decayed counters, on-device and inspectable.
4. **Config:** half-life (default 14 days), interaction weights, `minSamples`.
5. **Wiring:** call `record` from item taps/favourites; persist with `PrefsStore.setJson`; reorder lists with `orderByAffinity`; schedule reminders at `preferredHour() ?? 19`; show `topKeys` in settings with a Reset button.
6. **Example:** recipes the user keeps favouriting (Thai, spicy) float to the top within a few taps.
7. **Difficulty ★, no services.**
8. **Limits:** filter bubble — mix in some unranked items; one device only unless you sync the JSON; a new user sees the default order (cold start).

## Accessibility — `accessibility.dart`
1. **Suits:** every app; especially apps for older or low-vision users, health, education and public services.
2. **Does:** `relativeLuminance`, `contrastRatio`, `meetsWcag(fg, bg, largeText, level)`, `readableOn(background)`; `AccessibilityPreferences` (text scale, bold, reduce motion, high contrast; JSON) applied by `AccessibilityScope` through `MediaQuery` (device settings still win when stronger) and a max-contrast colour scheme; `announce(context, message)` for screen readers; `AccessibleTapTarget` (48×48 + label).
3. **Not AI** — WCAG 2.x formulas and Flutter's own accessibility hooks.
4. **Config:** the user's preferences (a settings screen with `SettingsToggle`s and a slider).
5. **Wiring:** wrap `MaterialApp.builder`'s child in `AccessibilityScope`; components in 02 already respect reduce-motion; call `announce` after silent changes ("Saved", "3 results").
6. **Example:** an in-app "Larger text / Bold / High contrast" panel (showcase demo) and a contrast check for user-chosen tag colours.
7. **Difficulty ★, no services.**
8. **Limits:** high contrast regenerates only `colorScheme` (component themes built from the old scheme keep their colours); contrast maths assumes opaque colours; text scaling can still overflow fixed-height layouts — test at 2×.

## Voice input — `voice_input.dart`
1. **Suits:** hands-busy apps (cooking, workshop, fitness), accessibility, quick capture of tasks/expenses/notes, search.
2. **Does:** `SpeechInput` interface with `DeviceSpeechInput` (speech_to_text) and `FakeSpeechInput` (scripted phrases — **not production functionality**); `parseNaturalTime` ("tomorrow at 5pm", "in 20 minutes", "next monday at 10:30", "tonight", "on Friday"); `VoiceCommandParser([VoiceIntent('add_task', ['remind me to {title}', 'add {title}'])])` → intent, slots and time; `VoiceInputButton` (partial words, final result, error snackbar when unavailable).
3. **Two natures.** Speech → text is ML inside the OS recogniser (Google/Apple), no key needed from you. Text → meaning is **rule-based** patterns: predictable, offline, but it only understands phrasings you anticipated. Use `14_ai` `extractFields` when phrasing is unpredictable.
4. **Config:** intents and their phrase patterns; locale.
5. **Wiring:** `VoiceInputButton(speech: ref.read(speechInputProvider), onResult: …)`; parse; create the item with `command.slots` and `command.at`; fall back to search or a prefilled form when nothing matches.
6. **Example:** "Remind me to call mum tomorrow at 5pm" → task "call mum", due tomorrow 17:00.
7. **Difficulty ★★.** Android: `RECORD_AUDIO` permission and a `<queries>` entry for `android.speech.RecognitionService` in the manifest. iOS: `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription`. Many devices need the network for recognition.
8. **Limits:** English time phrases only; "at 1"–"at 7" are assumed PM; a time already passed today means tomorrow; recogniser accuracy varies with accent and noise; always keep a keyboard path. The device engine is 🔶 (no microphone in `flutter test`); the parser, button and fake are tested.

## Offline-first repository — `offline_first_repository.dart`
1. **Suits:** field data collection, inspections, clinics or schools with poor connectivity, shopping lists, notes, habit/expense logs.
2. **Does:** `OfflineFirstRepository<T>` implements `Repository<T>`: reads and writes hit the local store instantly; writes are queued in `OfflineQueue` (09) and pushed by `sync()`, which then pulls remote changes. **Last-write-wins by `updatedAt` in both directions** (a newer server copy beats a queued push; a newer local copy is not overwritten by a pull; items with unsent edits are never overwritten). Optional `pruneMissing` deletes items removed on another device. Permanent errors (`isPermanentError`) are dropped and reported; transient ones retry with backoff. Overlapping `sync()` calls are coalesced into one follow-up run.
3. **Not AI** — a queue and a timestamp comparison.
4. **Config:** `pruneMissing`, `isPermanentError`, entity `name` (op type prefix), `userId` scoping.
5. **Wiring:** local = `SqfliteRepository`, remote = `SupabaseRepository` or an `ApiClient`-backed repository; call `sync()` on reconnect (`connectivityProvider`, 10), app resume and pull-to-refresh; show `pendingCount()` in an `OfflineBanner` (03) and `SyncReport.dropped` as an error.
6. **Example:** an inspection app that records findings in a basement and syncs when back upstairs.
7. **Difficulty ★★★, needs a backend** (any `Repository`). Your model must carry `updatedAt`; set it on the server (a trigger) if device clocks cannot be trusted.
8. **Limits:** whole-item last-write-wins — concurrent edits to *different fields* of the same item lose one side (use `realtime_collaboration.dart`'s per-key approach for that); a pull downloads everything (fine for hundreds of rows, add an `updated_at > lastSync` filter for more); deletes on other devices are only applied with `pruneMissing`.

## Real-time collaboration — `realtime_collaboration.dart`
1. **Suits:** shared shopping/packing lists, couple or family boards, group trip planning, classroom polls, live scoreboards, shared checklists.
2. **Does:** `CollaborativeDocument(replicaId, transport)` — a shared key → JSON-value map with `set`, `remove`, `values`, `changes` stream, `exportState` / `importState`. Built on `LwwMap`, a last-writer-wins map **CRDT**: each change carries a `CollabStamp` (Lamport counter + replica id) and deletions keep tombstones, so replicas converge even when messages are late, reordered or duplicated. Late joiners catch up via a hello → state exchange. Transports: `SupabaseBroadcastTransport` (🔶 production) and `InMemoryCollabHub` (test/demo double that can hold, reverse and duplicate messages — **not production functionality**).
3. **Not AI** — a well-known distributed-systems data structure, small enough to explain.
4. **Config:** channel name, broadcast event, private channel flag.
5. **Wiring:** one key per list item (`item:<id>`), value = the item's JSON; render `doc.values` with a `StreamBuilder` on `doc.changes`; save `exportState()` to a table or local storage so the document outlives the session (broadcast keeps no history).
6. **Example:** two phones editing the same shopping list live (showcase demo, with simulated lag).
7. **Difficulty ★★★.** Supabase Realtime enabled on the project; for private channels, a Realtime authorization policy (see `10_backend/realtime_presence.dart`). Works with any other transport (WebSocket, Firebase) by implementing `CollabTransport`.
8. **Limits:** the unit of conflict is one key — two people editing the same item at once → the later stamp wins; not for character-level text editing (needs a sequence CRDT such as Yjs); tombstones are never garbage-collected; if no peer is online and nothing was persisted, a newcomer starts empty.

## Tests
| File | Covers |
|---|---|
| `test/13_smart_features/rules_and_scoring_test.dart` | conditions (nested, describe, JSON round trip, missing facts, dates, paths, errors), matching helpers and `SmartMatcher`, recommender (content, cold start, co-occurrence, exclusions), priority, risk |
| `test/13_smart_features/analytics_and_engagement_test.dart` | trends, predictions, insights (+ `InsightCard`), automation, scheduling, gamification (+ widgets), activity timeline |
| `test/13_smart_features/context_and_sync_test.dart` | contextual actions (+ bar), personalization, accessibility (+ scope, tap target, announce), voice parser + button with the fake, offline-first sync (in-memory SQLite queue, flaky remote), CRDT convergence with reordered/duplicated delivery, late joiners, export/import |

**Renamed during testing:** `Matcher` → `SmartMatcher` (it clashed with `package:matcher`, which `flutter_test` exports) and `Badge` → `AchievementBadge` (clashed with Material's `Badge`).
