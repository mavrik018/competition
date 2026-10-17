# 05 · Forms

Building blocks for settings screens and data-entry forms.

| File | Component | Source |
|---|---|---|
| `form_section.dart` | `FormSection`, `FormRowTile`, `ValuePill`, `TextFieldRow` | StudyBuddies / Cookly `ios_ui.dart` |
| `segmented_control.dart` | `SegmentedControl<T>` | StudyBuddies |
| `number_stepper.dart` | `NumberStepper` | StudyBuddies / Cookly |
| `calendar_grid.dart` | `CalendarGrid`, `DateField`, `showDatePickerSheet`, `monthCells`, `weekdayHeadings` | StudyBuddies / Cookly |
| `validators.dart` | `Validators` | **new** |
| `password_checklist.dart` | `PasswordRule`, `passwordMeetsAll`, `PasswordChecklist` | StudyBuddies |
| `consent_checkbox.dart` | `ConsentCheckbox`, `ConsentLink` | StudyBuddies |
| `markdown_editing_controller.dart` | `MarkdownEditingController` | TaskFlow |

**Dependencies:** Flutter only (the Markdown controller also uses `11_utilities/markdown_parser.dart`).

---

## FormSection / FormRowTile / ValuePill / TextFieldRow

**Purpose.** An iOS Settings-style grouped card: a small-caps header, rows separated by inset hairlines, and a footnote.
```dart
FormSection(header: 'Account', footer: 'Shown on your profile.', children: [
  FormRowTile(label: 'Plan', value: 'Pro'),                                 // value as a pill
  FormRowTile(label: 'Email', value: email, valueAsPill: false),            // plain value
  FormRowTile(label: 'Reminders', trailing: Switch(value: on, onChanged: set)),
  FormRowTile(label: 'Privacy policy', showChevron: true, onTap: openPrivacy),
  FormRowTile(label: 'Delete account', destructive: true, onTap: confirmDelete),
  TextFieldRow(controller: name, label: 'Name', placeholder: 'Your name'),
])
```
**How it works.** The card is a `Material`, so rows use `InkWell` ripples. Dividers are inserted between children, not after the last one (tested).
**Limitations.** `TextFieldRow` has no validator. Use a `TextFormField` inside a row when you need one.

## SegmentedControl

**Purpose.** A filled iOS-style switch between 2–5 options. Material's `SegmentedButton` is the outlined Android equivalent.
**How it works.** A `Map<T, String>`, whose literal order is preserved. The selected segment gets a white (or dark-grey) thumb with a soft shadow. Re-tapping the selected segment does nothing (tested). Each segment carries button + selected semantics.

## NumberStepper

**Purpose.** − / + for small integers, with `min`, `max` and `step`. A button disables at the bound.
**Accessibility.** Exposes `value`, `increasedValue` and `decreasedValue`, plus `onIncrease`/`onDecrease` actions, so screen readers can adjust it (tested).

## CalendarGrid / DateField / showDatePickerSheet

**Purpose.** A pageable month grid with an optional per-day background (`dayColor`, e.g. a streak heatmap), `firstDate`/`lastDate` limits and a configurable week start, offered three ways: standalone, as an inline expanding form row (`DateField`), or as a modal sheet.
```dart
DateField(label: 'Due', value: due, onChanged: setDue, firstDate: DateTime.now());
final picked = await showDatePickerSheet(context, initialDate: DateTime.now(),
                                         firstWeekday: DateTime.monday);
```
**How it works.** `monthCells(month, firstWeekday:)` returns leading `null` blanks followed by `DateTime(y, m, d)` cells, built from y/m/d so daylight saving can never shift a day. The leading-blank count is `(firstDay.weekday − firstWeekday) % 7`.
**Changed from the source.** The source was Sunday-only and used `intl` for the month header. English month names are built in. For localisation, swap in `intl`'s `DateFormat`.
**Tests.** Padding for Sunday and Monday starts, a leap February, disabled days, month paging, DateField collapsing after a pick, the sheet's result.

## Validators

