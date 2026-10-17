# 12 · Common features

Feature-sized building blocks that recur across apps.

| File | Component | Source | Deps |
|---|---|---|---|
| `reminder_scheduler.dart` | `ReminderScheduler`, `Reminder`, `notificationIdFor`, `toZoned` | Couple `reminder_scheduler.dart` | flutter_local_notifications, timezone, flutter_timezone |
| `permission_helper.dart` | `requestPermission`, `checkPermission`, `outcomeFor`, `PermissionOutcome` | Couple `permission_service.dart` | permission_handler |
| `pomodoro_controller.dart` | `PomodoroController`, `FocusPhase` | StudyBuddies focus timer | `08/countdown_controller.dart` |
| `quiz_session.dart` | `QuizSession`, `QuizQuestion` | StudyBuddies `quiz_session_store.dart` + quiz screens | — |

---

## ReminderScheduler

**Purpose.** Local notifications at a time: schedule, cancel, re-sync all of them, and route a tap back into the app, including a tap that launched the app from closed.
```dart
final reminders = ReminderScheduler(onTap: deepLinks.handle);     // 07 DeepLinkQueue
await reminders.initialize();                                      // once, after runApp
// later, in context:
if (await reminders.requestPermission()) {
  await reminders.schedule(Reminder(key: task.id, title: task.title, body: 'Due in 30 minutes',
      at: task.due.subtract(const Duration(minutes: 30)), payload: '/task/${task.id}'));
}
await reminders.syncAll(allUpcomingReminders);   // cancel all, then schedule the future ones
```
**How it works.** The device's IANA zone comes from `flutter_timezone`, and times are converted with `toZoned`, which keeps the wall-clock reading so 09:00 stays 09:00 across a DST change (tested in Europe/London summer and winter). Past times are skipped. It uses the inexact Android schedule mode, which needs no "alarms & reminders" permission on Android 14+.
**Improvements over the sources.**
- Couple derived notification ids from `String.hashCode`, which Dart does not guarantee to be stable between runs, so a reminder scheduled by one launch might not be cancellable by the next. `notificationIdFor` is a fixed FNV-1a hash, computed in a way that is also exact on the web.
- TaskFlow guessed the zone from abbreviation and UTC-offset tables ("PKT" → Karachi), which picks the wrong zone for many users. That approach was dropped.

**Limitations.** A local notification fires only on the device that scheduled it; other users need server push. Platform setup (Android manifest receivers and permissions, iOS AppDelegate) follows the flutter_local_notifications README.
**Tests.** The id is stable, 31-bit and well spread; zone conversion. Scheduling itself needs a device.

## Permission helper

```dart
switch (await requestPermission(Permission.camera)) {
  case PermissionOutcome.granted: openCamera();
  case PermissionOutcome.denied:  break;   // they said no; ask again later, in context
  case PermissionOutcome.blocked:          // permanently denied or restricted
    if (await showAppConfirm(context, title: 'Camera is off', confirmLabel: 'Open Settings')) {
      await openAppSettings();
    }
}
```
**How it works.** It returns early when already granted and never re-prompts a blocked permission, which the OS would silently ignore. `outcomeFor` maps all six platform statuses: `limited` and `provisional` count as granted, `permanentlyDenied` and `restricted` as blocked.
**Changed from the source.** Couple returned a `bool`, which hid the "blocked, send them to Settings" case.

## PomodoroController

