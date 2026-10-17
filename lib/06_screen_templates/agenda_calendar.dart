/// A month calendar with event dots and the selected day's agenda below —
/// the standard "calendar + list of what's on" screen body.
///
/// Source: Couple `calendar_page.dart` (month grid + agenda section,
/// `table_calendar`) rebuilt on the toolkit's dependency-free
/// `CalendarGrid`, generic over any event type.
///
/// ```dart
/// AgendaCalendar<Event>(
///   events: events,
///   dateOf: (e) => e.start,
///   itemBuilder: (context, e) => ListTile(title: Text(e.title), subtitle: Text(formatTime(e.start))),
///   onDaySelected: (day) => selectedDay = day,
/// )
/// ```
library;

import 'package:flutter/material.dart';

import '../01_design_system/app_tokens.dart';
import '../03_feedback/state_views.dart';
import '../05_forms/calendar_grid.dart';
import '../11_utilities/date_utils.dart';

class AgendaCalendar<T> extends StatefulWidget {
  const AgendaCalendar({
    super.key,
    required this.events,
    required this.dateOf,
    required this.itemBuilder,
    this.initialDay,
    this.onDaySelected,
    this.firstWeekday = DateTime.monday,
    this.emptyText = 'Nothing planned',
    this.today,
  });

  final List<T> events;
  final DateTime Function(T event) dateOf;
  final Widget Function(BuildContext context, T event) itemBuilder;
  final DateTime? initialDay;
  final ValueChanged<DateTime>? onDaySelected;
  final int firstWeekday;
  final String emptyText;

  /// Overrides "today" for labels — for tests and previews.
  final DateTime? today;

  @override
  State<AgendaCalendar<T>> createState() => _AgendaCalendarState<T>();
}

class _AgendaCalendarState<T> extends State<AgendaCalendar<T>> {
  late DateTime _day = dateOnly(
    widget.initialDay ?? widget.today ?? DateTime.now(),
  );

  /// Events grouped by calendar day, rebuilt only when the list changes.
  late Map<DateTime, List<T>> _byDay = _group();

  @override
  void didUpdateWidget(AgendaCalendar<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events != widget.events) _byDay = _group();
  }

  Map<DateTime, List<T>> _group() {
    final map = <DateTime, List<T>>{};
    for (final event in widget.events) {
      (map[dateOnly(widget.dateOf(event))] ??= []).add(event);
    }
    for (final list in map.values) {
      list.sort((a, b) => widget.dateOf(a).compareTo(widget.dateOf(b)));
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final dayEvents = _byDay[_day] ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CalendarGrid(
          selected: _day,
          firstWeekday: widget.firstWeekday,
          markerCount: (day) => _byDay[dateOnly(day)]?.length ?? 0,
          onSelected: (day) {
            setState(() => _day = dateOnly(day));
            widget.onDaySelected?.call(day);
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.xs),
          child: Semantics(
            header: true,
            child: Text(
              '${relativeDayLabel(_day, now: widget.today)} · ${dayEvents.length} '
              '${dayEvents.length == 1 ? 'item' : 'items'}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ),
        if (dayEvents.isEmpty)
          EmptyView(
            icon: Icons.event_available_outlined,
            title: widget.emptyText,
            compact: true,
          )
        else
          for (final event in dayEvents) widget.itemBuilder(context, event),
      ],
    );
  }
}
