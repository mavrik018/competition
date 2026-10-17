# 01 · Design system

Tokens, colours, type and a complete `ThemeData`. Every other folder reads its colours from `Theme.of(context)`, so changing the palette here re-skins the whole toolkit.

| File | Component | Source |
|---|---|---|
| `app_tokens.dart` | `Gap`, `Radii`, `Insets`, `Motion`, `AppShadows` | Cookly, TaskFlow |
| `app_palette.dart` | `AppPalette`, `SemanticColors` | StudyBuddies, Cookly, Couple, TaskFlow |
| `app_typography.dart` | `AppTypography` | StudyBuddies |
| `app_theme.dart` | `AppTheme.build` | Cookly, StudyBuddies |
| `theme_mode_controller.dart` | `ThemeModeController`, `themeModeProvider` | StudyBuddies |

**Dependencies:** Flutter only. `theme_mode_controller.dart` also needs `flutter_riverpod` and `shared_preferences`.

## Quick start

```dart
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    theme: AppTheme.build(AppPalette.studyBlue, Brightness.light),
    darkTheme: AppTheme.build(AppPalette.studyBlue, Brightness.dark),
    themeMode: ref.watch(themeModeProvider),
    home: const HomePage(),
  );
}
```

For your own brand, use `AppPalette(primary: Color(0xFF...), secondary: ..., tertiary: ...)`.

---

## `app_tokens.dart`

**What it does.** Named constants for spacing (`Gap.xs`…`Gap.xxl`, `Gap.gutter`), corner radii (`Radii.sm`…`Radii.pill`), standard paddings (`Insets.page`, `.card`, `.sheet`, `.listRow`), animation timing (`Motion.press/short/medium/long`, `Motion.standard`, `Motion.emphasized`) and tinted shadows (`AppShadows.soft/lifted/glow`).

**How it works.** Plain `static const` values. Shadows are functions of a tint colour: a low-opacity brand-tinted shadow with a large blur reads softer than a grey one (Cookly's DESIGN.md rule).

**Changed from the source.** Cookly's scale was out of order (`sm` = 12 was bigger than `base` = 8) and went through `flutter_screenutil` (`.r`). Here the steps increase strictly and are logical pixels.

**Limitations.** No responsive scaling. If your design needs it, multiply at the call site or adopt `flutter_screenutil` app-wide.

## `app_palette.dart`

**What it does.** `AppPalette` turns 1–4 seed colours into a light and a dark `ColorScheme`, plus a `SemanticColors` theme extension (`success`, `warning`, `info`) for the status colours Material lacks. It ships one preset per source app: `studyBlue`, `kitchenWarm`, `coupleNavy`, `taskIndigo`.

**How it works.** `ColorScheme.fromSeed` derives every tonal role. In light mode your exact brand colours are pinned as `primary`/`secondary`/`tertiary`. In dark mode the seeded tones are used, because a dark brand colour is unreadable on a dark surface (tested). In dark mode the semantic colours are lerped 35% toward white.

**Inputs → outputs.** `AppPalette` → `scheme(Brightness)` → `ColorScheme`, and `semantic(Brightness)` → `SemanticColors`. In widgets, call `SemanticColors.of(context)`.

**Edge cases.** `SemanticColors.of` falls back to defaults when the theme was not built by `AppTheme`, so components never crash on a plain `ThemeData` (tested).

## `app_typography.dart`

**What it does.** `AppTypography.textTheme(color:, fontFamily:)` maps the Apple HIG ramp onto Material's 15 `TextTheme` slots: `displayMedium` 34 (Large Title), `titleMedium` 17 (navigation title), `bodyLarge` 17, `bodyMedium` 15, `labelSmall` 11 (the floor). `AppTypography.tabular(style)` adds tabular figures so timers don't jitter.

**Why.** StudyBuddies found 231 ad-hoc `fontSize` overrides that made the same element render at up to ten sizes. One ramp, one size per role, fixed that.

**Changed from the source.** `google_fonts` was removed. Pass `fontFamily` for a font declared in your pubspec, or leave it null for the platform font. Tabular figures replace the undeclared `'Roboto Mono'` family the source asked for.

## `app_theme.dart`

**What it does.** `AppTheme.build(palette, brightness, {fontFamily, pageTransitionsTheme})` returns a complete Material 3 `ThemeData`: flat app bars, borderless cards, 52px buttons, filled inputs whose border appears on focus, pill chips, floating snackbars, rounded sheets and dialogs, a navigation bar, and the `SemanticColors` extension.

**How it works.** Every component theme derives its colours from the scheme, so one function covers both modes. To use the fade-through route animation, pass `fadeThroughTransitions` from `07_navigation/page_transitions.dart`.

**Tests.** Both brightnesses produce a complete theme, and the font family and transitions pass through.

## `theme_mode_controller.dart`

**What it does.** A Riverpod `Notifier<ThemeMode>` that persists light / dark / system in SharedPreferences. It offers `setMode(mode)` and `toggle(platformBrightness)`.

**How it works.** `build()` returns `ThemeMode.system` and starts an async read of the saved value. A `_changedByUser` flag stops a slow read from overwriting a choice the user made in the meantime (tested). Storage failures are logged, never thrown, so the mode still applies for the session.

**Limitations.** The saved mode arrives a microtask after launch. If the saved mode differs from the system mode, the very first frame can show the system theme. To avoid that, read the preference before `runApp` and override the provider.

**Tests (16 in the folder).** Load, persist, the race guard, toggling from system, and parsing unknown values.
