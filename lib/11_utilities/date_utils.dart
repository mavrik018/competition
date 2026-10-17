/// Calendar arithmetic and friendly date labels, with no `intl` dependency.
///
/// Source: Cookly `meal_planner/domain/week_math.dart` (Monday-start weeks,
/// ISO week numbers, week labels), TaskFlow `core/utils/date_formatter.dart`
/// (Today / Tomorrow / weekday labels), Cookly `OfflineBanner._relative`
/// ("12m ago") and Couple `milestone_calculator.dart` (adding years without
/// overflowing Feb 29 into March).
///
/// Everything builds dates from year/month/day rather than adding
/// `Duration(days: n)`, because a day is not always 24 hours: across a
/// daylight-saving change, `DateTime(2026, 3, 29).add(Duration(days: 1))` can
/// land at 23:00 on the same day in local time.
///
/// For localised month and weekday names, use `intl`'s `DateFormat` instead
/// of the English tables here.
library;

const monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];
const weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Midnight at the start of [moment]'s calendar day, in the same time zone
/// kind (local or UTC) as [moment].
DateTime dateOnly(DateTime moment) => moment.isUtc
    ? DateTime.utc(moment.year, moment.month, moment.day)
    : DateTime(moment.year, moment.month, moment.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// [days] calendar days after [date] (negative for before), DST-safe.
DateTime addDays(DateTime date, int days) => date.isUtc
    ? DateTime.utc(date.year, date.month, date.day + days)
    : DateTime(date.year, date.month, date.day + days);

/// Whole calendar days from [from] to [to] (negative if [to] is earlier).
int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

int daysInMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;

/// The first day of [moment]'s week. Weeks start on Monday by default.
DateTime startOfWeek(DateTime moment, {int firstWeekday = DateTime.monday}) {
  final offset = (moment.weekday - firstWeekday) % 7;
  return addDays(dateOnly(moment), -offset);
}

/// ISO-8601 week number (1–53): the week containing the year's first
/// Thursday is week 1.
int isoWeekNumber(DateTime date) {
  final day = DateTime.utc(date.year, date.month, date.day);
  final thursday = day.add(Duration(days: DateTime.thursday - day.weekday));
  final firstThursday = DateTime.utc(thursday.year, 1, 4);
  final firstWeekThursday = firstThursday.add(
    Duration(days: DateTime.thursday - firstThursday.weekday),
  );
  return 1 + thursday.difference(firstWeekThursday).inDays ~/ 7;
}

/// Adds whole years, clamping Feb 29 to Feb 28 in non-leap years instead of
/// rolling over into March (what `DateTime(y + n, 2, 29)` does).
DateTime addYears(DateTime date, int years) {
  final year = date.year + years;
  final day = date.day.clamp(1, daysInMonth(year, date.month));
  return DateTime(year, date.month, day, date.hour, date.minute, date.second);
}

/// "Sep 14"
String formatShortDate(DateTime date) =>
    '${monthNames[date.month - 1].substring(0, 3)} ${date.day}';

/// "September 14, 2026"
String formatLongDate(DateTime date) =>
    '${monthNames[date.month - 1]} ${date.day}, ${date.year}';

/// "9:05 AM" (or "09:05" when [use24Hour]).
String formatTime(DateTime time, {bool use24Hour = false}) {
  final minutes = time.minute.toString().padLeft(2, '0');
  if (use24Hour) return '${time.hour.toString().padLeft(2, '0')}:$minutes';
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  return '$hour:$minutes ${time.hour < 12 ? 'AM' : 'PM'}';
}

/// "Today", "Tomorrow", "Yesterday", a weekday name within the coming week,
/// otherwise "Sep 14" (or "Sep 14, 2027" in another year).
String relativeDayLabel(DateTime date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final diff = daysBetween(today, date);
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  if (diff > 1 && diff < 7) return weekdayNames[date.weekday - 1];
  return date.year == today.year
      ? formatShortDate(date)
      : '${formatShortDate(date)}, ${date.year}';
}

/// "just now", "5m ago", "3h ago", "1 day ago", "4 days ago".
String timeAgo(DateTime when, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(when);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return diff.inDays == 1 ? '1 day ago' : '${diff.inDays} days ago';
}

/// "Sep 14 — Sep 20, 2026" for the week starting [weekStart].
String weekRangeLabel(DateTime weekStart) {
  final end = addDays(weekStart, 6);
  return '${formatShortDate(weekStart)} — ${formatShortDate(end)}, ${end.year}';
}
