/// Smart scheduling: find free time between busy events, place tasks into
/// it by deadline and priority (respecting working hours and breaks), and
/// detect clashes.
///
/// **Rule-based, not AI.** A greedy algorithm: tasks are sorted by
/// deadline, then priority, and each gets the earliest free slot that fits
/// before its deadline. Fast, predictable and explainable; not guaranteed
/// optimal (that is a constraint-solver problem).
///
/// Suits: study planners (revision blocks before exams), auto-planning a
/// to-do list into the calendar, shift or appointment slotting, meeting
/// time finders ("first slot we're all free"), meal-prep or chore plans.
///
/// ```dart
/// final plan = scheduleTasks(
///   tasks: [
///     SchedulableTask(id: 'essay', duration: const Duration(hours: 2), deadline: friday, priority: 5),
///     SchedulableTask(id: 'reading', duration: const Duration(minutes: 45), priority: 2),
///   ],
///   busy: calendarEvents.map((e) => TimeSlot(e.start, e.end)).toList(),
///   from: DateTime.now(),
///   until: DateTime.now().add(const Duration(days: 7)),
///   hours: const WorkingHours(startHour: 9, endHour: 18, days: {1, 2, 3, 4, 5}),
/// );
/// plan.placed;      // [(task, slot), …]
/// plan.unplaced;    // tasks that could not fit, with reasons
/// ```
library;

class TimeSlot {
  TimeSlot(this.start, this.end) : assert(!end.isBefore(start));

  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);

  bool overlaps(TimeSlot other) =>
      start.isBefore(other.end) && other.start.isBefore(end);

  @override
  bool operator ==(Object other) =>
      other is TimeSlot && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'TimeSlot($start → $end)';
}

class WorkingHours {
  const WorkingHours({
    this.startHour = 9,
    this.endHour = 17,
    this.days = const {1, 2, 3, 4, 5, 6, 7},
  }) : assert(startHour < endHour);

  final int startHour;
  final int endHour;

  /// Weekdays allowed, 1 = Monday … 7 = Sunday.
  final Set<int> days;
}

class SchedulableTask {
  const SchedulableTask({
    required this.id,
    required this.duration,
    this.deadline,
    this.priority = 3,
    this.earliestStart,
  });

  final String id;
  final Duration duration;
  final DateTime? deadline;

  /// 1 (low) … 5 (high). Breaks ties between equal deadlines.
  final int priority;

  /// Do not schedule before this (e.g. after the reading arrives).
  final DateTime? earliestStart;
}

class ScheduleResult {
  const ScheduleResult({required this.placed, required this.unplaced});

  final List<(SchedulableTask, TimeSlot)> placed;
  final List<(SchedulableTask, String)> unplaced;
}

/// Gaps of at least [minLength] within working [hours] between [from] and
/// [until] that do not overlap any [busy] slot.
List<TimeSlot> findFreeSlots({
  required List<TimeSlot> busy,
  required DateTime from,
  required DateTime until,
  WorkingHours hours = const WorkingHours(),
  Duration minLength = const Duration(minutes: 15),
}) {
  final sorted = List.of(busy)..sort((a, b) => a.start.compareTo(b.start));
  final free = <TimeSlot>[];
  for (
    var day = DateTime(from.year, from.month, from.day);
    day.isBefore(until);
    day = DateTime(day.year, day.month, day.day + 1)
  ) {
    if (!hours.days.contains(day.weekday)) continue;
    var cursor = _max(
      DateTime(day.year, day.month, day.day, hours.startHour),
      from,
    );
    final dayEnd = _min(
      DateTime(day.year, day.month, day.day, hours.endHour),
      until,
    );
    for (final event in sorted) {
      if (!event.end.isAfter(cursor) || !event.start.isBefore(dayEnd)) continue;
      if (event.start.isAfter(cursor)) {
        _addIfLongEnough(free, cursor, event.start, minLength);
      }
      cursor = _max(cursor, event.end);
    }
    _addIfLongEnough(free, cursor, dayEnd, minLength);
  }
  return free;
}

/// Places [tasks] into free time, earliest deadline first (then higher
/// priority, then longer first so big tasks are not squeezed out), each in
/// the earliest slot that ends before its deadline. A [buffer] is kept
/// after every placed task.
ScheduleResult scheduleTasks({
  required List<SchedulableTask> tasks,
  required List<TimeSlot> busy,
  required DateTime from,
  required DateTime until,
  WorkingHours hours = const WorkingHours(),
  Duration buffer = const Duration(minutes: 10),
}) {
  final ordered = List.of(tasks)
    ..sort((a, b) {
      final da = a.deadline ?? until;
      final db = b.deadline ?? until;
      final byDeadline = da.compareTo(db);
      if (byDeadline != 0) return byDeadline;
      final byPriority = b.priority.compareTo(a.priority);
      if (byPriority != 0) return byPriority;
      return b.duration.compareTo(a.duration);
    });

  final occupied = List.of(busy);
  final placed = <(SchedulableTask, TimeSlot)>[];
  final unplaced = <(SchedulableTask, String)>[];

  for (final task in ordered) {
    final start = task.earliestStart != null
        ? _max(task.earliestStart!, from)
        : from;
    final latestEnd = task.deadline != null
        ? _min(task.deadline!, until)
        : until;
    if (task.duration > Duration(hours: hours.endHour - hours.startHour)) {
      unplaced.add((
        task,
        'Longer than a working day — split it into smaller tasks',
      ));
      continue;
    }
    final slots = findFreeSlots(
      busy: occupied,
      from: start,
      until: latestEnd,
      hours: hours,
      minLength: task.duration,
    );
    if (slots.isEmpty) {
      unplaced.add((
        task,
        task.deadline != null && task.deadline!.isBefore(from)
            ? 'Deadline has already passed'
            : 'No free ${task.duration.inMinutes}-minute slot before the deadline',
      ));
      continue;
    }
    final slot = TimeSlot(
      slots.first.start,
      slots.first.start.add(task.duration),
    );
    placed.add((task, slot));
    occupied.add(TimeSlot(slot.start, slot.end.add(buffer)));
  }
  placed.sort((a, b) => a.$2.start.compareTo(b.$2.start));
  return ScheduleResult(placed: placed, unplaced: unplaced);
}

/// Pairs of overlapping slots (e.g. double-booked events), by index.
List<(int, int)> findConflicts(List<TimeSlot> slots) {
  final conflicts = <(int, int)>[];
  for (var i = 0; i < slots.length; i++) {
    for (var j = i + 1; j < slots.length; j++) {
      if (slots[i].overlaps(slots[j])) conflicts.add((i, j));
    }
  }
  return conflicts;
}

/// The first slot of [length] when everyone in [calendars] is free.
TimeSlot? firstCommonSlot({
  required List<List<TimeSlot>> calendars,
  required Duration length,
  required DateTime from,
  required DateTime until,
  WorkingHours hours = const WorkingHours(),
}) {
  final everyone = [for (final c in calendars) ...c];
  final free = findFreeSlots(
    busy: everyone,
    from: from,
    until: until,
    hours: hours,
    minLength: length,
  );
  return free.isEmpty
      ? null
      : TimeSlot(free.first.start, free.first.start.add(length));
}

void _addIfLongEnough(
  List<TimeSlot> into,
  DateTime start,
  DateTime end,
  Duration min,
) {
  if (end.difference(start) >= min) into.add(TimeSlot(start, end));
}

DateTime _max(DateTime a, DateTime b) => a.isAfter(b) ? a : b;
DateTime _min(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
