/// A tiny, JSON-serialisable condition language — the shared core of every
/// configurable rule in this folder (risk rules, automations, contextual
/// actions, badges).
///
/// **Rule-based, not AI.** A condition is evaluated against a "facts" map and
/// is either true or false; the same facts always give the same answer.
///
/// Newly written. The source apps hard-coded their rules in Dart (`if
/// (minutes > 60) ...`), so changing a threshold meant shipping a new build.
/// Expressing rules as data lets them live in a JSON asset, a Supabase table
/// or remote config.
///
/// ```dart
/// final rule = Condition.fromJson({
///   'all': [
///     {'field': 'age', 'op': '>=', 'value': 65},
///     {'any': [
///       {'field': 'conditions', 'op': 'contains', 'value': 'diabetes'},
///       {'field': 'bmi', 'op': '>', 'value': 30},
///     ]},
///   ],
/// });
/// rule.evaluate({'age': 70, 'bmi': 31, 'conditions': <String>[]}); // true
/// rule.describe(); // "(age ≥ 65 and (conditions contains diabetes or bmi > 30))"
/// ```
///
/// **Missing facts:** a field that is absent (or null) makes every operator
/// false except `not_exists`. Rules therefore never fire on data you do not
/// have — check `exists` explicitly if absence matters.
library;

/// Comparison operators, with their JSON spelling.
enum Op {
  eq('=='),
  neq('!='),
  gt('>'),
  gte('>='),
  lt('<'),
  lte('<='),
  contains('contains'),
  notContains('not_contains'),
  isIn('in'),
  notIn('not_in'),
  between('between'),
  exists('exists'),
  notExists('not_exists');

  const Op(this.symbol);
  final String symbol;

  static Op parse(String symbol) => Op.values.firstWhere(
    (op) => op.symbol == symbol,
    orElse: () => throw FormatException('Unknown operator "$symbol"'),
  );
}

sealed class Condition {
  const Condition();

  bool evaluate(Map<String, Object?> facts);

  /// Human-readable form, for explanations ("why was this flagged?").
  String describe();

  Map<String, Object?> toJson();

  /// Parses `{'field','op','value'}`, `{'all': [...]}`, `{'any': [...]}`,
  /// `{'not': {...}}` or `{'always': true}`. Throws [FormatException] on
  /// anything else, so a typo in remote config fails loudly at load time.
  static Condition fromJson(Map<String, Object?> json) {
    if (json.containsKey('all')) {
      return AllOf([for (final c in _list(json['all'])) fromJson(c)]);
    }
    if (json.containsKey('any')) {
      return AnyOf([for (final c in _list(json['any'])) fromJson(c)]);
    }
    if (json.containsKey('not')) {
      return Not(fromJson(_map(json['not'])));
    }
    if (json['always'] == true) return const Always();
    final field = json['field'];
    final op = json['op'];
    if (field is String && op is String) {
      return FieldCondition(field, Op.parse(op), json['value']);
    }
    throw FormatException('Not a condition: $json');
  }

  static List<Map<String, Object?>> _list(Object? value) {
    if (value is! List) throw FormatException('Expected a list, got $value');
    return [for (final item in value) _map(item)];
  }

  static Map<String, Object?> _map(Object? value) {
    if (value is! Map) throw FormatException('Expected an object, got $value');
    return value.cast<String, Object?>();
  }
}

/// Compares one fact with a value. [field] may be a dotted path into nested
/// maps: `'user.address.city'`.
class FieldCondition extends Condition {
  const FieldCondition(this.field, this.op, [this.value]);

  final String field;
  final Op op;
  final Object? value;

