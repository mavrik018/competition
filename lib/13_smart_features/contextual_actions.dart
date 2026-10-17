/// Contextual actions: suggest the 1–3 shortcuts that make sense *right
/// now* — "Start focus session" on a weekday morning, "Log dinner" in the
/// evening, "Restock milk" when it is running low — as chips above a list.
///
/// **Rule-based, not AI.** Each action has a condition over a facts map
/// (time of day plus whatever your app adds). Matching actions are ordered
/// by your priority; dismissed ones stay hidden for a cooldown.
///
/// Suits: home screens and dashboards ("what next?"), smart reminders,
/// quick-add bars, kiosk or field apps that adapt to time and place.
///
/// ```dart
/// final engine = ContextualActionEngine([
///   ContextualAction.fromJson({'id': 'focus', 'label': 'Start focus session', 'icon': 'timer',
///     'priority': 5, 'when': {'field': 'partOfDay', 'op': '==', 'value': 'morning'}}),
///   ContextualAction.fromJson({'id': 'restock', 'label': 'Restock milk', 'icon': 'cart',
///     'when': {'field': 'lowStockCount', 'op': '>', 'value': 0}}),
/// ]);
/// final facts = contextFacts(DateTime.now(), {'lowStockCount': pantry.lowStock.length});
/// ContextualActionBar(
///   actions: engine.suggest(facts),
///   onSelected: (a) => runAction(a.id),
///   onDismissed: (a) => engine.dismiss(a.id),
/// );
/// ```
library;

import 'package:flutter/material.dart';

import '../01_design_system/app_tokens.dart';
import 'rule_conditions.dart';

class ContextualAction {
  const ContextualAction({
    required this.id,
    required this.label,
    this.icon = Icons.bolt,
    this.when = const Always(),
    this.priority = 0,
    this.dismissFor = const Duration(hours: 12),
  });

  final String id;
  final String label;
  final IconData icon;
  final Condition when;

  /// Higher shows first.
  final int priority;

  /// How long the action stays hidden after the user dismisses it.
  final Duration dismissFor;

  static const _icons = {
    'bolt': Icons.bolt,
    'timer': Icons.timer_outlined,
    'add': Icons.add,
    'cart': Icons.shopping_cart_outlined,
    'meal': Icons.restaurant,
    'water': Icons.water_drop_outlined,
    'book': Icons.menu_book,
    'run': Icons.directions_run,
    'bed': Icons.bedtime_outlined,
    'call': Icons.call_outlined,
    'check': Icons.check_circle_outline,
  };

  factory ContextualAction.fromJson(Map<String, Object?> json) =>
      ContextualAction(
        id: json['id']! as String,
        label: json['label']! as String,
        icon: _icons[json['icon']] ?? Icons.bolt,
        when: json['when'] == null
            ? const Always()
            : Condition.fromJson(
                (json['when']! as Map).cast<String, Object?>(),
              ),
        priority: (json['priority'] as num?)?.toInt() ?? 0,
        dismissFor: Duration(
          minutes: (json['dismissForMinutes'] as num?)?.toInt() ?? 720,
        ),
      );
}

/// Time facts every rule can use, merged with your own [extra] facts:
/// `hour` (0–23), `weekday` (1 = Monday), `isWeekend`, and `partOfDay`
/// ('morning' 5–11, 'afternoon' 12–16, 'evening' 17–21, 'night').
Map<String, Object?> contextFacts(
  DateTime now, [
  Map<String, Object?> extra = const {},
]) => {
  'hour': now.hour,
  'weekday': now.weekday,
  'isWeekend': now.weekday >= DateTime.saturday,
  'partOfDay': switch (now.hour) {
    >= 5 && < 12 => 'morning',
    >= 12 && < 17 => 'afternoon',
    >= 17 && < 22 => 'evening',
    _ => 'night',
  },
  ...extra,
};

class ContextualActionEngine {
  ContextualActionEngine(this.actions, {this.maxSuggestions = 3});

  final List<ContextualAction> actions;
  final int maxSuggestions;

  /// Action id → when it was dismissed. Persist it (e.g. as JSON in
  /// `PrefsStore`) if dismissals should survive a restart.
  final Map<String, DateTime> dismissedAt = {};

  /// Actions whose condition holds for [facts] and that are not hidden,
  /// highest priority first (ties keep list order).
  List<ContextualAction> suggest(Map<String, Object?> facts, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final matching =
        [
          for (final (index, action) in actions.indexed)
            if (!_isHidden(action, clock) && action.when.evaluate(facts))
              (index, action),
        ]..sort((a, b) {
          final byPriority = b.$2.priority.compareTo(a.$2.priority);
          return byPriority != 0 ? byPriority : a.$1.compareTo(b.$1);
        });
    return [for (final (_, action) in matching.take(maxSuggestions)) action];
  }

  void dismiss(String id, {DateTime? at}) =>
      dismissedAt[id] = at ?? DateTime.now();

  bool _isHidden(ContextualAction action, DateTime now) {
    final at = dismissedAt[action.id];
    return at != null && now.difference(at) < action.dismissFor;
  }
}

/// A horizontal row of suggestion chips; each chip's × hides it (when
/// [onDismissed] is set). Renders nothing when [actions] is empty.
class ContextualActionBar extends StatelessWidget {
  const ContextualActionBar({
    super.key,
    required this.actions,
    required this.onSelected,
    this.onDismissed,
  });

  final List<ContextualAction> actions;
  final ValueChanged<ContextualAction> onSelected;
  final ValueChanged<ContextualAction>? onDismissed;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Gap.md),
      child: Row(
        children: [
          for (final action in actions)
            Padding(
              padding: const EdgeInsets.only(right: Gap.sm),
              child: InputChip(
                avatar: Icon(action.icon, size: 18),
                label: Text(action.label),
                onPressed: () => onSelected(action),
                onDeleted: onDismissed == null
                    ? null
                    : () => onDismissed!(action),
                deleteButtonTooltipMessage: 'Hide "${action.label}"',
              ),
            ),
        ],
      ),
    );
  }
}
