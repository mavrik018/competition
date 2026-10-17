/// Real-time collaboration: a shared key → value document that several
/// devices edit at once and that always ends up identical everywhere — even
/// when messages arrive late, out of order or twice.
///
/// **Not AI.** A last-writer-wins map CRDT ("conflict-free replicated data
/// type"): every change carries a Lamport timestamp plus the device id, so
/// all devices agree which of two concurrent edits is "later" without a
/// server deciding. Small enough to read in one sitting.
///
/// Suits: shared shopping/packing lists, a couple's or family's shared
/// board, group trip planning, classroom polls, live scoreboards, shared
/// settings, collaborative checklists.
///
/// ```dart
/// // Production transport: Supabase Realtime broadcast (needs a project).
/// final doc = CollaborativeDocument(
///   replicaId: deviceId,
///   transport: SupabaseBroadcastTransport(Supabase.instance.client, 'list:$listId'),
/// );
/// await doc.connect();
/// await doc.set('item:milk', {'title': 'Milk', 'done': false});
/// StreamBuilder(stream: doc.changes, builder: …);   // the whole map after each change
/// ```
///
/// **Granularity:** one key is the unit of conflict. Two people editing
/// *different* keys never conflict; two editing the *same* key → the later
/// stamp wins and the other edit is lost. Use one key per list item (not
/// one key for the whole list), and never use it for character-by-character
/// text editing (that needs a sequence CRDT such as Yjs).
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A Lamport counter plus the writing replica's id. Compared counter
/// first, then id, so every replica orders any two stamps the same way.
@immutable
class CollabStamp implements Comparable<CollabStamp> {
  const CollabStamp(this.counter, this.replicaId);

  final int counter;
  final String replicaId;

  @override
  int compareTo(CollabStamp other) {
    final byCounter = counter.compareTo(other.counter);
    return byCounter != 0 ? byCounter : replicaId.compareTo(other.replicaId);
  }

  bool operator >(CollabStamp other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is CollabStamp &&
      other.counter == counter &&
      other.replicaId == replicaId;

  @override
  int get hashCode => Object.hash(counter, replicaId);

  @override
  String toString() => '$counter@$replicaId';
}

/// One change: set [key] to [value], or delete it ([deleted] = true; the
/// "tombstone" is kept so a late, older "set" cannot bring the key back).
@immutable
class CollabOp {
  const CollabOp({
    required this.key,
    required this.stamp,
    this.value,
    this.deleted = false,
  });

  final String key;

  /// Any JSON-encodable value.
  final Object? value;
  final CollabStamp stamp;
  final bool deleted;

  Map<String, dynamic> toJson() => {
    'key': key,
    'value': value,
    'counter': stamp.counter,
    'replica': stamp.replicaId,
    if (deleted) 'deleted': true,
  };

  factory CollabOp.fromJson(Map<String, dynamic> json) => CollabOp(
    key: json['key'] as String,
    value: json['value'],
    stamp: CollabStamp(
      (json['counter'] as num).toInt(),
      json['replica'] as String,
    ),
    deleted: json['deleted'] == true,
  );
}

/// The CRDT itself: keeps, per key, the op with the greatest stamp.
/// Applying ops in any order, any number of times, gives the same result.
class LwwMap {
  final Map<String, CollabOp> _latest = {};

  /// Returns true when [op] changed the map.
  bool apply(CollabOp op) {
    final current = _latest[op.key];
    if (current != null && !(op.stamp > current.stamp)) return false;
    _latest[op.key] = op;
    return true;
  }

  /// Live (non-deleted) entries.
  Map<String, Object?> get values => {
    for (final op in _latest.values)
      if (!op.deleted) op.key: op.value,
  };

  int get maxCounter =>
      _latest.values.fold(0, (m, op) => math.max(m, op.stamp.counter));

  /// Every winning op, tombstones included — the full state.
  List<CollabOp> get ops => List.unmodifiable(_latest.values);
}

// ── Transport seam ──────────────────────────────────────────────────────────

/// Delivers JSON messages to every *other* connected replica. Delivery may
/// be late, reordered or duplicated — the document copes with all three.
abstract interface class CollabTransport {
  Stream<Map<String, dynamic>> get incoming;
  Future<void> connect();
  Future<void> send(Map<String, dynamic> message);
  Future<void> close();
}

/// Supabase Realtime **broadcast** channel (no database table needed).
/// 🔶 Needs a Supabase project; not covered by unit tests. Broadcast keeps
/// no history: save [CollaborativeDocument.exportState] somewhere durable
/// (a table, local storage) if the document must outlive the session.
class SupabaseBroadcastTransport implements CollabTransport {
  SupabaseBroadcastTransport(
    this._client,
    this.channelName, {
    this.event = 'collab',
    this.isPrivate = false,
  });

  final SupabaseClient _client;
  final String channelName;
  final String event;

  /// Private channels need a Realtime authorization policy (see
  /// `10_backend/realtime_presence.dart`).
  final bool isPrivate;
  RealtimeChannel? _channel;
  final _incoming = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get incoming => _incoming.stream;

