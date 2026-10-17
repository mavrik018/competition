# 02 · UI elements

Reusable widgets. All of them take their colours from the theme and use logical pixels (no `flutter_screenutil`).

| File | Component | Source | Extra deps |
|---|---|---|---|
| `pressable.dart` | `Pressable` | Cookly + StudyBuddies | — |
| `primary_button.dart` | `PrimaryButton` | StudyBuddies, Cookly | — |
| `app_chip.dart` | `AppChip` | Cookly | — |
| `section_header.dart` | `SectionHeader` | Cookly | — |
| `search_field.dart` | `SearchField` | Cookly | — |
| `radial_gauge.dart` | `RadialGauge` | StudyBuddies | — |
| `skeleton.dart` | `Shimmer`, `SkeletonBox`, `SkeletonList`, `SkeletonCardRow` | Cookly, rewritten | — (was `shimmer`) |
| `fade_slide_in.dart` | `FadeSlideIn`, `Stagger` | Cookly, rewritten | — (was `flutter_animate`) |
| `flip_card.dart` | `FlipCard` | StudyBuddies | — |
| `swipe_action_tile.dart` | `SwipeActionTile`, `SwipeAction` | TaskFlow | — |
| `activity_heatmap.dart` | `ActivityHeatmap` | StudyBuddies | — |
| `simple_bar_chart.dart` | `SimpleBarChart`, `BarDatum` | **new** (replaces Cookly's `fl_chart` use) | — |
| `spin_wheel.dart` | `SpinWheel`, `SpinWheelController`, `WheelSlice` | Cookly | — |
| `markdown_view.dart` | `MarkdownView`, `markdownSpans` | StudyBuddies | uses `11_utilities/markdown_parser.dart` |

Every file imports at most `01_design_system/app_tokens.dart` (plus `pressable.dart` for the chip and the parser for `MarkdownView`).

---

## Pressable

**Purpose.** Wraps any custom card or row so it shrinks to 98% while pressed (optionally also dims), with a selection haptic on tap and a medium haptic on long press.
```dart
Pressable(onTap: open, semanticLabel: 'Open recipe', child: RecipeCard(recipe))
```
**How it works.** `GestureDetector` tap-down/up/cancel toggles a `_down` flag that drives `AnimatedScale` and `AnimatedOpacity`. It is exposed as a semantic button only when it has a callback.
**Limitations.** No ink ripple by design. Use `InkWell` where Material feedback is expected.
**Tests.** Taps, long press, scale while held, no button semantics when inert.

## PrimaryButton

**Purpose.** A full-width call to action with `isLoading` (spinner, taps blocked, colour kept), `destructive` (error colour), an optional `icon`, and `expand` (full width or hug the content).
```dart
PrimaryButton(label: 'Save', isLoading: saving, onPressed: valid ? save : null)
```
**How it works.** A `FilledButton` whose disabled colours equal its enabled colours while loading, so a busy button does not look disabled. It is a live region, so screen readers hear "Save, loading".
**Tests.** Fires, ignores taps while loading, uses the error colour when destructive.

## AppChip

**Purpose.** A tinted pill for categories and filters: a 10% tint background when unselected, a solid tint with a glow when selected, and a per-chip `color` for colour-coding.
**Edge case.** The text colour on a selected chip is picked from the tint's brightness, so a light tint gets black text.
**Tests.** Tap, selected semantics.

## SectionHeader

**Purpose.** An all-caps eyebrow title with an optional icon and a trailing "See all" action. It is marked as a semantic header.

## SearchField

**Purpose.** A rounded search input with a leading icon and a clear (×) button that appears only while there is text. Clearing calls `onChanged('')`.
**How it works.** It owns a controller when none is given, and re-attaches its listener if the parent swaps the controller (tested). It rebuilds only to toggle the clear button.
**Pair with.** `Debouncer` (08) for search-as-you-type.

## RadialGauge

**Purpose.** A progress ring (0–1) drawn with `CustomPainter`, with an optional centre widget.
**Edge cases.** Values outside 0–1 and NaN are clamped. The centre child is wrapped in `FittedBox(scaleDown)`, so long labels or large system text shrink instead of overflowing (tested). The semantic label defaults to "N percent".

## Skeleton (`Shimmer`, `SkeletonBox`, `SkeletonList`, `SkeletonCardRow`)

**Purpose.** Shimmering placeholders shaped like the content that is loading, so the layout doesn't jump.
**How it works.** One `AnimationController` slides a three-stop `LinearGradient` across a `ShaderMask(srcATop)`. Wrap a whole skeleton layout in a single `Shimmer` so the sweep stays in sync.
**Why rewritten.** It replaces the `shimmer` package with about 40 lines.

## FadeSlideIn / Stagger

**Purpose.** Entrance motion: content fades in while rising 16px. `index` staggers list items (55ms per step).
**How it works.** One controller per item, started after `delayStep × index` with a `Timer` that is cancelled on dispose. When the OS "reduce motion" setting is on (`MediaQuery.disableAnimations`), the content shows immediately.
**Edge case.** A horizontal `Stagger` defaults to centre alignment, because stretching a row needs a bounded height (tested in a scroll view).
**Why rewritten.** It replaces `flutter_animate`.

## FlipCard

**Purpose.** A 3D card flip between `front` and `back`, for flashcards and reveal-the-answer UIs.
```dart
FlipCard(key: ValueKey(card.id), showBack: revealed, onTap: toggle,
         front: Text(card.q), back: Text(card.a))
```
**How it works.** It is declarative: the parent owns `showBack` and the widget animates to it. `Matrix4.rotationY` uses perspective `0.001`. Past 90° the back face is shown, pre-rotated 180° so its content isn't mirrored.
**Edge case.** Give each card a new `key`, so the next card starts face-up instead of animating back over the new content.
**Extracted from** the 1,500-line StudyBuddies review screen.

## SwipeActionTile

**Purpose.** Swipe right to reveal `startAction`, swipe left to reveal `endAction`. Set `dismisses: true` on an action (e.g. delete) to collapse the row before its callback runs.
**How it works.** A single unbounded `AnimationController` holds the horizontal offset. Past the reveal width, dragging gets rubber-band resistance (30%), and crossing the halfway threshold fires a light haptic. On release the row snaps open or closed. A dismissing action reverses a second controller driving `SizeTransition` + `FadeTransition`.
**Accessibility.** Both actions are also exposed as custom semantics actions, so screen-reader users can reach them without swiping (tested).
**Limitations.** Tapping the row while it is open doesn't close it, because the child's own gestures take priority. Swiping it back closes it.
**Tests.** Reveal + delete after collapse, snap back on a short swipe, blocked direction, non-dismissing action, semantics action.

## ActivityHeatmap

**Purpose.** A GitHub-style grid of the last N weeks (Monday at the top), shaded by a per-day number, with a Less→More legend and optional tooltips.
```dart
ActivityHeatmap(values: {for (final s in sessions) s.date: s.minutes},
                levelThresholds: const [20, 60], tooltip: (d, v) => '${v.round()} min')
```
**How it works.** `sumByDay` collapses timestamps to dates. `heatmapColumns` builds week columns from year/month/day (never `Duration(days:)`), so daylight-saving changes cannot shift a cell (tested). `heatmapLevel` counts the thresholds exceeded, and cell size is computed from the available width (6–18px).
**Generalised from** StudyBuddies' study-session-only version with built-in card chrome.

## SimpleBarChart

**Purpose.** A small bar chart with an optional dashed target line and a highlighted bar (e.g. "today").
**How it works.** Bars are animated `Container`s inside `Expanded` columns, and the target is a `CustomPaint` dashed line. `chartMax` adds 15% headroom and never returns 0, so an all-zero chart still lays out. Each bar has a semantic label, formatted by `valueFormatter`.
**Why new.** Cookly pulled in `fl_chart` for seven bars and one line.
**Limitations.** No axes, gridlines, negative values or scrolling. Use a chart package for analytical charts.

## SpinWheel

**Purpose.** A decision/prize wheel. `controller.spinTo(index)` or `spinRandom(n)` spins it, `onSettled(index)` reports the result, and a haptic tick fires as each slice passes the pointer.
**How it works.** `spinEndAngle` computes the forward distance from the current resting angle to the target slice's centre, plus four full turns, eased with `easeOutQuart`. `sliceUnderPointer` maps an angle back to a slice, which drives the ticks.
**Bug fixed.** Cookly's wheel computed the end angle as if every spin started from 0. From the second spin on, the wheel visibly stopped on a different slice from the one it reported. The test spins 50 times per slice count and checks the landed slice every time.
**Simplified.** The decorative bezel, pegs and glass hub were dropped (693 → ~250 lines).

## MarkdownView

**Purpose.** Renders the Markdown subset AI models produce: headings, bullet and numbered lists (nested), quotes, fenced code (horizontal scroll, verbatim), pipe tables, and inline bold, italic, code and strikethrough. `selectable: true` wraps it in a `SelectionArea`.
**How it works.** `parseMarkdown` (11) produces blocks, a `switch` maps each block to a widget, and `markdownSpans` maps the inline runs to `TextSpan`s.
**Limitations.** Links, images and HTML render as plain text. For full CommonMark, use `flutter_markdown`.

**Folder tests: 36** (`basic_elements_test`, `interactive_elements_test`, `data_display_test`).

---

## Phase 2 additions

| File | Components | Extra deps |
|---|---|---|
| `app_buttons.dart` | `AppButton` (`ButtonVariant`, `ButtonSize`), `SocialSignInButton` (`SocialProvider`) | — |
| `text_inputs.dart` | `AppTextField`, `PasswordField`, `PinCodeField`, `TagInputField` | — |
| `cards.dart` | `StatCard`, `ActionCard`, `ImageCard` | — |
| `animations.dart` | `AnimatedCounter`, `SuccessCheckmark`, `Shake` + `ShakeController` | — |
| `line_chart.dart` | `SimpleLineChart`, `Sparkline`, `plotPoints` | — |
| `donut_chart.dart` | `DonutChart`, `ChartSegment`, `donutSweeps`, `chartPalette` | — |

All are new (none of the four apps had them as reusable pieces). Tests: `test/02_ui_elements/new_elements_test.dart`.

### AppButton / SocialSignInButton
**Purpose.** One button for every case: `filled`, `tonal`, `outlined`, `text`, `destructive` × `small` (36), `medium` (44), `large` (52), with `icon`, `isLoading` and `expand`. `SocialSignInButton` is the "Continue with Apple / Google / email / phone" row.
```dart
AppButton(label: 'Delete', variant: ButtonVariant.destructive, icon: Icons.delete, onPressed: confirm)
AppButton(label: 'Save', isLoading: saving, expand: true, onPressed: save)
```
**How it works.** Maps the variant to the matching Material 3 button. While loading it wraps the button in `IgnorePointer` and passes a no-op handler, so the colours stay "enabled" and a spinner replaces the icon.
**Limitations.** Brand guidelines for Apple/Google buttons are approximated with theme colours — check the official guidelines before a store submission.

### Text inputs
**Purpose.** `AppTextField` (label, `isRequired` adds " *" and a required validator, `clearable`), `PasswordField` (show/hide toggle with tooltip), `PinCodeField` (OTP boxes), `TagInputField` (chips typed with Enter or comma).
```dart
PinCodeField(length: 6, onCompleted: verify)
TagInputField(tags: tags, onChanged: setTags, suggestions: ['dart', 'flutter'], maxTags: 5)
```
**How it works.** `PinCodeField` is one hidden `TextField` (digits only, `AutofillHints.oneTimeCode` so SMS autofill works) drawn as boxes. `TagInputField` de-duplicates case-insensitively, offers suggestions as `ActionChip`s, and removes the last tag on Backspace in an empty field via a state-owned `FocusNode.onKeyEvent`.
**Limitations.** `PinCodeField` is digits-only. Tags are plain strings.

### Cards
**Purpose.** `StatCard` (label, value, icon, `delta` as a fraction — `0.12` shows "+12%" — coloured success/error, `higherIsBetter` flips the colour for things like spending), `ActionCard` (icon + title + subtitle + chevron), `ImageCard` (image with a placeholder icon when missing, optional badge).
**Accessibility.** `StatCard` reads as one sentence: "Study time: 6h, +12%".

### Animations
**Purpose.** `AnimatedCounter` (numbers count up/down), `SuccessCheckmark` (drawn tick with `onCompleted`), `Shake` (wrong-answer / wrong-PIN shake with an error haptic).
**How it works.** `TweenAnimationBuilder`, a `CustomPainter` and a `ChangeNotifier` trigger. All three skip the motion when the OS (or `AccessibilityScope`, 13) asks to reduce motion.

### SimpleLineChart / Sparkline / DonutChart
**Purpose.** Dependency-free charts: a line chart with optional dashed comparison series (e.g. last week), area fill, dots and labels; a tiny sparkline for cards; a donut with legend and centre label.
```dart
SimpleLineChart(values: thisWeek, comparison: lastWeek, labels: ['M','T','W','T','F','S','S'])
DonutChart(segments: [ChartSegment('Food', 260), ChartSegment('Rent', 700)], centerLabel: '€960')
```
**How it works.** `plotPoints` maps values to the canvas (pure, unit-tested); `donutSweeps` turns values into angles. `chartPalette` derives distinct colours from the theme (de-duplicated, hue-rotated when the scheme has few colours).
**Accessibility.** Each chart has a spoken summary ("Line chart, from 30 to 64, high 70"; "Food 260, 27%; Rent 700, 73%").
**Limitations.** No touch tooltips, zoom or axes with ticks — use `fl_chart` if the problem needs them.
