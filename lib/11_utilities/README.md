# 11 · Utilities

Pure Dart helpers with no Flutter widgets and no platform channels, so everything here is unit-tested.

| File | Contents | Source |
|---|---|---|
| `date_utils.dart` | `dateOnly`, `isSameDay`, `addDays`, `daysBetween`, `daysInMonth`, `startOfWeek`, `isoWeekNumber`, `addYears`, `formatShortDate`, `formatLongDate`, `formatTime`, `relativeDayLabel`, `timeAgo`, `weekRangeLabel` | Cookly `week_math.dart`, TaskFlow `date_formatter.dart`, Couple `milestone_calculator.dart` |
| `number_format.dart` | `formatQuantity`, `formatCompact`, `formatBytes`, `formatDuration` | Cookly `format_number.dart` + new |
| `markdown_parser.dart` | `parseMarkdown`, `parseMarkdownLine`, `parseInline`, the block classes | StudyBuddies `markdown_tokens.dart` (+ TaskFlow strikethrough) |
| `geo.dart` | `distanceKm`, `formatDistance` | Couple `haversine.dart` |
| `spaced_repetition.dart` | `ReviewState` (SM-2), `dueCards` | StudyBuddies `smart_review.dart` |
| `streak.dart` | `recordActivity`, `currentStreak`, `longestStreak` | TaskFlow `streak_manager.dart` |
| `quantity_scaler.dart` | `scaleQuantity`, `defaultMeasuredUnits` | Cookly `servings_scaler.dart` |
| `health_calc.dart` | `basalMetabolicRate`, `dailyCalorieTarget`, `macroTargets`, `bmi`, `bmiCategory` | Cookly `calorie_calculator.dart` (+ BMI) |
| `collection_utils.dart` | `reorder`, `groupBy`, `distinctBy` | Couple `element_ordering.dart` + new |
| `app_logger.dart` | `AppLogger` | Couple `logger.dart` |

**Dependencies:** none (`app_logger.dart` uses Flutter's `kReleaseMode`).

---

## date_utils

```dart
relativeDayLabel(task.due)            // "Today", "Tomorrow", "Yesterday", "Saturday", "Nov 2", "Jan 2, 2027"
timeAgo(note.updatedAt)               // "just now", "5m ago", "3h ago", "4 days ago"
isoWeekNumber(DateTime.now())         // 42
addYears(DateTime(2024, 2, 29), 1)    // 2025-02-28, not March 1
startOfWeek(now, firstWeekday: DateTime.sunday)
```
**DST rule.** Day arithmetic builds dates from y/m/d (`DateTime(y, m, d + n)`) instead of adding `Duration(days: n)`. Across a daylight-saving change, a day isn't 24 hours. `daysBetween` compares UTC midnights.
**Limitation.** Names are English. For localisation, use `intl`'s `DateFormat` for display and keep these for arithmetic.
**Tests.** Year boundaries for ISO weeks (2027-01-01 is week 53 of 2026), leap days, every label branch.

## number_format

`formatQuantity(1.50) → "1.5"`, `formatCompact(1200) → "1.2k"`, `formatBytes(3355443) → "3.2 MB"`, `formatDuration(65 min) → "1h 05m"`.

## markdown_parser

Parses the subset that AI responses and notes use into plain objects, which `MarkdownView` (02), `MarkdownEditingController` (05) or a PDF exporter can render.
- **Blocks:** heading (1–6, needs a space after `#`, so `#hashtag` stays text), bullet and numbered (with indent level), quote, fenced code (verbatim, language kept, an unterminated fence runs to the end like CommonMark), pipe table (two or more rows, escaped `\|` kept, ragged rows padded), blank, paragraph. Handles `\r\n`.
- **Inline:** `**bold**`, `*italic*`, `` `code` ``, `~~strike~~`. `2 * 3 * 4` stays plain. TaskFlow's `_underline_` was not adopted: it mangles `snake_case_names`.

**Why one parser.** StudyBuddies rendered Markdown on screen and in PDF export with two hand-written parsers that drifted: exported PDFs printed literal `**` and `###`. One parser feeding every renderer prevents that.

## geo

`distanceKm(lat1, lng1, lat2, lng2)` (haversine, mean Earth radius) and `formatDistance` ("850 m", "12.4 km", "5,570 km"). Pure Dart, unlike `geolocator.distanceBetween`, which needs a registered platform plugin. Tested London → New York ≈ 5,570 km.

## spaced_repetition (SM-2)

```dart
var state = ReviewState.fromJson(row);          // or const ReviewState() for a new card
state = state.review(knewIt ? 4 : 2, now: DateTime.now());
await save(state.toJson());
final queue = dueCards(statesById, DateTime.now(), limit: 20);  // most overdue first, new cards last
```
Intervals 1 → 6 → interval × ease. Grade < 3 resets the card. Ease changes ±0.15 only on grades 2 and 5, clamped to 1.3–3.0. This matches StudyBuddies' (deliberately simplified) SM-2 so existing data stays compatible. **Tests.** The interval sequence, reset, ease clamps, JSON, due ordering.

## streak

`recordActivity(lastActiveDay:, count:, today:)` for counter-style streaks (same day keeps the count, the next day adds one, a gap resets, a clock moved backwards resets). `currentStreak(activeDays, today)` counts a streak ending yesterday as still alive, so it isn't shown as broken before the user has acted today. `longestStreak(activeDays)`.
**Changed from the source.** TaskFlow mixed this rule with SharedPreferences and a Supabase sync in one static method. Here it is pure; persist the result yourself.

## quantity_scaler

`scaleQuantity('2-3 cloves', 2) → "4-6 cloves"`, `('1 1/2 cups', 2) → "3 cups"`, `('400g', 1.5) → "600g"`. Counts round to whole numbers with a minimum of 1 ("1.5 eggs" isn't a quantity). Measured units (`defaultMeasuredUnits`: g, ml, cup, tbsp, …, extendable) keep decimals. Unparseable text is returned unchanged.
**Bug fixed.** `"1/0 cup"` (zero denominator) fell through to the plain-number rule and became `"2/0 cup"`, in the Cookly source too. It is now returned as written (tested).

## health_calc

Mifflin-St Jeor BMR, × activity multiplier (enum), ± goal (−500 / 0 / +500, enum) with a 1,000 kcal floor, goal-specific macro splits, and BMI with WHO categories. Enums replaced the source's strings, so `'very_active'` typos are compile errors. These are estimates for pre-filling editable fields, not medical advice.

## collection_utils

`reorder(list, old, new, fromReorderableListView: true)` corrects Flutter's pre-removal `newIndex` and never mutates the input. `groupBy` and `distinctBy` keep first-seen order.

## AppLogger

`AppLogger.info('Note saved', tag: 'notes')`, `AppLogger.error('Sync failed', error: e, stackTrace: st)`. Logs go through `dart:developer` (they show in DevTools with severity). Debug entries are dropped in release builds. The optional `sink` forwards entries to a crash reporter. **Rule (from Couple):** log that something happened, never the user's content.

**Folder tests: 29** (`utilities_test.dart`).