  @override
  Future<void> connect() {
    final ready = Completer<void>();
    _channel = _client
        .channel(channelName, opts: RealtimeChannelConfig(private: isPrivate))
        .onBroadcast(
          event: event,
          callback: (message) {
            // The user payload is nested under 'payload'.
            final data = message['payload'];
            if (data is Map) _incoming.add(Map<String, dynamic>.from(data));
          },
        )
        .subscribe((status, error) {
          if (ready.isCompleted) return;
          if (status == RealtimeSubscribeStatus.subscribed) {
            ready.complete();
          } else if (error != null) {
            ready.completeError(error);
          }
        });
    return ready.future;
  }

  @override
  Future<void> send(Map<String, dynamic> message) async {
    await _channel?.sendBroadcastMessage(event: event, payload: message);
  }

  @override
  Future<void> close() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) await _client.removeChannel(channel);
    await _incoming.close();
  }
}

/// A test/demo double: replicas connected to one hub in the same process.
/// **Not production functionality** — nothing leaves the device. Set
/// [holdMessages] to queue messages, then [deliverHeld] them reordered or
/// duplicated to simulate a bad network.
class InMemoryCollabHub {
  final List<_HubTransport> _peers = [];
  final List<(_HubTransport, Map<String, dynamic>)> _held = [];
  bool holdMessages = false;

  CollabTransport transport() => _HubTransport(this);

  int get heldCount => _held.length;

  /// Delivers held messages, optionally in reverse order and/or twice.
  void deliverHeld({bool reverse = false, bool duplicate = false}) {
    final batch = reverse ? _held.reversed.toList() : List.of(_held);
    _held.clear();
    for (final (to, message) in [...batch, if (duplicate) ...batch]) {
      to._deliver(message);
    }
  }

  void _send(_HubTransport from, Map<String, dynamic> message) {
    for (final peer in _peers) {
      if (identical(peer, from)) continue;
      // Copy through JSON-like maps so replicas never share objects.
      final copy = Map<String, dynamic>.from(message);
      holdMessages ? _held.add((peer, copy)) : peer._deliver(copy);
    }
  }
}

class _HubTransport implements CollabTransport {
  _HubTransport(this._hub);

  final InMemoryCollabHub _hub;
  final _incoming = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get incoming => _incoming.stream;

  void _deliver(Map<String, dynamic> message) {
    if (!_incoming.isClosed) _incoming.add(message);
  }

  @override
  Future<void> connect() async => _hub._peers.add(this);

  @override
  Future<void> send(Map<String, dynamic> message) async =>
      _hub._send(this, message);

  @override
  Future<void> close() async {
    _hub._peers.remove(this);
    await _incoming.close();
  }
}

// ── The document ────────────────────────────────────────────────────────────

/// A shared map kept in sync over a [CollabTransport].
///
/// Protocol (three JSON messages):
/// * `{'type': 'op', 'op': {…}}` — one change.
/// * `{'type': 'hello', 'from': id}` — sent on connect; peers answer with…
/// * `{'type': 'state', 'ops': [...]}` — everything they know, so a late
///   joiner catches up from whoever is online.
class CollaborativeDocument {
  CollaborativeDocument({required this.replicaId, required this.transport});

  final String replicaId;
  final CollabTransport transport;
  final LwwMap _map = LwwMap();
  final _changes = StreamController<Map<String, Object?>>.broadcast();
  StreamSubscription<Map<String, dynamic>>? _subscription;
  int _clock = 0;

  /// The whole map after every local or remote change.
  Stream<Map<String, Object?>> get changes => _changes.stream;

  Map<String, Object?> get values => _map.values;

  Object? operator [](String key) => _map.values[key];

  Future<void> connect() async {
    _subscription = transport.incoming.listen(_receive);
    await transport.connect();
    await transport.send({'type': 'hello', 'from': replicaId});
  }

  Future<void> set(String key, Object? value) =>
      _write(CollabOp(key: key, value: value, stamp: _tick()));

  Future<void> remove(String key) =>
      _write(CollabOp(key: key, stamp: _tick(), deleted: true));

  /// Full state, for saving locally or in a table between sessions.
  List<Map<String, dynamic>> exportState() => [
    for (final op in _map.ops) op.toJson(),
  ];

  /// Merges a saved state (safe to call with stale or duplicate data).
  void importState(List<Object?> ops) {
    var changed = false;
    for (final json in ops) {
      if (json is Map) {
        changed |= _apply(CollabOp.fromJson(Map<String, dynamic>.from(json)));
      }
    }
    if (changed) _emit();
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await transport.close();
    await _changes.close();
  }

  CollabStamp _tick() => CollabStamp(++_clock, replicaId);

  Future<void> _write(CollabOp op) async {
    _apply(op);
    _emit();
    await transport.send({'type': 'op', 'op': op.toJson()});
  }

  bool _apply(CollabOp op) {
    _clock = math.max(_clock, op.stamp.counter); // Lamport rule
    return _map.apply(op);
  }

  void _receive(Map<String, dynamic> message) {
    switch (message['type']) {
      case 'op':
        final op = CollabOp.fromJson(
          Map<String, dynamic>.from(message['op'] as Map),
        );
        if (_apply(op)) _emit();
      case 'state':
        importState(message['ops'] as List);
      case 'hello' when message['from'] != replicaId:
        if (_map.ops.isNotEmpty) {
          unawaited(transport.send({'type': 'state', 'ops': exportState()}));
        }
      default:
        debugPrint('CollaborativeDocument: ignored ${message['type']}');
    }
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(values);
  }
}
