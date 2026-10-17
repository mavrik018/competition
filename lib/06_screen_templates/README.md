# 06 · Screen templates

Whole screens you configure instead of building. They compose components from 01–05 and leave all I/O to the caller.

| File | Component | Source | Uses |
|---|---|---|---|
| `onboarding_pager.dart` | `OnboardingPager`, `OnboardingSlide` | Couple (+ dot style from StudyBuddies/Cookly) | 01 |
| `auth_form_screen.dart` | `AuthFormScreen`, `AuthMode`, `AuthFormData` | Cookly `auth_scaffold.dart` + StudyBuddies/Cookly sign-in & sign-up | 01, 02, 05 |
| `responsive_frame.dart` | `MaxWidthFrame`, `MaxWidthSliver`, `context.isTablet`, `adaptiveColumnCount` | StudyBuddies `tablet_frame.dart`, `responsive.dart` | — |

---

## OnboardingPager

**Purpose.** A first-run walkthrough: swipeable slides (an icon or any image widget, a title, body text), animated page dots (the active dot stretches into a pill), Skip, and Next becoming "Get started" on the last slide.
```dart
OnboardingPager(
  slides: const [
    OnboardingSlide(icon: Icons.bolt, title: 'Capture fast', body: 'Snap, record or type.'),
    OnboardingSlide(image: Image(image: AssetImage('assets/sync.png')), title: 'Synced', body: 'On every device.'),
  ],
  onFinish: () async {
    await prefs.set(Prefs.onboardingDone, true);              // 09 PrefsStore
    await requestPermission(Permission.notification);         // 12, in context
    if (context.mounted) Navigator.of(context).pushReplacement(...);
  },
)
```
**Integration.** Persisting "seen" is the caller's job (Couple used a SharedPreferences flag). Gate the route with `guardRedirect(onboardingDone: ...)` (07).
**Edge cases.** Skip fades out on the last slide, and the page indicator has a "Page n of m" semantic label.
**Tests.** Next → Get started calls `onFinish`; Skip calls `onFinish`.

## AuthFormScreen

**Purpose.** A complete email and password sign-in / sign-up screen.
- Validated fields (`Validators`), autofill hints, and a show/hide password toggle
- On sign-up: a name field (`askForName`), a live `PasswordChecklist`, and the rules enforced on submit
- On sign-in: a "Forgot password?" link
- An inline error box (a live region), a loading button that blocks double submits, and the keyboard's Done key submitting
- An "or" divider with your `socialButtons`, a mode-switch link, and a `footer` slot (e.g. `ConsentCheckbox`)

**Inputs → outputs.** `onSubmit(AuthFormData(mode, email (trimmed), password, name?))`. The screen performs no network calls: `isLoading` and `errorText` come from the caller.
```dart
final authAction = NotifierProvider.autoDispose<ActionController, AsyncValue<void>>(ActionController.new);
...
final action = ref.watch(authAction);
AuthFormScreen(
  mode: mode,
  isLoading: action.isLoading,
  errorText: action.hasError ? AppException.from(action.error!).message : null,
  onSubmit: (d) => ref.read(authAction.notifier).run(() => d.mode == AuthMode.signIn
      ? auth.signIn(email: d.email, password: d.password)
      : auth.signUp(email: d.email, password: d.password, name: d.name)),
  socialButtons: [OutlinedButton.icon(onPressed: auth.signInWithApple, icon: const Icon(Icons.apple), label: const Text('Continue with Apple'))],
  onSwitchMode: toggleMode,
  onForgotPassword: openReset,
)
```
**Architectural reasoning.** In StudyBuddies and Cookly every auth screen (400+ lines each) held its own request state, and StudyBuddies needed an `AuthAction` enum just to stop one button's spinner lighting another's. Keeping the screen stateless about requests and pairing it with one `ActionController` per action removes that whole class of bug.
**Limitations.** No "confirm password" field (add one with `Validators.matches`). The layout is fixed: for a radically different design, copy the file.
**Tests.** Validation blocks submit, trimmed submit, password rules enforced on sign-up, loading blocks Done-key submit, social buttons and mode switch.

## MaxWidthFrame / MaxWidthSliver / responsive helpers

**Purpose.** Keeps phone layouts readable on tablets and desktop by centring content in a capped column. `context.isTablet` uses the shortest side (≥ 600), so a phone in landscape stays a phone. `adaptiveColumnCount(width, minCellWidth: 180)` picks grid columns.
**How it works.** `Align(heightFactor: 1)` + `ConstrainedBox(maxWidth)`. The `heightFactor: 1` matters: without it, inside loose-but-bounded slots like `Scaffold.bottomNavigationBar` the frame expands to the full height. StudyBuddies hit this bug, and the test checks a 64px nav bar stays 64px.
**Changed from the source.** The `flutter_screenutil` re-scaling for tablets was removed. Without screenutil it is unnecessary.

**Folder tests: 10** (`templates_test.dart`).

---

## Phase 2 additions

Every template below takes plain data and callbacks — no repository, provider or router inside — so it fits any state management. Tests: `test/06_screen_templates/new_screens_test.dart` and `responsive_layout_test.dart`.

