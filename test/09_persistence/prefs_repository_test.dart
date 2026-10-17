import 'package:competition_toolkit/09_persistence/prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

typedef Note = ({String id, String text});

PrefsRepository<Note> notes() => PrefsRepository<Note>(
  key: 'notes',
  idOf: (n) => n.id,
  toJson: (n) => {'id': n.id, 'text': n.text},
  fromJson: (j) => (id: j['id']! as String, text: j['text']! as String),
);

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('CRUD keeps order and survives a new instance', () async {
    final repo = notes();
    expect(await repo.getAll(), isEmpty);
    await repo.save((id: 'a', text: 'first'));
    await repo.save((id: 'b', text: 'second'));
    await repo.save((id: 'a', text: 'edited')); // update keeps position
    expect([for (final n in await repo.getAll()) n.text], ['edited', 'second']);

    final reopened = notes(); // like an app restart
    expect((await reopened.getById('b'))!.text, 'second');
    await reopened.delete('a');
    expect(await reopened.getAll(), hasLength(1));
    await reopened.delete('missing'); // no-op
  });

  test('watchAll emits the current list and every change', () async {
    final repo = notes();
    final seen = <int>[];
    final sub = repo.watchAll().listen((items) => seen.add(items.length));
    await repo.save((id: 'a', text: 'x'));
    await repo.save((id: 'b', text: 'y'));
    await Future<void>.delayed(Duration.zero);
    expect(seen.last, 2);
    await repo.clear();
    await Future<void>.delayed(Duration.zero);
    expect(seen.last, 0);
    await sub.cancel();
  });

  test('corrupt or partly unreadable data does not crash', () async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString('notes', '{not json');
    expect(await notes().getAll(), isEmpty);

    await prefs.setString(
      'notes',
      '[{"id":"ok","text":"fine"},{"id":"broken"}]',
    );
    final items = await notes().getAll();
    expect([for (final n in items) n.id], ['ok']);
  });
}