**Purpose.** Focus blocks alternating with short breaks, and a long break every N rounds.
```dart
final pomodoro = PomodoroController(focusMinutes: 25, autoStartNext: false,
    onPhaseComplete: (phase, minutes) { if (phase == FocusPhase.focus) logStudySession(minutes); });
ListenableBuilder(listenable: pomodoro, builder: (_, _) =>
    RadialGauge(value: pomodoro.timer.progress, size: 220, child: Text(pomodoro.timer.formatted)));
```
**How it works.** Each phase is a `CountdownController` (08), so the timer is wall-clock accurate across app suspension. Only finished **focus** phases count as rounds, and `skip()` doesn't count. Changing the focus length is ignored while running, so the countdown can't jump under the user (StudyBuddies' rule). Completion is reported through a callback rather than a dialog shown from state code.
**Tests.** The phase sequence focus → short → focus → long, the length lock while running, skip, waiting without auto-start.

## QuizSession

**Purpose.** An immutable multiple-choice quiz in progress (current question, answers, score, mistakes, elapsed time) that serialises to JSON so a quiz can be resumed after the app closes.
```dart
var s = QuizSession(questions: questions, seed: DateTime.now().millisecond);
s = s.answer(option);  final right = s.isCorrect(s.currentIndex);  s = s.next();
if (s.isComplete) showResults(score: s.score, total: s.total, review: s.mistakes);
await prefs.setJson('quiz_in_progress', s.toJson());     // 09 PrefsStore
```
**How it works.** Every operation returns a new session. `optionsFor(i)` shuffles the options with a seed and a hand-written prompt hash, so the order is identical after resuming (tested). `String.hashCode` would not be stable across runs.
**Changed from the source.** StudyBuddies coupled this to SharedPreferences and its `Quiz` model. Here it is a plain value; persist it with any store.

**Folder tests: 10** (`common_features_test.dart`).

---

## Phase 2 additions — device features

Pattern for everything that needs hardware, permissions or a platform SDK: an **interface**, a **device implementation**, and a clearly labelled **Fake** for tests and demos. Fakes are *not* production functionality — they never touch the camera, GPS or share sheet. Override the Riverpod provider in tests or demo builds.

| File | API | Device implementation | Fake | Platforms |
|---|---|---|---|---|
| `file_rules.dart` | `FileRules(maxBytes, allowedExtensions, checkContent).check`, `sniffFileType`, `mimeTypeFor` | pure Dart | — | all |
| `media_picker.dart` | `MediaPicker.pickImage / pickFiles` → `PickedMedia(name, bytes, path)` | `DeviceMediaPicker` (image_picker + file_picker) | `FakeMediaPicker` | Android, iOS, web, desktop |
| `qr_code.dart` | `QrPayload` types (`QrUrl`, `QrWifi`, `QrEmail`, `QrPhone`, `QrSms`, `QrGeo`, `QrContact`, `QrAppLink`, `QrText`), `parseQr`, `QrCodeView`, `QrScannerView` | mobile_scanner, pretty_qr_code | parse/encode are pure | scanning: Android, iOS, web, macOS |
| `ocr.dart` | `TextRecognizerService.recognizeFile(path)`, rule-based `extractFromText` (amounts, total, dates, emails, phones, URLs) | `MlKitTextRecognizer` (on-device ML Kit) | `FakeTextRecognizer` | ML Kit: Android, iOS only |
| `location_service.dart` | `LocationService`, `GeoPoint`, `Geofence`, `nearestPlaces` | `GeolocatorLocationService` (permission flow, last-known fallback on timeout) | `FakeLocationService(route, problem)` | Android, iOS, web, desktop |
| `share_service.dart` | `ShareService` (text and files) | `SystemShareService` (share_plus) | `FakeShareService` | all |
| `data_export.dart` | `toCsv`, `parseCsv`, `csvToMaps`, `utf8Bytes(bom:)`, `toPrettyJson`, `buildPdfReport` | pure Dart + `pdf` | — | all |
| `reminder_scheduler.dart` | **new:** `scheduleDaily(key, title, body, hour, minute)`, `nextDailyOccurrence` | flutter_local_notifications | — | Android, iOS, macOS |

**Platform setup** (only for the device implementations):
* **Camera / gallery (image_picker) and QR scanning (mobile_scanner):** iOS `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` in Info.plist; Android requests the camera permission at runtime.
* **OCR (google_mlkit_text_recognition):** Android `minSdkVersion` 21+, iOS 15.5+ and `pod install`; on-device, no key, no network. Unsupported on web/desktop — gate it with `defaultTargetPlatform`.
* **Location (geolocator):** Android `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` in the manifest; iOS `NSLocationWhenInUseUsageDescription`.
* **Share (share_plus):** nothing. On iPad pass a share origin when sharing from a button.
* **PDF (pdf):** nothing; pass a TTF `font` for non-Latin text.
* **Reminders (flutter_local_notifications):** Android apps must enable core library desugaring in `android/app/build.gradle.kts` (`isCoreLibraryDesugaringEnabled = true` + `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`), or the APK build fails at `checkDebugAarMetadata`. `tool/create_app.dart` and `tool/add_component.dart` add this automatically whenever the reminders file is copied into an app.

**Rule-based vs ML here.** OCR *recognition* is on-device machine learning (ML Kit). Everything after it — finding the total, dates, phone numbers — is rule-based regex in `extractFromText`, tested on sample receipt text.

**Limitations.** `extractFromText` handles common US/EU receipt formats only; `QrScannerView` needs a real camera; `buildPdfReport` uses the built-in Helvetica (Latin only) unless you pass a font.
**Tests.** `test/12_common_features/device_features_test.dart` (file sniffing, QR encode↔parse round trips, `QrCodeView` renders, OCR extraction on sample receipts, geofences, fakes, CSV round trips, a multi-page PDF, `nextDailyOccurrence`). The device implementations themselves are 🔶 — not unit-testable without a camera, GPS or share sheet.
