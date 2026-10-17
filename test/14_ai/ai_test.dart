import 'package:competition_toolkit/10_backend/edge_function_client.dart';
import 'package:competition_toolkit/14_ai/ai_assistant.dart';
import 'package:competition_toolkit/14_ai/ai_text_client.dart';
import 'package:flutter_test/flutter_test.dart';

const _labels = {
  'food': ['lunch', 'grocer', 'cafe'],
  'transport': ['bus', 'uber', 'fuel'],
};

void main() {
  group('EdgeFunctionAiClient', () {
    test('sends the request and unwraps the envelope', () async {
      late Map<String, dynamic> sent;
      final client = EdgeFunctionAiClient(
        EdgeFunctionClient(
          invoke: (name, body) async {
            expect(name, 'ai-complete');
            sent = body;
            return {
              'ok': true,
              'data': {'text': 'Hi!'},
            };
          },
        ),
      );
      final reply = await client.complete(
        const AiRequest(prompt: 'Hello', system: 'Be brief', json: true),
      );
      expect(reply, 'Hi!');
      expect(sent, {
        'prompt': 'Hello',
        'system': 'Be brief',
        'maxTokens': 512,
        'json': true,
      });
    });

    test('server errors arrive as EdgeFunctionFailure', () {
      final client = EdgeFunctionAiClient(
        EdgeFunctionClient(
          invoke: (_, _) async => {
            'ok': false,
            'error': {
              'code': 'rate_limited',
              'message': 'Too many requests.',
              'retryable': true,
            },
          },
        ),
      );
      expect(
        client.complete(const AiRequest(prompt: 'x')),
        throwsA(
          isA<EdgeFunctionFailure>()
              .having((f) => f.code, 'code', 'rate_limited')
              .having((f) => f.retryable, 'retryable', true),
        ),
      );
    });
  });

  group('AiAssistant.summarize', () {
    const text =
        'Photosynthesis turns light into chemical energy. Plants use '
        'chlorophyll to absorb light. The weather was nice. Chemical energy '
        'from light is stored as glucose in plants.';

    test('uses the model and keeps user text inside markers', () async {
      final fake = FakeAiTextClient((_) => 'Plants store light as glucose.');
      final result = await AiAssistant(fake).summarize(text, maxSentences: 1);
      expect(result.source, AiSource.ai);
      expect(result.value, 'Plants store light as glucose.');
      expect(fake.requests.single.prompt, startsWith('<<<'));
      expect(fake.requests.single.system, contains('at most 1 sentences'));
    });

    test('falls back to an extractive summary on failure', () async {
      final result = await AiAssistant(
        FakeAiTextClient.failing(),
      ).summarize(text, maxSentences: 2);
      expect(result.usedFallback, isTrue);
      expect(result.error, isA<EdgeFunctionFailure>());
      expect(result.value, isNot(contains('weather')));
    });

    test('disabled AI never calls the client', () async {
      final fake = FakeAiTextClient((_) => 'x');
      final result = await AiAssistant(fake, enabled: false).summarize(text);
      expect(result.usedFallback, isTrue);
      expect(fake.requests, isEmpty);
    });
  });

  group('AiAssistant.classify', () {
    test('accepts only known labels', () async {
      final ok = await AiAssistant(
        FakeAiTextClient((_) => ' "Food." '),
      ).classify('Lunch at the cafe', labels: _labels, fallbackLabel: 'other');
      expect((ok.value, ok.source), ('food', AiSource.ai));

      final invented = await AiAssistant(
        FakeAiTextClient((_) => 'Entertainment'),
      ).classify('Uber to work', labels: _labels, fallbackLabel: 'other');
      expect(
        (invented.value, invented.source),
        ('transport', AiSource.fallback),
      );

      final nothing = await AiAssistant(
        FakeAiTextClient.failing(),
      ).classify('Cinema', labels: _labels, fallbackLabel: 'other');
      expect(nothing.value, 'other');
    });
  });

  group('AiAssistant.extractFields', () {
    test('keeps only requested keys and tolerates code fences', () async {
      final result =
          await AiAssistant(
            FakeAiTextClient(
              (_) => '```json\n{"title": "Barista", "pay": 12, "hack": 1}\n```',
            ),
          ).extractFields(
            'Barista wanted, £12/h',
            fields: {'title': 'job title', 'pay': 'hourly pay', 'city': 'city'},
          );
      expect(result.source, AiSource.ai);
      expect(result.value, {'title': 'Barista', 'pay': 12, 'city': null});
    });

    test('invalid JSON gives an empty map', () async {
      final result = await AiAssistant(
        FakeAiTextClient((_) => 'Sure! The title is Barista.'),
      ).extractFields('x', fields: {'title': 'job title'});
      expect(result.value, isEmpty);
      expect(result.error, isA<FormatException>());
    });
  });

  group('AiAssistant.rephrase', () {
    const fact = 'You studied 23% more than last week (140 min vs 114 min).';

    test('accepts rewording that keeps every number', () async {
      final result = await AiAssistant(
        FakeAiTextClient(
          (_) => 'Great job — 140 min this week, 23% up on the 114 min before!',
        ),
      ).rephrase(fact);
      expect(result.source, AiSource.ai);
    });

    test('rejects a reply that changed the numbers', () async {
      final result = await AiAssistant(
        FakeAiTextClient((_) => 'Amazing — you studied 30% more!'),
      ).rephrase(fact);
      expect(result.usedFallback, isTrue);
      expect(result.value, fact);
    });
  });

  group('rule-based helpers', () {
    test('extractiveSummary', () {
      expect(extractiveSummary('One. Two.', maxSentences: 3), 'One. Two.');
      final summary = extractiveSummary(
        'Cats sleep a lot. Cats hunt mice at night. Taxes are due. '
        'Cats groom themselves.',
        maxSentences: 2,
      );
      // "cats" is the most frequent word; sentences stay in original order.
      expect(summary, 'Cats sleep a lot. Cats groom themselves.');
    });

    test('keywordClassify, matchLabel and numbersIn', () {
      expect(keywordClassify('Fuel and bus fare', _labels), 'transport');
      expect(keywordClassify('Cinema', _labels), isNull);
      expect(matchLabel('Label: transport', _labels.keys), 'transport');
      expect(matchLabel('food or transport', _labels.keys), isNull);
      expect(numbersIn('23% of 1,200 is 276.0'), {'23', '1200', '276.0'});
    });
  });
}
