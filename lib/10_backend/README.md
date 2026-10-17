# 10 · Backend integrations

Supabase (auth, database errors, Edge Functions, Storage, Realtime), connectivity, and RevenueCat subscriptions. The network calls themselves are thin; the logic around them (error mapping, retries, envelopes, caching) is behind seams and unit-tested.

| File | Component | Source | Deps |
|---|---|---|---|
| `supabase_bootstrap.dart` | `initializeSupabase`, `SupabaseConfig`, `supabaseClientProvider`, `authStateProvider`, `currentUserProvider`, `userIdChanges` | Cookly `supabase_client.dart` | supabase_flutter, flutter_riverpod |
| `app_exception.dart` | `AppException`, `AppErrorKind` | Cookly + StudyBuddies + TaskFlow | supabase_flutter |
| `auth_service.dart` | `AuthService`, `AppleSignInResult`, `generateNonce`, `sha256Hex` | StudyBuddies + Cookly | supabase_flutter, sign_in_with_apple, crypto |
| `edge_function_client.dart` | `EdgeFunctionClient`, `EdgeFunctionFailure` | StudyBuddies `ai_edge_client.dart`, `ai_failure.dart` | supabase_flutter |
| `storage_uploader.dart` | `StorageUploader`, `UploadHandle`, `storagePath`, `SignedUrlCache` | Couple `upload_manager.dart`, `signed_url_cache.dart` | supabase_flutter |
| `realtime_presence.dart` | `PresenceRoom`, `onlineIdsFrom` | Couple `couple_presence_channel.dart` | supabase_flutter |
| `connectivity.dart` | `connectivityProvider`, `isOnlineProvider`, `hasConnection` | Couple + Cookly | connectivity_plus, flutter_riverpod |
| `purchases_gateway.dart` | `PurchasesGateway`, `RevenueCatGateway`, `baseProductId`, `planForProduct` | Cookly | purchases_flutter, flutter_riverpod |

## Setup

```bash
flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxx
```
```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final startupError = await initializeSupabase();   // null on success
  runApp(ProviderScope(child: App(startupError: startupError)));
}
```
No URL or key is baked into source (Cookly had defaults committed). The publishable key is meant to ship in apps; row-level security protects the data. Never put the `service_role` key in the client.

---

## AppException

**Purpose.** One place that turns any backend error into `AppException(message, kind)`, where `message` is safe to show and `kind` is one of `auth`, `offline`, `permission`, `validation`, `rateLimited`, `quotaExceeded`, `server` or `unknown`.

| Input | Result |
|---|---|
| `AuthRetryableFetchException` (checked before `AuthException`) | offline |
| `AuthException` | auth, wording rewritten for common cases (bad credentials, already registered, unconfirmed, rate limit, expired OTP), otherwise passed through |
| `PostgrestException` 23505 / 23503 / 23514 / 23502 / 42501 / PGRST116 / PGRST301 | "already exists" / "depends on" / "not allowed" / "missing" / permission / "no longer there" / session expired |
| `StorageException` 413 or "too large" / 403 | file too large / no access |
| `FunctionException` `reason: quota_exhausted\|limit_reached` / `rate_limited` or 429 / 401 | quotaExceeded / rateLimited / auth, preferring the server's `message` |
| `TimeoutException`, or text containing socket / client / host-lookup / connection | offline |
| anything else | unknown, "Something went wrong. Please try again." |