| File | Screen | Typical use |
|---|---|---|
| `responsive_layout.dart` | `WindowSize`, `windowSizeFor`, `ResponsiveBuilder`, `ResponsiveGrid`, `gridColumnsFor` | phone / tablet / desktop layouts (Material 3 breakpoints 600 / 840) |
| `otp_screen.dart` | `OtpVerificationScreen` | email/SMS code step of sign-up or 2FA |
| `dashboard_template.dart` | `DashboardTemplate`, `DashboardSection` | home screens: greeting, stat grid, highlight card, sections, pull-to-refresh |
| `search_filter_bar.dart` | `SearchFilterBar<T>` | search box + filter chips + sort sheet bound to a `ListQuery` (08) |
| `crud_list_screen.dart` | `CrudListScreen<T>` | any "list of my things": search, filters, sort, FAB, swipe-delete with Undo, empty/error/no-match states |
| `list_detail_scaffold.dart` | `ListDetailScaffold<T>` | master–detail: pushes a page on phones, side by side from 840 px |
| `agenda_calendar.dart` | `AgendaCalendar<T>` | month grid with event dots + the selected day's agenda |
| `analytics_template.dart` | `AnalyticsTemplate`, `AnalyticsSnapshot` | stats screen with a period switcher, KPIs, trend line, breakdown donut, insight cards |
| `profile_template.dart` | `ProfileTemplate`, `ProfileAvatar`, `ProfileStat`, `initialsOf` | user / pet / team profile |
| `settings_template.dart` | `SettingsTemplate`, `SettingsGroup`, `SettingsToggle`, `SettingsChoice<T>`, `SettingsLink`, `SettingsAction` | settings screens |

### ResponsiveBuilder / ResponsiveGrid
**Purpose.** `ResponsiveBuilder(compact:, medium:, expanded:)` picks a layout from the *available width* (a `LayoutBuilder`, so it also works inside a split pane); missing builders fall back to the next smaller one. `ResponsiveGrid(minItemWidth: 160)` fills rows with equal-width, equal-height cells (`gridColumnsFor` does the maths, unit-tested).

### OtpVerificationScreen
```dart
OtpVerificationScreen(
  destination: email,
  onVerify: (code) => auth.verifyOtp(email: email, token: code),   // throw on a wrong code
  onResend: () => auth.sendOtp(email),
)
```
**How it works.** `PinCodeField` + `Shake` on failure + a `CountdownController` (08) that disables "Resend code in 0:42" until the cooldown ends. Any exception from `onVerify` shows `errorMessage` and clears the boxes.

### CrudListScreen
```dart
CrudListScreen<Task>(
  title: 'Tasks',
  items: ref.watch(tasksProvider),                       // AsyncValue<List<Task>>
  idOf: (t) => t.id, titleOf: (t) => t.title,
  searchableText: (t) => '${t.title} ${t.notes}',
  filters: [FilterOption('open', 'Open', (t) => !t.done)],
  sorts: [SortOption('due', 'Due date', (a, b) => a.due.compareTo(b.due))],
  onAdd: openEditor, onTap: openDetail,
  onDelete: (t) => ref.read(tasksProvider.notifier).delete(t.id),
  onRestore: (t) => ref.read(tasksProvider.notifier).save(t),
)
```
**How it works.** `SearchFilterBar` + `applyListQuery` (08) for filtering and sorting; deletion uses `SwipeActionTile`, then a snackbar 'Deleted "x"' with Undo calling `onRestore`. "No matches" (with a Clear button) is distinguished from "nothing yet".
**Limitations.** Loads the whole list (pair with `PaginationController` for huge lists); one swipe action.
**Gotcha.** The error state's "Try again" button and pull-to-refresh only appear when you pass `onRefresh` (e.g. `() => ref.read(provider.notifier).reload()`); without it the error is shown with no way to retry. Found while building the expense mini-app.

### The other templates
* `ListDetailScaffold` — `tileBuilder(context, item, selected, open)` + `detailBuilder`; below `breakpoint` (840) `open` pushes a page, above it the detail pane updates in place ("Select an item" when empty).
* `AgendaCalendar` — `CalendarGrid` with `markerCount` + the day's events sorted by time under a "Today · 2 items" header.
* `AnalyticsTemplate` — one `AnalyticsSnapshot` per period; feed it `trends.dart` / `insights.dart` (13) for the numbers and sentences.
* `ProfileTemplate` — avatar (image or initials), stats row, "Edit profile", free sections.
* `SettingsTemplate` — sealed `SettingsItem` types; `SettingsChoice<T>.choose()` opens a typed picker sheet. **Bug fixed during testing:** choosing a value crashed with a runtime type error ("`(String) => void` is not a subtype of `(dynamic) => void`") because the generic callback passed through a non-generic row; the picker logic now lives in the generic item.

**Limitations.** Templates own their `Scaffold`; inside a `TabShell` tab, that is what you want. They are layouts, not flows — navigation stays in your router.

**Riverpod scope.** Keep one `ProviderScope` above `MaterialApp`. A `ProviderScope` placed inside a screen is invisible to routes that screen pushes (sheets, `ListDetailScaffold` detail pages on phones), because pushed routes live under the Navigator — the volunteer mini-app crashed with "No ProviderScope found" until its nested scope was removed.
