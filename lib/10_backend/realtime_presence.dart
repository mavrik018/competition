/// "Who is online right now" for a shared room (a couple, a team, a
/// document), using Supabase Realtime Presence.
///
/// Source: Couple `features/presence/data/couple_presence_channel.dart`. Kept:
/// a private channel, re-announcing presence from scratch after a reconnect
/// instead of assuming it survived the gap, and exposing the result as a
/// stream of user-id sets. Generalised from `couple:{id}` to any room name,
/// and the presence parsing was pulled into [onlineIdsFrom] for testing.
///
/// ```dart
/// final room = PresenceRoom(client, room: 'team:$teamId', userId: uid)..join();
/// StreamBuilder(stream: room.onlineUserIds, builder: …);
/// // after connectivity returns:
/// room.rejoin();
/// // when leaving the screen:
/// room.leave();
/// ```
///
/// A private channel needs a Realtime authorization policy on
/// `realtime.messages` allowing members of the room.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PresenceRoom {
  PresenceRoom(
    this._client, {
    required this.room,
    required this.userId,
    this.isPrivate = true,
  });

  final SupabaseClient _client;
  final String room;
  final String userId;
  final bool isPrivate;

  RealtimeChannel? _channel;
  final _online = StreamController<Set<String>>.broadcast();

  /// Emits the full set of online user ids after every presence sync.
  Stream<Set<String>> get onlineUserIds => _online.stream;

  void join() {
    final channel = _client.channel(
      room,
      opts: RealtimeChannelConfig(private: isPrivate),
    );
    channel.onPresenceSync((_) {
      final payloads = channel
          .presenceState()
          .expand((state) => state.presences)
          .map((presence) => presence.payload);
      if (!_online.isClosed) _online.add(onlineIdsFrom(payloads));
    });
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        channel.track({
          'user_id': userId,
          'online_at': DateTime.now().toUtc().toIso8601String(),
        });
      } else if (error != null) {
        debugPrint('PresenceRoom($room): $status $error');
      }
    });
    _channel = channel;
  }

  /// Drops and re-creates the subscription — call when connectivity returns.
  Future<void> rejoin() async {
    await _channel?.unsubscribe();
    join();
  }

  Future<void> leave() async {
    await _channel?.unsubscribe();
    _channel = null;
    await _online.close();
  }
}

/// The distinct `user_id`s in a set of presence payloads.
Set<String> onlineIdsFrom(Iterable<Map<String, dynamic>> payloads) =>
    payloads.map((payload) => payload['user_id']).whereType<String>().toSet();
