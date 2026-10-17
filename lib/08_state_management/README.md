# 08 · State management

Riverpod 3 patterns that every source app re-implemented per screen, plus two framework-neutral controllers.

| File | Component | Source | Deps |
|---|---|---|---|
| `action_controller.dart` | `ActionController` | Cookly `AuthController._run` + StudyBuddies `AuthNotifier._run` | flutter_riverpod |
| `pagination_controller.dart` | `PaginationController<T>`, `PaginatedState<T>`, `PageResult<T>` | Couple `pagination.dart` (state only) | flutter_riverpod |
| `countdown_controller.dart` | `CountdownController` | StudyBuddies `focus_timer_notifier.dart` | — |
| `debouncer.dart` | `Debouncer` | TaskFlow `debounce.dart` | — |

**Why Riverpod 3.** All four apps use Riverpod, and two are already on 3.x. In 3.x, `StateNotifier`/`StateProvider` are legacy, so everything here is a `Notifier`. Note two Riverpod 3 rules these components respect: `state` cannot be assigned inside `build()`, and async work checks `ref.mounted` before writing state.

---

## ActionController

**Purpose.** Runs one user-triggered async action (sign in, save, delete) and exposes it as `AsyncValue<void>`.
```dart
final saveNote = NotifierProvider.autoDispose<ActionController, AsyncValue<void>>(ActionController.new);

final state = ref.watch(saveNote);
PrimaryButton(label: 'Save', isLoading: state.isLoading, onPressed: () async {
  if (await ref.read(saveNote.notifier).run(() => repo.save(note)) && context.mounted) {
    Navigator.pop(context);
  }
});
if (state.hasError) Text(AppException.from(state.error!).message);
```
**Behaviour.** `run` returns `true` on success, so the screen can navigate without re-reading state. A second `run` while busy returns `false` and does nothing (StudyBuddies' double-tap guard, which stopped a duplicate sign-up). `reset()` clears an error.
**Integration.** Declare one provider per action, so two buttons never share a spinner.
**Tests.** Success, failure kept as an error, busy guard.

## PaginationController

**Purpose.** Cursor-based infinite lists: the first page on build, `loadMore()` (safe to call from every scroll event), `refresh()`, and an `error` that keeps the rows already loaded.
```dart
final notesPager = NotifierProvider.autoDispose<PaginationController<Note>, PaginatedState<Note>>(
  () => PaginationController((ref, cursor) => ref.read(notesRepo).page(after: cursor)),
);
// in ListView.builder: if (i == state.items.length - 1) ref.read(notesPager.notifier).loadMore();
```
**How it works.** `PageResult(items, nextCursor)`, where a null cursor means the end. A generation counter makes a page requested before a `refresh()` get discarded. `copyWith` uses a sentinel so nullable fields (`cursor`, `error`) can be cleared explicitly (tested).
**Limitations.** Forward-only and append-only. Inserting new rows at the top (a chat) needs a different cursor scheme.
**Tests.** Pages to the end, error then retry, refresh, sentinel `copyWith`.

## CountdownController

**Purpose.** A pausable countdown that is still correct after the app was backgrounded, for exam timers, focus timers and OTP resend timers.
**How it works.** On `start()` it stores a wall-clock deadline. Every `tick` (250ms) and every `resync()` recompute `remaining = deadline − now`. Counting down by one per tick (the naive approach) drifts and freezes while the OS suspends the app. `formatted` rounds up, so "0:00" appears only at the end. `onFinished` fires exactly once.
**Integration.** It is a `ChangeNotifier`: use `ListenableBuilder`, or Riverpod via `Provider` + `ref.onDispose(c.dispose)`. Call `resync()` from `AppLifecycleListener(onResume:)`. The clock is injectable for tests.
**Limitations.** It does not run while the app is killed. For an alert at the end time, schedule a `Reminder` (12) as well.
**Tests.** Countdown and single finish (`fake_async`), pause/reset, correct remaining time after "5 minutes in another app" with no ticks.

## Debouncer

**Purpose.** Runs an action only after calls stop for `delay`: `run(action)`, `cancel()`, `flush(action)` (run now if pending, e.g. autosave on leave), `isPending`, `dispose()`.
**Riverpod pattern (corrected).** TaskFlow's debounced-search provider returned the raw query from `build()`, so it never actually debounced. The working version keeps the old value until the timer fires:
```dart
class DebouncedQuery extends Notifier<String> {
  @override
  String build() {
    final query = ref.watch(queryProvider);
    final timer = Timer(const Duration(milliseconds: 300), () => state = query);
    ref.onDispose(timer.cancel);
    return stateOrNull ?? query;
  }
}
```
**Tests.** Only the last call runs, cancel, flush.

**Folder tests: 13** (`state_management_test.dart`, including one for the corrected debounced-provider pattern).

---

## Phase 2 additions

### CrudController (`crud_controller.dart`)
**Purpose.** The `AsyncNotifier` every "list of things" needs, over any `Repository<T>` (09): load, optimistic save (upsert), optimistic delete with undo, reload.
```dart
final tasksProvider = AsyncNotifierProvider<CrudController<Task>, List<Task>>(
  () => CrudController((ref) => ref.read(taskRepositoryProvider),
      idOf: (t) => t.id, sort: (a, b) => a.due.compareTo(b.due)),
);
final removed = await ref.read(tasksProvider.notifier).delete(id);   // keep for Undo
```
**How it works.** Updates `state` first, then writes; on failure it restores the previous list and rethrows so the UI can show the error.
**Limitations.** Whole-list state (fine up to a few thousand items). Not for paginated server lists — use `PaginationController`.

### ListQuery / applyListQuery (`list_query.dart`)
**Purpose.** Search + filter + sort for any list, as one immutable value (`ListQuery`) and one pure function.
```dart
final visible = applyListQuery(items, query,
    searchableText: (t) => t.title,
    filters: [FilterOption('done', 'Done', (t) => t.done)],
    sorts: [SortOption('title', 'A–Z', (a, b) => a.title.compareTo(b.title))],
    filterMode: FilterMode.all);
```
**How it works.** Every query word must appear (any order); matching ignores case, accents and punctuation (`normalizeForSearch`); sorting is stable and re-selecting a sort flips its direction.

Tests: `test/08_state_management/crud_and_query_test.dart`.
