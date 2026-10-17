/// Automation: "when X happens and Y is true, do Z" rules (like IFTTT /
/// Shortcuts) that users or admins can create, store as JSON and toggle —
/// evaluated by a small engine that calls your action handlers.
///
/// **Rule-based, not AI.** An event either matches a rule or not; actions
/// are your own functions. Nothing runs unless a rule says so.
///
/// Suits: "when a task is completed, award XP", "when spending in a
/// category passes 80% of budget, notify me", "when I arrive at the gym,
/// start a workout timer", "when stock falls below 3, add to shopping
/// list", "when a grade under 50 is entered, flag the student".
///
/// ```dart
/// final engine = AutomationEngine(
///   rules: [
///     AutomationRule.fromJson({
///       'id': 'low_stock', 'name': 'Restock reminder',
///       'trigger': 'item_used',
///       'when': {'field': 'remaining', 'op': '<', 'value': 3},
///       'actions': [{'type': 'add_to_list', 'params': {'list': 'shopping'}}],
///       'cooldownMinutes': 60,
///     }),
///   ],
///   handlers: {
///     'add_to_list': (event, params) async => shopping.add(event.data['name'] as String),
///     'notify': (event, params) async => reminders.schedule(...),
///   },
/// );
/// await engine.handle(AppEvent('item_used', {'name': 'Milk', 'remaining': 1}));
/// ```
///
/// Event data can be anything your rules need; conditions read it as the
/// facts map (see `rule_conditions.dart`).
library;

import 'rule_conditions.dart';

class AppEvent {
  AppEvent(this.type, [this.data = const {}, DateTime? at])
    : at = at ?? DateTime.now();

  final String type;
  final Map<String, Object?> data;
  final DateTime at;
}

class AutomationAction {
  const AutomationAction(this.type, [this.params = const {}]);

  final String type;
  final Map<String, Object?> params;

  Map<String, Object?> toJson() => {
    'type': type,
    if (params.isNotEmpty) 'params': params,
  };
}

class AutomationRule {
  const AutomationRule({
    required this.id,
    required this.name,
    required this.trigger,
    required this.actions,
    this.when = const Always(),
    this.enabled = true,
    this.cooldown = Duration.zero,
  });

  final String id;
  final String name;

  /// The [AppEvent.type] this rule listens for.
  final String trigger;
  final Condition when;
  final List<AutomationAction> actions;
  final bool enabled;

  /// Minimum time between two runs of this rule (stops notification spam).
  final Duration cooldown;

  AutomationRule copyWith({bool? enabled}) => AutomationRule(
    id: id,
    name: name,
    trigger: trigger,
    actions: actions,
    when: when,
    enabled: enabled ?? this.enabled,
    cooldown: cooldown,
  );

  factory AutomationRule.fromJson(Map<String, Object?> json) => AutomationRule(
    id: json['id']! as String,
    name: (json['name'] ?? json['id']) as String,
    trigger: json['trigger']! as String,
    when: json['when'] == null
        ? const Always()
        : Condition.fromJson((json['when']! as Map).cast<String, Object?>()),
    actions: [
      for (final a in (json['actions']! as List))
        AutomationAction(
          (a as Map)['type']! as String,
          (a['params'] as Map?)?.cast<String, Object?>() ?? const {},
        ),
    ],
    enabled: json['enabled'] != false,
    cooldown: Duration(
      minutes: (json['cooldownMinutes'] as num?)?.toInt() ?? 0,
    ),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'trigger': trigger,
    'when': when.toJson(),
    'actions': [for (final a in actions) a.toJson()],
    'enabled': enabled,
    if (cooldown > Duration.zero) 'cooldownMinutes': cooldown.inMinutes,
  };

  /// "When item_used and remaining < 3 → add_to_list" — for a rules list UI.
  String describe() =>
      'When $trigger${when is Always ? '' : ' and ${when.describe()}'} → ${actions.map((a) => a.type).join(', ')}';
}

typedef ActionHandler =
    Future<void> Function(AppEvent event, Map<String, Object?> params);

/// One action that ran (or failed), for an activity log or debugging.
class AutomationRun {
  const AutomationRun({
    required this.ruleId,
    required this.actionType,
    required this.at,
    this.error,
  });

  final String ruleId;
  final String actionType;
  final DateTime at;
  final Object? error;

  bool get succeeded => error == null;
}

class AutomationEngine {
  AutomationEngine({
    required List<AutomationRule> rules,
    required this.handlers,
  }) : _rules = List.of(rules);

  final Map<String, ActionHandler> handlers;
  final List<AutomationRule> _rules;
  final Map<String, DateTime> _lastRun = {};
  final List<AutomationRun> log = [];

  List<AutomationRule> get rules => List.unmodifiable(_rules);

  void upsertRule(AutomationRule rule) {
    final index = _rules.indexWhere((r) => r.id == rule.id);
    index < 0 ? _rules.add(rule) : _rules[index] = rule;
  }

  void removeRule(String id) => _rules.removeWhere((r) => r.id == id);

  void setEnabled(String id, bool enabled) {
    final index = _rules.indexWhere((r) => r.id == id);
    if (index >= 0) _rules[index] = _rules[index].copyWith(enabled: enabled);
  }

  /// Runs every enabled rule matching [event]. One failing action is logged
  /// and does not stop the others. Returns the runs from this event.
  Future<List<AutomationRun>> handle(AppEvent event) async {
    final runs = <AutomationRun>[];
    for (final rule in List.of(_rules)) {
      if (!rule.enabled || rule.trigger != event.type) continue;
      if (!rule.when.evaluate(event.data)) continue;
      final last = _lastRun[rule.id];
      if (last != null && event.at.difference(last) < rule.cooldown) continue;
      _lastRun[rule.id] = event.at;

      for (final action in rule.actions) {
        final handler = handlers[action.type];
        Object? error;
        if (handler == null) {
          error = StateError('No handler for action "${action.type}"');
        } else {
          try {
            await handler(event, action.params);
          } catch (e) {
            error = e;
          }
        }
        runs.add(
          AutomationRun(
            ruleId: rule.id,
            actionType: action.type,
            at: event.at,
            error: error,
          ),
        );
      }
    }
    log.addAll(runs);
    return runs;
  }
}
