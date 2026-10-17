/// Local reminders: schedule a notification for a time, cancel it, re-sync
/// all of them, and route a tap back into the app — including a tap that
/// launched the app from closed.
///
/// Source: Couple `core/notifications/reminder_scheduler.dart` (the
/// cleaner of two implementations): device time-zone lookup through
/// `flutter_timezone` for DST-correct scheduling, skipping times already in
/// the past, "cancel all and reschedule" as the sync strategy, and handling
/// the cold-start launch payload. TaskFlow's version guessed the zone from
/// abbreviation and UTC-offset tables, which picks the wrong zone for half
/// the world; it was not used. Changed: Couple derived notification ids from
/// `String.hashCode`, which Dart does not guarantee to be stable between
/// runs — and a reminder scheduled in one run must be cancellable in the
/// next. [notificationIdFor] uses a fixed FNV-1a hash instead.
///
/// Limitation (from the source, still true): a local notification fires
/// only on the device that scheduled it. Reminders for other users need
/// server push.
///
/// ```dart
/// final reminders = ReminderScheduler(onTap: (payload) => links.handle(payload));
/// await reminders.initialize();               // once, after runApp
/// await reminders.requestPermission();        // in context, not at launch
/// await reminders.schedule(Reminder(
///   key: task.id, title: task.title, body: 'Due in 30 minutes',
///   at: task.due.subtract(const Duration(minutes: 30)), payload: '/task/${task.id}',
/// ));
/// ```
///
/// Platform setup (manifest permissions, iOS AppDelegate) follows the
/// `flutter_local_notifications` README.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

@immutable
class Reminder {
  const Reminder({
    required this.key,
    required this.title,
    required this.at,
    this.body,
    this.payload,
  });

  /// Your id for the thing being reminded about (task id, event id).
  final String key;
  final String title;
  final String? body;
  final DateTime at;

  /// Handed back to `onTap` — typically a deep-link path.
  final String? payload;
}

class ReminderScheduler {
  ReminderScheduler({
    this.onTap,
    this.channelId = 'reminders',
    this.channelName = 'Reminders',
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final void Function(String payload)? onTap;
  final String channelId;
  final String channelName;
  final FlutterLocalNotificationsPlugin _plugin;
  tz.Location _zone = tz.UTC;

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    try {
      final name = (await FlutterTimezone.getLocalTimezone()).identifier;
      _zone = tz.getLocation(name);
    } catch (error) {
      debugPrint(
        'ReminderScheduler: unknown device time zone, using UTC: $error',
      );
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permission is requested separately, in context.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) onTap?.call(payload);
      },
    );

    // A tap that launched the app from fully closed does not arrive through
    // the callback above.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if ((launch?.didNotificationLaunchApp ?? false) && payload != null) {
      onTap?.call(payload);
    }
  }

  /// Asks for notification permission (Android 13+, iOS). Returns whether it
  /// was granted.
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return true;
  }

  /// Schedules [reminder], replacing any earlier one with the same key.
  /// Times in the past are ignored. Returns whether it was scheduled.
  Future<bool> schedule(Reminder reminder) async {
    if (!reminder.at.isAfter(DateTime.now())) return false;
    await _plugin.zonedSchedule(
      id: notificationIdFor(reminder.key),
      title: reminder.title,
      body: reminder.body,
      scheduledDate: toZoned(reminder.at, _zone),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(channelId, channelName),
        iOS: const DarwinNotificationDetails(),
      ),
      // Inexact needs no special "alarms & reminders" permission on
      // Android 14+; a reminder a minute late is fine.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: reminder.payload,
    );
    return true;
  }

  /// Repeats every day at [hour]:[minute] local time (e.g. a study or
  /// medication reminder) until [cancel]led with the same [key].
  Future<void> scheduleDaily({
    required String key,
    required String title,
    String? body,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    await _plugin.zonedSchedule(
      id: notificationIdFor(key),
      title: title,
      body: body,
      scheduledDate: toZoned(
        nextDailyOccurrence(hour, minute, DateTime.now()),
        _zone,
      ),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(channelId, channelName),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // Repeat whenever the time of day matches.
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  Future<void> cancel(String key) => _plugin.cancel(id: notificationIdFor(key));

  /// Cancels everything and schedules [reminders] afresh — simple and
  /// correct for tens of reminders, and what a second device needs the
  /// first time it opens the app.
  Future<int> syncAll(Iterable<Reminder> reminders) async {
    await _plugin.cancelAll();
    var scheduled = 0;
    for (final reminder in reminders) {
      if (await schedule(reminder)) scheduled++;
    }
    return scheduled;
  }
}

/// A stable 31-bit notification id for [key] (FNV-1a). The same key gives
/// the same id in every run and on every platform.
int notificationIdFor(String key) {
  var hash = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    hash ^= unit;
    // × the FNV prime 0x01000193 (= 2^24 + 0x193), split so no intermediate
    // exceeds 2^53 — on the web, ints are doubles and would lose precision.
    hash = ((hash << 24) + hash * 0x193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

/// [local] (a wall-clock time on this device) as a time in [zone], keeping
/// the same wall-clock reading so "9:00" stays 9:00 across a DST change.
tz.TZDateTime toZoned(DateTime local, tz.Location zone) {
  final l = local.toLocal();
  return tz.TZDateTime(
    zone,
    l.year,
    l.month,
    l.day,
    l.hour,
    l.minute,
    l.second,
  );
}

/// The next moment the wall clock reads [hour]:[minute] — later today, or
/// tomorrow if that time has already passed (or is right now).
DateTime nextDailyOccurrence(int hour, int minute, DateTime now) {
  final today = DateTime(now.year, now.month, now.day, hour, minute);
  return today.isAfter(now)
      ? today
      : DateTime(now.year, now.month, now.day + 1, hour, minute);
}