**Purpose.** Composable `FormField` validators that return null when valid: `required`, `email`, `minLength`, `maxLength`, `matches` (confirm password), `integer(min,max)`, `compose([...])` (first failure wins).
**Design choice.** Format validators (`email`, `integer`) let empty input pass, so "optional but well-formed" fields work. Combine with `required` for mandatory fields.
**Limitation.** The email check is pragmatic (`x@y.tld`, no spaces), not RFC 5322.

## PasswordRule / PasswordChecklist

**Purpose.** A live checklist under a sign-up password field. Each rule ticks green as it is met. `passwordMeetsAll(text, rules)` gates the submit button.
**Changed from the source.** Rules are data (`PasswordRule(label, test)`) instead of hard-coded. The defaults are StudyBuddies' (8+ characters, upper, lower, number or symbol). Each row's semantics announce "met" or "not met".

## ConsentCheckbox

**Purpose.** "I agree to the Terms of Use and Privacy Policy." — a rounded checkbox whose sentence has tappable links. The list is joined as "A, B and C".
**How it works.** `TapGestureRecognizer`s live in `State` and are disposed, and rebuilt when the `links` list changes. The checkbox and the sentence are separate semantics nodes, so screen readers can still activate each link. `onChanged: null` disables the row.

## MarkdownEditingController

**Purpose.** A `TextEditingController` that styles inline Markdown while the user types. Text between markers turns bold, italic, struck through or monospace, and the markers stay visible but faded.
**How it works.** `buildTextSpan` runs the shared `parseInline` and re-emits the markers, so the span text is exactly the controller text and cursor positions stay correct (tested: `toPlainText() == text`). While an IME is composing (CJK input) it falls back to the default rendering.

**Folder tests: 19** (`forms_test.dart`).

---

## Phase 2 additions

### DynamicForm (`dynamic_form.dart`)
**Purpose.** A whole form from a list of field specs — or from JSON (remote config, a Supabase table, an admin screen). Covers registration forms, surveys, intake/inspection checklists and "report an issue" forms without writing a screen per form.

| Spec | Renders | Value type |
|---|---|---|
| `TextFieldSpec(kind: TextKind.text / multiline / email / phone / url / password)` | `AppTextField` / `PasswordField` with the matching keyboard + validator | `String` |
| `NumberFieldSpec(min, max, decimal, suffix)` | numeric field (accepts `,` decimals) | `num` |
| `ChoiceFieldSpec(options: [FieldOption(value, label)], multiple)` | dropdown (single) / chips (multiple) | `String` / `List<String>` |
| `SwitchFieldSpec` | switch | `bool` (default false) |
| `DateFieldSpec(firstDate, lastDate)` | date picker field | `DateTime` |
| `SliderFieldSpec(min, max, divisions)` | slider | `double` (default min) |

```dart
DynamicForm(
  fields: [for (final f in jsonList) FieldSpec.fromJson(f)],   // type: text|number|choice|switch|date|slider
  initialValues: existing,
  onSubmit: (values) => repo.save(Report.fromMap(values)),     // FutureOr — the button shows a spinner
)
```
**How it works.** A sealed `FieldSpec` hierarchy; each spec knows its widget and validators. `DynamicFormState.submit()` / `.values` are public for forms whose button lives elsewhere (`showSubmitButton: false` + a `GlobalKey<DynamicFormState>`).
**Limitations.** No conditional fields ("show B when A is yes") and no file fields — combine with `MediaPicker` (12) for uploads.
**Tests.** `test/05_forms/dynamic_form_test.dart` (JSON parsing of every type, required/format validation blocks submit, typed values, prefill).

### New validators (`validators.dart`)
`Validators.number({min, max})` (accepts `3,5`), `Validators.phone()` (7–15 digits after removing spaces, dashes, brackets and `+`), `Validators.url()` (http/https with a dotted host), `Validators.pattern(regex, message)` (must match the *whole* input). Tested in `dynamic_form_test.dart`.

### CalendarGrid — event markers
`markerCount: (day) => eventsOn(day).length` draws 0–3 dots under a day, and the day's spoken label gains ", has events". Tested in `test/06_screen_templates/responsive_layout_test.dart`.