  @override
  bool evaluate(Map<String, Object?> facts) {
    final actual = readFact(facts, field);
    if (op == Op.exists) return actual != null;
    if (op == Op.notExists) return actual == null;
    if (actual == null) return false;

    switch (op) {
      case Op.eq:
        return _equals(actual, value);
      case Op.neq:
        return !_equals(actual, value);
      case Op.gt:
        final c = _compare(actual, value);
        return c != null && c > 0;
      case Op.gte:
        final c = _compare(actual, value);
        return c != null && c >= 0;
      case Op.lt:
        final c = _compare(actual, value);
        return c != null && c < 0;
      case Op.lte:
        final c = _compare(actual, value);
        return c != null && c <= 0;
      case Op.contains:
        return _contains(actual, value);
      case Op.notContains:
        return !_contains(actual, value);
      case Op.isIn:
        return value is List && (value as List).any((v) => _equals(actual, v));
      case Op.notIn:
        return value is List && !(value as List).any((v) => _equals(actual, v));
      case Op.between:
        final range = value;
        if (range is! List || range.length != 2) return false;
        final low = _compare(actual, range[0]);
        final high = _compare(actual, range[1]);
        return low != null && high != null && low >= 0 && high <= 0;
      case Op.exists:
      case Op.notExists:
        return false; // handled above
    }
  }

  @override
  String describe() {
    final symbol = switch (op) {
      Op.gte => '≥',
      Op.lte => '≤',
      Op.neq => '≠',
      Op.eq => '=',
      _ => op.symbol.replaceAll('_', ' '),
    };
    if (op == Op.exists || op == Op.notExists) return '$field $symbol';
    final shown = value is List
        ? (value as List).join(op == Op.between ? '–' : ', ')
        : '$value';
    return '$field $symbol $shown';
  }

  @override
  Map<String, Object?> toJson() => {
    'field': field,
    'op': op.symbol,
    if (op != Op.exists && op != Op.notExists) 'value': value,
  };
}

class AllOf extends Condition {
  const AllOf(this.conditions);
  final List<Condition> conditions;

  @override
  bool evaluate(Map<String, Object?> facts) =>
      conditions.every((c) => c.evaluate(facts));

  @override
  String describe() => '(${conditions.map((c) => c.describe()).join(' and ')})';

  @override
  Map<String, Object?> toJson() => {
    'all': [for (final c in conditions) c.toJson()],
  };
}

class AnyOf extends Condition {
  const AnyOf(this.conditions);
  final List<Condition> conditions;

  @override
  bool evaluate(Map<String, Object?> facts) =>
      conditions.any((c) => c.evaluate(facts));

  @override
  String describe() => '(${conditions.map((c) => c.describe()).join(' or ')})';

  @override
  Map<String, Object?> toJson() => {
    'any': [for (final c in conditions) c.toJson()],
  };
}

class Not extends Condition {
  const Not(this.condition);
  final Condition condition;

  @override
  bool evaluate(Map<String, Object?> facts) => !condition.evaluate(facts);

  @override
  String describe() => 'not ${condition.describe()}';

  @override
  Map<String, Object?> toJson() => {'not': condition.toJson()};
}

class Always extends Condition {
  const Always();

  @override
  bool evaluate(Map<String, Object?> facts) => true;

  @override
  String describe() => 'always';

  @override
  Map<String, Object?> toJson() => {'always': true};
}

/// Reads `a.b.c` from nested maps. Returns null when any step is missing.
Object? readFact(Map<String, Object?> facts, String path) {
  Object? current = facts;
  for (final key in path.split('.')) {
    if (current is! Map) return null;
    current = current[key];
  }
  return current;
}

bool _equals(Object? a, Object? b) {
  if (a is num && b is num) return a == b;
  if (a is String && b is String) return a.toLowerCase() == b.toLowerCase();
  return a == b;
}

/// Orders numbers, strings (case-insensitive), DateTimes and ISO date
/// strings against DateTimes. Null when the two cannot be compared.
int? _compare(Object? a, Object? b) {
  if (a is num && b is num) return a.compareTo(b);
  final aDate = a is DateTime ? a : (a is String ? DateTime.tryParse(a) : null);
  final bDate = b is DateTime ? b : (b is String ? DateTime.tryParse(b) : null);
  if ((a is DateTime || b is DateTime) && aDate != null && bDate != null) {
    return aDate.compareTo(bDate);
  }
  if (a is String && b is String) {
    return a.toLowerCase().compareTo(b.toLowerCase());
  }
  return null;
}

bool _contains(Object actual, Object? value) {
  if (actual is String && value is String) {
    return actual.toLowerCase().contains(value.toLowerCase());
  }
  if (actual is Iterable) return actual.any((item) => _equals(item, value));
  if (actual is Map) return actual.containsKey(value);
  return false;
}
