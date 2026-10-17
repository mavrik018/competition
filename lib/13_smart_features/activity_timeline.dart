/// Activity timeline: a chronological feed of what happened ("You
/// completed 3 tasks", "Ana commented on your note") grouped under Today /
/// Yesterday / dates, with a vertical line connecting the entries.
///
/// **Not AI.** Grouping and labelling only. Generate events from your own
/// writes (or from `AutomationEngine.log`).
///
/// Suits: audit/history screens, shared-space feeds (couple, team, class),
/// order or case tracking, "what I did this week" reviews, notification
/// centres.
///
/// ```dart
/// ActivityTimeline(
///   events: [
///     ActivityEvent(id: '1', title: 'Completed "Essay draft"', at: now, icon: Icons.check_circle),
///     ActivityEvent(id: '2', title: 'Ana joined the group', subtitle: 'Biology 101', at: yesterday),
///   ],
///   onTap: (e) => openDetail(e.id),
/// )
/// ```
library;

import 'package:flutter/material.dart';

import '../01_design_system/app_tokens.dart';
import '../11_utilities/date_utils.dart';

class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.title,
    required this.at,
    this.subtitle,
    this.icon = Icons.circle,
    this.color,
    this.type,
  });

  final String id;
  final String title;
  final DateTime at;
  final String? subtitle;
  final IconData icon;
  final Color? color;

  /// Your own category ('task', 'comment'…) for filtering.
  final String? type;
}

/// Newest first, grouped by calendar day. Labels: "Today", "Yesterday",
/// a weekday within the past week, otherwise "Sep 14" (with the year if not
/// this year).
List<({String label, List<ActivityEvent> events})> groupActivityByDay(
  Iterable<ActivityEvent> events, {
  required DateTime now,
}) {
  final sorted = events.toList()..sort((a, b) => b.at.compareTo(a.at));
  final groups = <({String label, List<ActivityEvent> events})>[];
  DateTime? currentDay;
  for (final event in sorted) {
    final day = dateOnly(event.at);
    if (currentDay == null || day != currentDay) {
      currentDay = day;
      groups.add((label: _dayLabel(day, now), events: []));
    }
    groups.last.events.add(event);
  }
  return groups;
}

String _dayLabel(DateTime day, DateTime now) {
  final diff = daysBetween(day, now);
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff > 1 && diff < 7) return weekdayNames[day.weekday - 1];
  return day.year == now.year
      ? formatShortDate(day)
      : '${formatShortDate(day)}, ${day.year}';
}

class ActivityTimeline extends StatelessWidget {
  const ActivityTimeline({
    super.key,
    required this.events,
    this.onTap,
    this.now,
    this.emptyText = 'No activity yet',
  });

  final List<ActivityEvent> events;
  final ValueChanged<ActivityEvent>? onTap;

  /// Overrides the clock — for tests.
  final DateTime? now;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final clock = now ?? DateTime.now();
    if (events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Text(
          emptyText,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final group in groupActivityByDay(events, now: clock)) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.xs),
            child: Semantics(
              header: true,
              child: Text(
                group.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                ),
              ),
            ),
          ),
          for (var i = 0; i < group.events.length; i++)
            _TimelineRow(
              event: group.events[i],
              isLast: i == group.events.length - 1,
              onTap: onTap,
            ),
        ],
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event, required this.isLast, this.onTap});

  final ActivityEvent event;
  final bool isLast;
  final ValueChanged<ActivityEvent>? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = event.color ?? scheme.primary;
    return InkWell(
      onTap: onTap == null ? null : () => onTap!(event),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 48,
              child: Column(
                children: [
                  const SizedBox(height: Gap.sm),
                  Icon(event.icon, size: 18, color: color),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: scheme.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, Gap.sm, Gap.md, Gap.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title, style: theme.textTheme.bodyLarge),
                    if (event.subtitle != null)
                      Text(
                        event.subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    Text(
                      formatTime(event.at),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
