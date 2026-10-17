/// A month calendar you can page through, plus two ways to use it as a date
/// picker: an inline [DateField] form row that expands it, and a modal
/// [showDatePickerSheet].
///
/// Source: StudyBuddies `IosCalendarGrid`, `IosDateField`, `showIosDatePicker`
/// (`core/widgets/ios_ui.dart`), also ported by Cookly. Kept: the per-day
/// background hook (StudyBuddies uses it for a streak heatmap) and
/// first/last-date limits. Changed: the week start is configurable (the
/// source was Sunday-only), dates are built from year/month/day so daylight
/// saving can never shift a cell, and no `intl` dependency.
///
/// ```dart
/// FormSection(children: [
///   DateField(label: 'Due', value: due, onChanged: setDue, firstDate: DateTime.now()),
/// ])
///
/// final picked = await showDatePickerSheet(context, initialDate: DateTime.now());
/// ```
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../01_design_system/app_tokens.dart';

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', //
  'August', 'September', 'October', 'November', 'December',
];
const _weekdayShort = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

/// The cells of [month]'s grid: `null` for the blanks before day 1, then one
/// date per day. [firstWeekday] uses [DateTime.monday]..[DateTime.sunday].
List<DateTime?> monthCells(
  DateTime month, {
  int firstWeekday = DateTime.sunday,
}) {
  final first = DateTime(month.year, month.month);
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final leading = (first.weekday - firstWeekday) % 7;
  return [
    for (var i = 0; i < leading; i++) null,
    for (var d = 1; d <= daysInMonth; d++) DateTime(month.year, month.month, d),
  ];
}

/// Weekday headings in display order for [firstWeekday].
List<String> weekdayHeadings(int firstWeekday) => [
  for (var i = 0; i < 7; i++) _weekdayShort[(firstWeekday - 1 + i) % 7],
];

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

class CalendarGrid extends StatefulWidget {
  const CalendarGrid({
    super.key,
    required this.selected,
    required this.onSelected,
    this.firstDate,
    this.lastDate,
    this.dayColor,
    this.markerCount,
    this.firstWeekday = DateTime.sunday,
    this.showCard = true,
  });

  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  /// Days before [firstDate] or after [lastDate] are greyed out and inert.
  final DateTime? firstDate;
  final DateTime? lastDate;

  /// Optional background per day — e.g. activity intensity.
  final Color? Function(DateTime day)? dayColor;

  /// Number of event dots under a day (0–3 drawn; e.g. events that day).
  final int Function(DateTime day)? markerCount;
  final int firstWeekday;

  /// When false, the grid renders without its own card, for embedding.
  final bool showCard;

  @override
  State<CalendarGrid> createState() => _CalendarGridState();
}

class _CalendarGridState extends State<CalendarGrid> {
  late DateTime _month = DateTime(widget.selected.year, widget.selected.month);

  @override
  void didUpdateWidget(CalendarGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameDay(oldWidget.selected, widget.selected)) {
      _month = DateTime(widget.selected.year, widget.selected.month);
    }
  }

  bool _enabled(DateTime day) {
    final first = widget.firstDate;
    final last = widget.lastDate;
    if (first != null && day.isBefore(_dateOnly(first))) return false;
    if (last != null && day.isAfter(_dateOnly(last))) return false;
    return true;
  }

  void _shiftMonth(int delta) {
    HapticFeedback.selectionClick();
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = DateTime.now();
    final cells = monthCells(_month, firstWeekday: widget.firstWeekday);

    final grid = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_monthNames[_month.month - 1]} ${_month.year}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Previous month',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  CupertinoIcons.chevron_left,
                  size: 18,
                  color: scheme.primary,
                ),
                onPressed: () => _shiftMonth(-1),
              ),
              IconButton(
                tooltip: 'Next month',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  CupertinoIcons.chevron_right,
                  size: 18,
                  color: scheme.primary,
                ),
                onPressed: () => _shiftMonth(1),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              for (final name in weekdayHeadings(widget.firstWeekday))
                Expanded(
                  child: Center(
                    child: Text(
                      name,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
          child: GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              for (final day in cells)
                day == null ? const SizedBox.shrink() : _dayCell(day, today),
            ],
          ),
        ),
      ],
    );

    if (!widget.showCard) return grid;
    return Material(
      color: scheme.surfaceContainerLowest,
      elevation: 2,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg - 2),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: grid,
    );
  }

  Widget _dayCell(DateTime day, DateTime today) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isSelected = _sameDay(day, widget.selected);
    final isToday = _sameDay(day, today);
    final enabled = _enabled(day);
    final custom = widget.dayColor?.call(day);

    final background = isSelected
        ? scheme.primary.withValues(alpha: 0.15)
        : (custom ?? Colors.transparent);
    final Color textColor;
    if (!enabled) {
      textColor = scheme.onSurfaceVariant.withValues(alpha: 0.35);
    } else if (isSelected || isToday) {
      textColor = scheme.primary;
    } else if (custom != null) {
      textColor =
          ThemeData.estimateBrightnessForColor(custom) == Brightness.dark
          ? Colors.white
          : scheme.onSurface;
    } else {
      textColor = scheme.onSurface;
    }

    final markers = (widget.markerCount?.call(day) ?? 0).clamp(0, 3);

    return Semantics(
      button: enabled,
      selected: isSelected,
      label:
          '${_monthNames[day.month - 1]} ${day.day}'
          '${markers > 0 ? ', has events' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                widget.onSelected(day);
              }
            : null,
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.day}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: textColor,
                    fontWeight: isSelected || isToday ? FontWeight.w600 : null,
                    height: 1.1,
                  ),
                ),
                if (markers > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < markers; i++)
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A form row showing the chosen date as a pill; tapping it expands a
/// [CalendarGrid] inline underneath. Place it inside a `FormSection`.
class DateField extends StatefulWidget {
  const DateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Date',
    this.firstDate,
    this.lastDate,
    this.firstWeekday = DateTime.sunday,
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final String label;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final int firstWeekday;

  @override
  State<DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<DateField> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final v = widget.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _expanded = !_expanded);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(widget.label, style: theme.textTheme.bodyLarge),
                ),
                AnimatedContainer(
                  duration: Motion.short,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _expanded
                        ? scheme.primary.withValues(alpha: 0.15)
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: Text(
                    '${_monthNames[v.month - 1]} ${v.day}, ${v.year}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: _expanded ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: Motion.medium,
          sizeCurve: Curves.easeOutCubic,
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: CalendarGrid(
              selected: widget.value,
              firstDate: widget.firstDate,
              lastDate: widget.lastDate,
              firstWeekday: widget.firstWeekday,
              showCard: false,
              onSelected: (date) {
                widget.onChanged(date);
                setState(() => _expanded = false);
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Shows a [CalendarGrid] in a bottom sheet. Resolves to the tapped date, or
/// null when cancelled.
Future<DateTime?> showDatePickerSheet(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  int firstWeekday = DateTime.sunday,
  String title = 'Select date',
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                CalendarGrid(
                  selected: initialDate,
                  firstDate: firstDate,
                  lastDate: lastDate,
                  firstWeekday: firstWeekday,
                  showCard: false,
                  onSelected: (date) => Navigator.of(sheetContext).pop(date),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
