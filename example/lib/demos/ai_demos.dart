import 'package:competition_toolkit/02_ui_elements/app_buttons.dart';
import 'package:competition_toolkit/14_ai/ai_assistant.dart';
import 'package:competition_toolkit/14_ai/ai_text_client.dart';
import 'package:flutter/material.dart';

import '../main.dart';

final aiDemos = <Demo>[
  Demo(
    'AI (with rule-based fallback)',
    'AI assistant',
    (_) => const _AiAssistantDemo(),
    subtitle: 'Scripted fake model — toggle it off to see fallbacks',
  ),
];

const _note =
    'Mitochondria are the powerhouse of the cell. They produce ATP through '
    'cellular respiration. My cat likes boxes. ATP stores the energy that '
    'cells use for almost every process. Cells with high energy needs, like '
    'muscle cells, contain many mitochondria.';

class _AiAssistantDemo extends StatefulWidget {
  const _AiAssistantDemo();

  @override
  State<_AiAssistantDemo> createState() => _AiAssistantDemoState();
}

class _AiAssistantDemoState extends State<_AiAssistantDemo> {
  bool _aiUp = true;
  final _results = <String, AiResult<Object?>>{};

  /// A scripted stand-in for the `ai-complete` Edge Function. **Not a real
  /// model**: replies are canned so the demo works offline.
  AiTextClient get _client => _aiUp
      ? FakeAiTextClient((request) {
          final system = request.system ?? '';
          if (system.startsWith('Summarize')) {
            return 'Mitochondria make ATP, the energy cells run on; '
                'energy-hungry cells have more of them.';
          }
          if (system.startsWith('Classify')) return 'Biology';
          return 'Nice work — 23% more study time than last week '
              '(140 min vs 114 min)!';
        })
      : FakeAiTextClient.failing();

  Future<void> _run(
    String name,
    Future<AiResult<Object?>> Function(AiAssistant) task,
  ) async {
    final result = await task(AiAssistant(_client));
    if (mounted) setState(() => _results[name] = result);
  }

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      SwitchListTile(
        title: const Text('AI service available'),
        subtitle: const Text('Off = every call fails, fallbacks take over'),
        value: _aiUp,
        onChanged: (v) => setState(() {
          _aiUp = v;
          _results.clear();
        }),
      ),
      _Task(
        title: 'Summarize a note',
        result: _results['summary'],
        onRun: () =>
            _run('summary', (ai) => ai.summarize(_note, maxSentences: 2)),
      ),
      _Task(
        title: 'Classify into your labels',
        result: _results['classify'],
        onRun: () => _run(
          'classify',
          (ai) => ai.classify(
            _note,
            labels: const {
              'Biology': ['cell', 'atp', 'mitochondria'],
              'History': ['war', 'empire'],
            },
            fallbackLabel: 'Other',
          ),
        ),
      ),
      _Task(
        title: 'Rephrase a rule-based insight',
        result: _results['rephrase'],
        onRun: () => _run(
          'rephrase',
          (ai) => ai.rephrase(
            'Your study time is 23% higher than last week (140 min vs 114 min).',
          ),
        ),
      ),
    ],
  );
}

class _Task extends StatelessWidget {
  const _Task({required this.title, required this.onRun, this.result});

  final String title;
  final VoidCallback onRun;
  final AiResult<Object?>? result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    return DemoBlock(
      title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppButton(
            label: 'Run',
            variant: ButtonVariant.tonal,
            onPressed: onRun,
          ),
          if (r != null) ...[
            const SizedBox(height: 8),
            Chip(
              avatar: Icon(
                r.usedFallback ? Icons.rule : Icons.auto_awesome,
                size: 16,
              ),
              label: Text(r.usedFallback ? 'Rule-based fallback' : 'AI'),
            ),
            Text('${r.value}'),
          ],
        ],
      ),
    );
  }
}
