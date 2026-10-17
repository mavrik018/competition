# 09 · Persistence

Local storage for settings, offline writes and offline reads.

| File | Component | Source | Deps |
|---|---|---|---|
| `prefs_store.dart` | `PrefsStore`, `PrefKey<T>`, `prefsStoreProvider` | **new** | shared_preferences, flutter_riverpod |
| `local_id.dart` | `generateLocalId()` | Cookly `local_id.dart` | — |
| `offline_queue.dart` | `OfflineQueue`, `PendingOp`, `OpOutcome`, `DrainResult` | Couple + StudyBuddies + Cookly (merged) | sqflite |
| `json_cache.dart` | `JsonCache` | Cookly `local_cache_db.dart` | sqflite |

## One database for both

```dart
final db = await openDatabase(
  p.join(await getDatabasesPath(), 'app.db'),
  version: 1,
  onCreate: (db, _) async {
    await OfflineQueue.createTable(db);
    await JsonCache.createTables(db);
  },
);
final queue = OfflineQueue(db);
final cache = JsonCache(db);
```
`createTable(s)` use `if not exists`, so they can also run from `onUpgrade` when adding them to an existing database.

**Why sqflite and not Drift.** Three of the four apps avoid code generation. Couple's docs explicitly ban `build_runner`, and Drift requires it. Raw SQL in two small tables is simpler than a generated layer.

---

## PrefsStore

**Purpose.** Typed SharedPreferences: declare each key once with its type and default, then `get` and `set` it.
```dart
abstract final class Prefs {
  static const onboardingDone = PrefKey<bool>('onboarding_done', false);
  static const recentSearches = PrefKey<List<String>>('recent_searches', []);
}
// main: override prefsStoreProvider with PrefsStore(await SharedPreferences.getInstance())
store.get(Prefs.onboardingDone);  await store.set(Prefs.onboardingDone, true);
await store.setJson('quiz_in_progress', session.toJson());   // objects
```
**Edge cases.** A value stored with the wrong type returns the default (tested). Corrupt JSON reads as `null` and never throws. `set` throws `ArgumentError` for unsupported types.
**Why.** The source apps scattered string keys and repeated defaults (`'onboarding_completed'`, `'is_dark_mode'`, `'streak_last_used_date'`, …) at every call site.

## generateLocalId

A cryptographically random UUID v4 (`Random.secure`). Creating ids on the client is what makes offline-first simple: the row keeps the same id when it syncs, so no temporary-id remapping is needed. Tested for format and for 500 unique ids.

## OfflineQueue

**Purpose.** A durable FIFO of writes made offline, replayed when the connection returns.
```dart
await queue.enqueue('note_upsert', note.toJson(), userId: uid);

ref.listen(isOnlineProvider, (was, online) async {                 // 10_backend
  if (!online) return;
  final result = await queue.drain(userId: uid, handlers: {
    'note_upsert': (p) async { await supabase.from('notes').upsert(p); return OpOutcome.done; },
    'note_delete': (p) async { await supabase.from('notes').delete().eq('id', p['id']); return OpOutcome.done; },
  });
  if (result.dropped.isNotEmpty) context.showError('Some changes could not be saved.');
});
```
**How it works.**
- Table `pending_ops(id, user_id, op_type, payload JSON, attempts, next_attempt_at, created_at, last_error)`.
- `drain` replays due ops oldest-first. A handler returns `done` (removed), `drop` (removed and reported, e.g. a conflict or validation failure) or `retry`. A thrown exception counts as `retry`.
- The first `retry` **stops the drain** (StudyBuddies: the rest will fail the same way offline) and schedules the op with capped exponential backoff: 30s, 1m, 2m, 4m, then 8m (Couple).
- After `maxAttempts` (5) an op is no longer retried automatically, but it stays in the table for `retryNow(id)` or `remove(id)`. Couple's rule: never silently delete a user's write.
- Ops are scoped by `userId`, and `clearUser` runs on sign-out (Cookly).
- An op type with no handler is left untouched, in case a newer build queued it.
- Re-entrant `drain` calls return immediately.

