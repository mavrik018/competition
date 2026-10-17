// Mini-app 3 — Shared shopping list.
//
// Puzzle pieces: CollaborativeDocument + InMemoryCollabHub (13 real-time
// CRDT) · VoiceInputButton + FakeSpeechInput + VoiceCommandParser (13) ·
// OfflineBanner (03) · EmptyView (03) · AppTextField (02).
//
// Both "phones" run in this one app over an in-memory hub — a labelled
// test double. On real devices, give each phone a SupabaseBroadcastTransport
// with the same channel name.

import 'dart:async';

import 'package:competition_toolkit/02_ui_elements/text_inputs.dart';
import 'package:competition_toolkit/03_feedback/offline_banner.dart';
import 'package:competition_toolkit/03_feedback/state_views.dart';
import 'package:competition_toolkit/09_persistence/local_id.dart';
import 'package:competition_toolkit/13_smart_features/realtime_collaboration.dart';
import 'package:competition_toolkit/13_smart_features/voice_input.dart';
import 'package:flutter/material.dart';

const _parser = VoiceCommandParser([
  VoiceIntent('add', ['add {item}', 'we need {item}', 'buy {item}']),
]);

class SharedListApp extends StatefulWidget {
  const SharedListApp({super.key, this.speech});

  /// Injected for tests; defaults to a scripted fake.
  final SpeechInput? speech;

  @override
  State<SharedListApp> createState() => _SharedListAppState();
}

class _SharedListAppState extends State<SharedListApp> {
  final _hub = InMemoryCollabHub();
  late final _mine = CollaborativeDocument(
    replicaId: 'my-phone',
    transport: _hub.transport(),
  );
  late final _partner = CollaborativeDocument(
    replicaId: 'partner-phone',
    transport: _hub.transport(),
  );
  late final SpeechInput _speech =
      widget.speech ??
      FakeSpeechInput(['add oat milk', 'we need bananas', 'buy coffee']);
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _input = TextEditingController();
  bool _online = true;
  String? _heard;

  @override
  void initState() {
    super.initState();
    for (final doc in [_mine, _partner]) {
      _subscriptions.add(doc.changes.listen((_) => setState(() {})));
      unawaited(doc.connect());
    }
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    unawaited(_mine.dispose());
    unawaited(_partner.dispose());
    _input.dispose();
    super.dispose();
  }

  Future<void> _add(CollaborativeDocument doc, String title) async {
    final clean = title.trim();
    if (clean.isEmpty) return;
    await doc.set('item:${generateLocalId()}', {'title': clean, 'done': false});
  }

  void _setOnline(bool online) {
    setState(() {
      _online = online;
      _hub.holdMessages = !online;
      if (online) _hub.deliverHeld();
    });
  }

  void _onVoice(String text) {
    final command = _parser.parse(text, now: DateTime.now());
    setState(() => _heard = command == null ? 'Not understood: "$text"' : null);
    if (command != null) unawaited(_add(_mine, command.slots['item']!));
  }

  @override
  Widget build(BuildContext context) {
    final items = _mine.values.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared list'),
        actions: [
          Row(
            children: [
              const Text('Online'),
              Switch(value: _online, onChanged: _setOnline),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          OfflineBanner(isOnline: _online),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _input,
                    label: 'Add an item',
                    textInputAction: TextInputAction.done,
                    onSubmitted: (v) {
                      unawaited(_add(_mine, v));
                      _input.clear();
                    },
                  ),
                ),
                VoiceInputButton(speech: _speech, onResult: _onVoice),
              ],
            ),
          ),
          if (_heard != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_heard!),
            ),
          Expanded(
            child: items.isEmpty
                ? const EmptyView(
                    icon: Icons.shopping_basket_outlined,
                    title: 'The list is empty',
                    message: 'Type, speak, or let your partner add something.',
                  )
                : ListView(
                    children: [
                      for (final MapEntry(:key, :value) in items)
                        if (value case {
                          'title': final String title,
                          'done': final bool done,
                        })
                          CheckboxListTile(
                            value: done,
                            title: Text(title),
                            onChanged: (v) => _mine.set(key, {
                              'title': title,
                              'done': v ?? false,
                            }),
                            secondary: IconButton(
                              tooltip: 'Remove $title',
                              icon: const Icon(Icons.close),
                              onPressed: () => _mine.remove(key),
                            ),
                          ),
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.phone_android),
                label: Text(
                  "Partner adds 'Bread' (partner sees ${_partner.values.length} items)",
                ),
                onPressed: () => _add(_partner, 'Bread'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
