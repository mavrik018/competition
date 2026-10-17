// Where the items live. To change storage, change ONE line here:
//   PrefsRepository      — any platform incl. web, small data (default)
//   SqfliteRepository    — mobile/desktop, larger data (lib/toolkit/09_persistence)
//   SupabaseRepository   — cloud, multi-user (lib/toolkit/10_backend; needs a project)
//   InMemoryRepository   — tests and demos
// Screens and the controller only know `Repository<Item>`.

import 'package:{{app_name}}/toolkit/08_state_management/crud_controller.dart';
import 'package:{{app_name}}/toolkit/09_persistence/prefs_repository.dart';
import 'package:{{app_name}}/toolkit/09_persistence/repository.dart';
import 'package:{{app_name}}/toolkit/13_smart_features/priority_scoring.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'item.dart';

final itemRepositoryProvider = Provider<Repository<Item>>(
  (ref) => PrefsRepository<Item>(
    key: 'items',
    idOf: (i) => i.id,
    toJson: (i) => i.toJson(),
    fromJson: Item.fromJson,
  ),
);

/// The item list with optimistic save/delete. Open items first, then by
/// the rule-based priority score (highest first).
final itemsProvider = AsyncNotifierProvider<CrudController<Item>, List<Item>>(
  () => CrudController(
    (ref) => ref.watch(itemRepositoryProvider),
    idOf: (i) => i.id,
    sort: compareItems,
  ),
);

int compareItems(Item a, Item b) {
  if (a.done != b.done) return a.done ? 1 : -1;
  final now = DateTime.now();
  return scorePriority(
    b.priorityInput,
    now: now,
  ).score.compareTo(scorePriority(a.priorityInput, now: now).score);
}
