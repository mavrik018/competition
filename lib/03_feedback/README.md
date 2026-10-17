# 03 · Feedback and states

How a screen tells the user what is happening: a receipt for an action, the loading / empty / error states, being offline, and progress through a long job.

| File | Component | Source |
|---|---|---|
| `app_snackbars.dart` | `context.showSuccess/showError/showInfo`, `AppSnackbars` | StudyBuddies + Cookly |
| `state_views.dart` | `LoadingView`, `EmptyView`, `ErrorView` | StudyBuddies, Cookly, Couple |
| `async_value_view.dart` | `AsyncValueView<T>` | **new** |
| `offline_banner.dart` | `OfflineBanner`, `PendingSyncBanner` | Couple + Cookly |
| `step_progress.dart` | `StepProgressView`, `ProgressStep` | StudyBuddies |

**Dependencies:** Flutter. `AsyncValueView` also needs `flutter_riverpod`.

---

## Snackbars

**Purpose.** One-line success, error and info receipts that look the same on every screen. Raw exception text never reaches the user.
```dart
try {
  await repo.save(note);
  if (context.mounted) context.showSuccess('Note saved');
} catch (e, st) {
  if (context.mounted) context.showError("Couldn't save your note.", error: e, stackTrace: st, onRetry: save);
}
```
**How it works.** It is an extension on `BuildContext` that delegates to `AppSnackbars`. The static `AppSnackbars` versions take a `ScaffoldMessengerState` captured before an `await`, which is Cookly's convention for avoiding stale contexts. A new snackbar replaces the current one instead of queueing behind it (tested). An error with `onRetry` gets a Retry action and stays up 5 seconds. Errors are logged with `debugPrint`, including the stack trace.
**Edge cases.** With no `ScaffoldMessenger` it is a silent no-op. The success colour comes from `SemanticColors`.
**Tests.** Success icon, Retry callback, replacement.

## LoadingView / EmptyView / ErrorView

**Purpose.** The three non-happy-path states, sharing one layout (tinted icon disc, title, message, action). `compact: true` gives less padding for use inside a section.
**Rules kept from the source.** Empty is not an error, so give it a next step with `actionLabel` + `onAction`. ErrorView expects a human sentence, so map exceptions first with `AppException.from(e).message`.
**Tests.** Empty action shown only with a callback, error retry, loading message.

## AsyncValueView

**Purpose.** Renders a Riverpod `AsyncValue` as loading, error, empty or data, so screens stop hand-writing `.when(...)` three different ways.
```dart
AsyncValueView(
  value: ref.watch(notesProvider),
  onRetry: () => ref.invalidate(notesProvider),
  isEmpty: (notes) => notes.isEmpty,
  empty: const EmptyView(icon: Icons.notes, title: 'No notes yet'),
  errorMessage: (e) => AppException.from(e).message,
  data: (notes) => NotesList(notes),
)
```
**How it works.** It checks `hasValue` first, so during a refresh the previous data stays on screen instead of flashing a spinner (tested with a real `invalidate`). Then error, then loading. `loading:` accepts a skeleton.

## OfflineBanner

**Purpose.** A persistent strip saying the device is offline. Being offline is ongoing state, so this is a banner, not a toast. With `syncedAt` it says "Showing data saved 12m ago".
**How it works.** It takes plain values (`isOnline`, `syncedAt`), so it works with any connectivity source. Pair it with `isOnlineProvider` (10) and `JsonCache.syncedAt` (09). It animates its size in and out, and is a live region.

## PendingSyncBanner

**Purpose.** "3 changes waiting to sync" with a **Sync now** button that is shown only while online. It hides at 0, shows a spinner while syncing, and stays up if the sync fails (tested).
**Pair with.** `OfflineQueue.pendingCount()` and `OfflineQueue.drain()` (09).

## StepProgressView

**Purpose.** Shows a long job (an AI pipeline, an upload) as a checklist of real steps with a running clock and an optional determinate bar for the current step.
**Why (from StudyBuddies).** A one-minute job behind a bare spinner is indistinguishable from a hang. The clock is the cheapest proof of life. Nothing advances on a timer: steps move only when `currentKey` changes, so the indicator never lies.
**How it works.** `currentStepIndex` finds the active step (unknown or null means the first). Earlier steps show as done. A 1-second `Timer.periodic`, cancelled on dispose, updates the `mm:ss` clock with tabular figures.
**Tests.** Index and clock helpers, done ticks, determinate bar only on the current step.

**Folder tests: 16** (`feedback_test.dart`).

---

## Phase 2 additions — `loading_overlay.dart`

| Component | Purpose |
|---|---|
| `runWithLoading(context, task, message:)` | Shows a blocking progress dialog while `task` runs and **always** closes it (in `finally`), returning the task's result or rethrowing its error. |
| `LoadingOverlay(isLoading:, child:, message:)` | Dims and blocks one area (a form) instead of the whole app. |
| `StatusBanner(kind:, message:, title:, actionLabel:, onAction:, onDismiss:)` | Inline info / success / warning / error banner (`StatusKind`) for messages that should stay on screen, unlike a snackbar. |

```dart
final saved = await runWithLoading(context, () => repo.save(note), message: 'Saving…');
StatusBanner(kind: StatusKind.warning, message: 'You are offline. Changes will sync later.')
```
**Limitations.** `runWithLoading` blocks the whole screen — prefer a button's `isLoading` for short actions.
**Tests.** `test/03_feedback/loading_overlay_test.dart` (dialog closes on success and on error, overlay blocks taps, banner actions).