`isRetryable` tells the UI whether to offer Retry. **Web-safe:** connection errors are recognised by text instead of importing `dart:io` (Cookly's version broke web builds).
**Tests.** Every row above.

## AuthService

**Purpose.** Every Supabase auth flow behind one class, with a 15-second timeout and `AppException` errors.

| Method | Notes |
|---|---|
| `signUp(email, password, name)` | stores `full_name` in user metadata, sends `emailRedirectTo` |
| `signIn(email, password)` | trims the email |
| `signInWithOAuth(provider)` | opens the **external** browser on mobile: iOS's in-app Safari sheet cannot follow the custom-scheme redirect and is left showing a blank page (StudyBuddies) |
| `signInWithApple()` | native sheet with a SHA-256 nonce (replay protection). Returns `null` when the user cancels. Returns `fullName`, which Apple sends **only on the first authorization**, so persist it then. Falls back to OAuth on the web |
| `sendPasswordResetCode`, `verifyRecoveryCode`, `updatePassword` | an OTP code flow (the email template must show `{{ .Token }}`) |
| `signOut(beforeSignOut:)` | clear caches and queues (09) first, best-effort |
| `deleteAccount(beforeSignOut:)` | calls your `delete-account` Edge Function (service role). Signs out locally **only after** the server succeeds |

**Changed from the sources.** StudyBuddies wrote names into its own `users` table, which was removed (the result is returned instead). Couple signed out even when deletion failed, which looks like success while the account still exists. This version keeps the user signed in and throws.
**Not unit-tested.** The flows need a live Supabase project and native sheets. They are covered by analysis, and the pure parts (`generateNonce`, `sha256Hex` against a known vector) are tested.

## EdgeFunctionClient

**Purpose.** Calls Edge Functions that return a standard envelope: `{"ok":true,"data":{…}}` or `{"ok":false,"error":{"code","message","retryable","details"}}`.
```dart
final functions = EdgeFunctionClient.supabase(Supabase.instance.client);
final quiz = await functions.call('generate-quiz', body: {'note_id': id}, parse: Quiz.fromJson);
```
**Behaviour.** Fails fast when signed out (no wasted request). Treats the envelope as authoritative even on HTTP 200. A non-2xx response with an envelope keeps the server's code and message. A non-envelope body (gateway HTML, empty) becomes a retryable `transport` failure. A `parse` exception becomes `bad_response`, so schema drift on the server doesn't look like a client crash.
**Server side.** Return the same envelope from every function. StudyBuddies kept one `_shared/errors.ts` for this.
**Tests.** All five paths, using an injected invoker.

## StorageUploader / SignedUrlCache

```dart
final uploader = StorageUploader.supabase(client, bucket: 'media');
final handle = UploadHandle();                       // call handle.cancel() if the user leaves
final path = await uploader.upload(
  bytes: bytes,
  path: storagePath(ownerId: uid, folder: 'avatars', extension: 'jpg'),
  contentType: 'image/jpeg',
  handle: handle,
);
await supabase.from('profiles').update({'avatar_path': path}).eq('id', uid); // only after upload
final url = await SignedUrlCache.supabase(client, bucket: 'media').get(path);
```
**Behaviour.** Up to 3 attempts with 2s and 4s waits. Cancellation is checked before each attempt (Supabase has no mid-request abort). Paths are `{owner}/{folder}/{uuid}.{ext}`, so Storage RLS can check `(storage.foldername(name))[1] = auth.uid()`. `SignedUrlCache` re-signs 30 seconds before expiry so a slow render never gets a dead link.
**Changed from the source.** Image and video compression (two native plugins) was left out: compress first with `flutter_image_compress` or `video_compress` if you need it. Progress is 0 → 1 per attempt, because Supabase reports no byte progress.
**Tests.** Retries and waits, exhausted attempts, cancel, path format, URL refresh timing.

## PresenceRoom

**Purpose.** "Who is online" for any room (a team, a document, a couple) via Realtime Presence.
```dart
final room = PresenceRoom(client, room: 'team:$teamId', userId: uid)..join();
StreamBuilder<Set<String>>(stream: room.onlineUserIds, builder: …);
ref.listen(isOnlineProvider, (was, now) { if (was == false && now) room.rejoin(); });
```
Re-announces presence from scratch after a reconnect instead of assuming it survived (Couple's rule). A private channel needs a Realtime authorization policy. **Tests.** `onlineIdsFrom` (de-duplicating several devices per user). The channel itself needs a live server.

## connectivityProvider / isOnlineProvider

A `StreamProvider<bool>` that emits the current state first, then only real changes. `isOnlineProvider` is synchronous and optimistic (`true` until the first reading), so a slow plugin never flashes an offline banner. It reports link-layer connectivity, not whether your server is reachable.

## PurchasesGateway (RevenueCat)

An interface over the static `Purchases` API, so subscription logic can be tested with a fake (Cookly's real bug, a listener never re-attached after sign-in, was only catchable that way). Rules kept from Cookly: configure **once** with your user id, then `logIn` to switch users and never `logOut`; strip the Play `:base-plan` suffix (`baseProductId`) before matching products (`planForProduct`); unlock features from your **server's** entitlement record (written by the RevenueCat webhook), not from the SDK's `CustomerInfo`.
**Not included.** Cookly's 600-line `SubscriptionNotifier` and paywall: they depend on its own backend tables and webhook.

**Folder tests: 24** (`backend_test.dart`).

---

## Phase 2 additions

### ApiClient (`api_client.dart`)
**Purpose.** A small REST client for any JSON API (open data, weather, a sponsor's API): base URL, bearer token, default headers, timeout, typed errors, safe retries.
```dart
final api = ApiClient(baseUrl: 'https://api.example.com/v1', authToken: token);
final items = await api.get('/items', query: {'page': 2, 'q': null});   // null values dropped
await api.post('/items', body: {'name': 'Milk'});
```
**How it works.** Retries only idempotent methods (`maxRetries` 2; POST is never retried) on network errors, timeouts, 429 and 5xx, waiting 0.5 s·2ⁿ or the server's `Retry-After` (capped at 30 s). Failures become a typed `ApiException(kind:, statusCode:, isRetryable:)`; the server's message is shown only for 4xx (5xx bodies are not user-safe). The `http.Client` and the wait function are injectable, so tests run instantly.
**Limitations.** JSON only (no multipart — use `StorageUploader` for files); no caching (pair with `JsonCache`, 09).
**Tests.** `test/10_backend/api_client_test.dart` (uses `http/testing` `MockClient` — no network).

### SupabaseRepository (`supabase_repository.dart`) 🔶
`Repository<T>` over a Supabase table: `select` / `upsert` / `delete`, `watchAll()` via `.stream(primaryKey:)` (needs Realtime enabled on the table), errors mapped to `AppException`.
```dart
SupabaseRepository<Note>(client, table: 'notes', fromRow: Note.fromJson, toRow: (n) => n.toJson(), idOf: (n) => n.id, orderBy: 'updated_at')
```
**Setup.** A table with an `id` primary key and RLS policies scoping rows to `auth.uid()`. **Not unit-tested** (needs a live project); it is a thin mapping over the Supabase client.
