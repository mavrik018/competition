// The app's main record. Rename it (Task, Report, Booking…) and add fields;
// keep `id` and `updatedAt`, which storage and sync rely on.

import 'package:{{app_name}}/toolkit/09_persistence/local_id.dart';
import 'package:{{app_name}}/toolkit/13_smart_features/priority_scoring.dart';
import 'package:flutter/foundation.dart';

@immutable
class Item {
  const Item({
    required this.id,
    required this.title,
    this.notes,
    this.importance = 3,
    this.due,
    this.done = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Item.create({
    required String title,
    String? notes,
    int importance = 3,
    DateTime? due,
  }) {
    final now = DateTime.now();
    return Item(
      id: generateLocalId(),
      title: title,
      notes: notes,
      importance: importance,
      due: due,
      createdAt: now,
      updatedAt: now,
    );
  }

  final String id;
  final String title;
  final String? notes;

  /// 1 (low) … 5 (essential).
  final int importance;
  final DateTime? due;
  final bool done;
  final DateTime createdAt;
  final DateTime updatedAt;

  Item copyWith({
    String? title,
    String? notes,
    int? importance,
    DateTime? due,
    bool clearDue = false,
    bool? done,
  }) => Item(
    id: id,
    title: title ?? this.title,
    notes: notes ?? this.notes,
    importance: importance ?? this.importance,
    due: clearDue ? null : (due ?? this.due),
    done: done ?? this.done,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );

  /// Input for the rule-based priority score (toolkit 13).
  PriorityInput get priorityInput =>
      PriorityInput(due: due, importance: importance, createdAt: createdAt);

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'notes': notes,
    'importance': importance,
    'due': due?.toIso8601String(),
    'done': done,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// Tolerant: missing or malformed fields get defaults instead of crashing.
  factory Item.fromJson(Map<String, Object?> json) {
    final created = DateTime.tryParse('${json['createdAt']}') ?? DateTime(2000);
    return Item(
      id: json['id']! as String,
      title: (json['title'] as String?) ?? '',
      notes: json['notes'] as String?,
      importance: (json['importance'] as num?)?.toInt() ?? 3,
      due: DateTime.tryParse('${json['due']}'),
      done: json['done'] == true,
      createdAt: created,
      updatedAt: DateTime.tryParse('${json['updatedAt']}') ?? created,
    );
  }
}
