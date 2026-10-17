# 04 · Dialogs and sheets

iOS-shaped alerts and action sheets that work on every platform and follow the app theme.

| File | Component | Source |
|---|---|---|
| `alerts.dart` | `showAppAlert`, `showAppConfirm`, `showAppMessage`, `showTextPrompt`, `AlertAction`, `AlertTextField` | StudyBuddies `ios_ui.dart` (Cookly ported the same file) |
| `picker_sheet.dart` | `showPickerSheet<T>`, `PickerOption<T>`, `SheetGrabber` | StudyBuddies / Cookly |

**Dependencies:** Flutter only, plus `01_design_system/app_tokens.dart`.

**Why not `CupertinoAlertDialog`?** It looks like an iOS dialog dropped onto a non-iOS app, and it ignores the app theme. These keep the iOS structure (centred card, hairline dividers, pill-free text actions, action sheet with a separate Cancel) with the app's own colours.

---

## showAppAlert and friends

```dart
// Yes/no
final ok = await showAppConfirm(context, title: 'Delete note?', message: 'This cannot be undone.',
                                confirmLabel: 'Delete', destructive: true);

// Info
await showAppMessage(context, title: 'Saved to Files');

// Text input
final minutes = await showTextPrompt(context, title: 'Custom length', suffix: 'min',
                                     keyboardType: TextInputType.number);

// Anything else
final index = await showAppAlert(context, title: 'Export as', actions: const [
  AlertAction(label: 'PDF', style: AlertActionStyle.primary),
  AlertAction(label: 'Markdown'),
  AlertAction(label: 'Cancel'),
]);
```

**Inputs → outputs.** `showAppAlert` resolves to the tapped action's index, or `null` when dismissed by tapping outside. `showAppConfirm` resolves to `true` only when confirm is tapped. `showTextPrompt` resolves to the trimmed text, or `null` on cancel.

**How it works.**
- A `showGeneralDialog` with a fade and a spring-in scale from 92% (`easeOutBack`), like the native alert.
- Two short actions (≤ 14 characters each) sit side by side. Otherwise they stack (tested).
- `AlertAction.onPressed` runs **after** the dialog has been popped, so callbacks never use a stale dialog context (tested).
- `showTextPrompt` mirrors the text out through `onChanged` instead of owning a controller. In the source, a controller disposed when the future completed was still used by the closing animation ("TextEditingController was used after being disposed"). `AlertTextField` owns and disposes its own controller, and the test confirms no exception is thrown.

**Limitations.** No platform switch: the same look on Android and iOS. Content taller than 85% of the screen scrolls inside the card.

## showPickerSheet

**Purpose.** Replaces dropdowns and popup menus with a bottom action sheet: an optional title and message, rows with icon, subtitle and a destructive style, a tick on the current value, and a separate Cancel pill.
```dart
final sort = await showPickerSheet<SortOrder>(context, title: 'Sort by', selected: current, options: [
  const PickerOption(value: SortOrder.newest, label: 'Newest first', icon: Icons.schedule),
  const PickerOption(value: SortOrder.title, label: 'Title', subtitle: 'A to Z'),
]);
```
**How it works.** `showModalBottomSheet` with a transparent background. The card is a `Material` (not a decorated `Container`) so row ripples paint above the card colour. The list grows to 60% of the screen height and then scrolls, and the sheet is capped at 540px wide on tablets.
**Outputs.** The chosen value, or `null` on Cancel or dismiss.

## SheetGrabber
The 36×5 handle for the top of custom sheets. `AppTheme` already turns on `showDragHandle` for standard sheets.

**Folder tests: 11** (`dialogs_test.dart`).

---

## Phase 2 additions — `bottom_sheets.dart`

**`showAppBottomSheet<T>(context, builder:, title:, actions:, maxHeightFraction:, isDismissible:)`** — the general-purpose sheet: drag handle, optional title, scrollable body, a pinned action row (`actions` gets the *sheet's* context so `Navigator.pop(sheetContext, value)` returns a result), keyboard-aware padding and a 640 px max width on tablets.
```dart
final filter = await showAppBottomSheet<Filter>(
  context,
  title: 'Filters',
  builder: (_) => FilterForm(controller: c),
  actions: (sheet) => [AppButton(label: 'Apply', expand: true, onPressed: () => Navigator.pop(sheet, c.value))],
);
```
**Limitations.** One sheet height policy (content height up to `maxHeightFraction`). For pickers from a list use `showPickerSheet`.
**Tests.** `test/03_feedback/loading_overlay_test.dart` (title, content and actions; an action pops the sheet with a result).