**Architectural reasoning.** Couple's coordinator hard-coded a `switch` over feature repositories, and StudyBuddies' service hard-coded the `notes` and `courses` tables. Passing handlers in makes the queue a reusable component that knows nothing about any feature.
**Limitations.** No automatic conflict detection: do it in the handler (e.g. compare `updated_at` like StudyBuddies did, and return `drop`). Strict ordering holds only within one drain. Files referenced by ops must be copied somewhere durable first (Couple's `stageFileForQueue`).
**Tests (real SQLite via `sqflite_common_ffi`).** Order and removal, retry stops and backs off, the backoff table, exhaustion and `retryNow`, drop reporting, per-user scoping and unknown types, the re-entrancy guard.

## JsonCache

**Purpose.** An offline read cache: the last successful fetch of a list (or of a single item), per user, with a sync timestamp.
```dart
try {
  final rows = await supabase.from('notes').select();
  unawaited(cache.saveCollection(uid, 'notes', rows));
  return rows.map(Note.fromJson).toList();
} catch (e) {
  final cached = await cache.loadCollection(uid, 'notes');
  if (cached == null) rethrow;                   // never synced → a real error
  return cached.map(Note.fromJson).toList();     // show OfflineBanner(syncedAt: …)
}
```
**How it works.** `saveCollection` replaces the whole collection in one transaction and stores order in `position`. Item ids default to the `'id'` field, then the position. `loadCollection` returns `null` for "never synced" and `[]` for "synced, empty", which callers use to choose between an error and an empty state (tested). `saveItem`/`loadItem` cache single records under `key/itemId`. `syncedAt(uid, key)` feeds `OfflineBanner`. Save failures are logged, never thrown: the fetch already succeeded.
**Limitations.** Whole-collection replacement suits tens to hundreds of rows, not thousands. Use different keys for a collection and for its single items (`'notes'` vs `'note'`), because `saveCollection` clears its key.
**Tests.** Null vs empty, replacement and order, id fallback, single items, per-user clearing.

**Folder tests: 15** (`persistence_test.dart`).

---

## Phase 2 additions — `Repository<T>` and its storage implementations

| File | Class | Storage | Platforms | Packages |
|---|---|---|---|---|
| `repository.dart` | `Repository<T>` interface, `InMemoryRepository<T>`, `watchList` helper | memory | all | none (pure Dart) |
| `sqflite_repository.dart` | `SqfliteRepository<T>` | SQLite, one JSON row per item | Android, iOS, macOS; Windows/Linux via `sqflite_common_ffi` — **not the web** | sqflite |
| `prefs_repository.dart` | `PrefsRepository<T>` | shared preferences, one JSON list | **all, including the web** | shared_preferences |

`SupabaseRepository<T>` (10) and `OfflineFirstRepository<T>` (13) implement the same interface, so screens and `CrudController` never change when storage does. Choose storage in one provider:
```dart
final itemRepositoryProvider = Provider<Repository<Item>>((ref) => PrefsRepository<Item>(
  key: 'items', idOf: (i) => i.id, toJson: (i) => i.toJson(), fromJson: Item.fromJson,
));
```

**How it works.** `SqfliteRepository` rows are `(id, json, updated_at)` (call `SqfliteRepository.createTable(db, 'tasks')` in `onCreate`), so no migration is needed when the model gains a field; reads are newest-updated first. `PrefsRepository` keeps the collection in memory after the first read and rewrites one JSON list on each save; updates keep an item's position. Every `watchAll()` emits the current list on listen and after every write made through that repository (shared `watchList` helper).

**Split during verification.** `SqfliteRepository` used to live in `repository.dart`, so anything that only needed the interface (`CrudController`, `SupabaseRepository`) pulled in sqflite, which does not run on the web. The interface file is now dependency-free.

**Bug fixed during testing.** The first `watchAll` subscribed to changes only after its initial load finished, so a write made right after `listen` was missed; it now subscribes immediately and drops a stale initial load.

**Limitations.**
- SQLite JSON rows cannot be queried by field in SQL — filter in Dart (`applyListQuery`) or use real columns for large tables.
- `PrefsRepository` is for small collections (hundreds of items). The shared_preferences docs say writes are not guaranteed to be on disk when the call returns and the plugin "must not be used for storing critical data". Unreadable items are skipped (and logged), not fatal.
- Writes made by other code paths (raw SQL, another `PrefsRepository` on the same key) are not observed.

**Tests.** `test/08_state_management/crud_and_query_test.dart` (in-memory and SQLite via `sqflite_common_ffi`), `test/09_persistence/prefs_repository_test.dart` (CRUD, restart, watch, corrupt data — with `InMemorySharedPreferencesAsync`). The starter template and the expense mini-app also test persistence across a simulated restart.
