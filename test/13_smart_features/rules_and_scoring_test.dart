import 'package:competition_toolkit/13_smart_features/priority_scoring.dart';
import 'package:competition_toolkit/13_smart_features/recommendations.dart';
import 'package:competition_toolkit/13_smart_features/risk_scoring.dart';
import 'package:competition_toolkit/13_smart_features/rule_conditions.dart';
import 'package:competition_toolkit/13_smart_features/smart_matching.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Item = ({String id, Set<String> tags});
typedef Student = ({Set<String> subjects, double maxRate});
typedef Tutor = ({String name, Set<String> subjects, double rate});

void main() {
  group('Condition', () {
    final rule = Condition.fromJson({
      'all': [
        {'field': 'age', 'op': '>=', 'value': 65},
        {
          'any': [
            {'field': 'conditions', 'op': 'contains', 'value': 'diabetes'},
            {'field': 'bmi', 'op': '>', 'value': 30},
          ],
        },
      ],
    });

    test('evaluates nested all/any', () {
      expect(rule.evaluate({'age': 70, 'bmi': 31, 'conditions': []}), isTrue);
      expect(
        rule.evaluate({
          'age': 70,
          'bmi': 22,
          'conditions': ['Diabetes'],
        }),
        isTrue,
      );
      expect(rule.evaluate({'age': 60, 'bmi': 31}), isFalse);
    });

    test('describes itself and survives a JSON round trip', () {
      const text = '(age ≥ 65 and (conditions contains diabetes or bmi > 30))';
      expect(rule.describe(), text);
      expect(Condition.fromJson(rule.toJson()).describe(), text);
    });

    test('missing facts are false except not_exists', () {
      const lt = FieldCondition('x', Op.lt, 3);
      expect(lt.evaluate({}), isFalse);
      expect(const FieldCondition('x', Op.notExists).evaluate({}), isTrue);
      expect(const FieldCondition('x', Op.exists).evaluate({'x': 0}), isTrue);
      // Not() inverts that — document it to users of `not`.
      expect(const Not(lt).evaluate({}), isTrue);
    });

    test('strings compare case-insensitively', () {
      expect(
        const FieldCondition(
          'name',
          Op.eq,
          'hello',
        ).evaluate({'name': 'HeLLo'}),
        isTrue,
      );
      expect(
        const FieldCondition(
          'note',
          Op.notContains,
          'URGENT',
        ).evaluate({'note': 'not urgent at all'}),
        isFalse,
      );
    });

    test('dates compare against ISO strings', () {
      const before = FieldCondition('due', Op.lt, '2026-01-01');
      expect(before.evaluate({'due': DateTime(2025, 12, 1)}), isTrue);
      expect(before.evaluate({'due': DateTime(2026, 2, 1)}), isFalse);
    });

    test('between, in, not_in and dotted paths', () {
      const range = FieldCondition('n', Op.between, [1, 5]);
      expect(range.evaluate({'n': 5}), isTrue);
      expect(range.evaluate({'n': 6}), isFalse);
      expect(
        const FieldCondition('c', Op.isIn, [
          'red',
          'blue',
        ]).evaluate({'c': 'Blue'}),
        isTrue,
      );
      expect(
        const FieldCondition('c', Op.notIn, ['red']).evaluate({'c': 'green'}),
        isTrue,
      );
      expect(
        const FieldCondition('user.address.city', Op.eq, 'Oslo').evaluate({
          'user': {
            'address': {'city': 'Oslo'},
          },
        }),
        isTrue,
      );
      expect(readFact({'a': 1}, 'a.b'), isNull);
    });

    test('malformed JSON fails loudly', () {
      expect(
        () => Condition.fromJson({'field': 'x', 'op': '~=', 'value': 1}),
        throwsFormatException,
      );
      expect(() => Condition.fromJson({'foo': 1}), throwsFormatException);
      expect(() => Condition.fromJson({'all': 'nope'}), throwsFormatException);
    });
  });

  group('smart matching helpers', () {
    test('set and range scores', () {
      expect(jaccard({'a', 'b'}, {'B', 'c'}), closeTo(1 / 3, 1e-9));
      expect(jaccard(<String>{}, <String>{}), 0);
      expect(coverage(['x', 'y'], ['X']), 0.5);
      expect(coverage([], ['x']), 1);
      expect(proximityScore(5, maxKm: 10), 0.5);
      expect(proximityScore(20, maxKm: 10), 0);
      expect(closeness(8, 10, tolerance: 4), 0.5);
      expect(rangeOverlap(9, 17, 13, 20), 0.5);
    });

    test('edit distance and text similarity', () {
      expect(levenshtein('kitten', 'sitting'), 3);
      expect(levenshtein('', 'abc'), 3);
      expect(textSimilarity('recieve', 'Receive'), closeTo(5 / 7, 1e-9));
      expect(textSimilarity('', ''), 1);
    });
  });

  group('Matcher', () {
    final matcher = SmartMatcher<Student, Tutor>([
      MatchCriterion(
        'Subjects',
        weight: 3,
        required: true,
        score: (s, t) => coverage(s.subjects, t.subjects),
      ),
      MatchCriterion('Budget', score: (s, t) => t.rate <= s.maxRate ? 1 : 0),
    ], minScore: 0.5);

    const student = (subjects: {'maths', 'physics'}, maxRate: 20.0);
    const ana = (name: 'Ana', subjects: {'Maths', 'Physics'}, rate: 25.0);
    const ben = (name: 'Ben', subjects: {'maths'}, rate: 15.0);
    const cy = (name: 'Cy', subjects: {'history'}, rate: 10.0);
    const dee = (name: 'Dee', subjects: {'maths', 'physics'}, rate: 25.0);

    test('required criterion excludes, ranking is stable and explained', () {
      expect(matcher.score(student, cy), isNull);
      final ranked = matcher.rank(student, [ana, ben, cy, dee]);
      // Ana and Dee both 0.75 (keep input order), Ben 0.625.
      expect([for (final r in ranked) r.candidate.name], ['Ana', 'Dee', 'Ben']);
      expect(ranked.first.percent, 75);
      expect(ranked.first.explanation, 'Subjects 100%, Budget 0%');
      expect(ranked.first.strengths(), ['Subjects']);
      expect(matcher.rank(student, [ana, ben, dee], limit: 1), hasLength(1));
    });

    test('minScore drops weak matches', () {
      const strict = SmartMatcher<Student, Tutor>([
        MatchCriterion('Subjects', score: _subjects),
      ], minScore: 0.9);
      expect(strict.rank(student, [ben]), isEmpty);
    });

    test('assignOneToOne pairs greedily without reuse', () {
      const physicsOnly = (subjects: {'physics'}, maxRate: 30.0);
      const mathsOnly = (subjects: {'maths'}, maxRate: 20.0);
      final pairs = matcher.assignOneToOne(
        [physicsOnly, mathsOnly],
        [ben, ana],
      );
      expect(pairs, hasLength(2));
      final byStudent = {for (final (s, r) in pairs) s: r.candidate.name};
      expect(byStudent[mathsOnly], 'Ben');
      expect(byStudent[physicsOnly], 'Ana');
    });
  });

  group('Recommender', () {
    const a = (id: 'a', tags: {'soup', 'vegan'});
    const b = (id: 'b', tags: {'soup', 'vegan', 'quick'});
    const c = (id: 'c', tags: {'pasta'});
    const d = (id: 'd', tags: {'Soup'});
    final recommender = Recommender<Item>(
      idOf: (i) => i.id,
      tagsOf: (i) => i.tags,
    );

    test('content-based picks with reasons', () {
      final picks = recommender.recommend(catalog: [a, b, c, d], liked: {'a'});
      expect([for (final p in picks) p.item.id], ['b', 'd']);
      expect(picks.first.reason, 'Similar to a');
    });

    test('cold start falls back to popularity', () {
      final picks = recommender.recommend(
        catalog: [a, b, c, d],
        liked: {},
        histories: [
          {'c'},
          {'c', 'd'},
        ],
      );
      expect([for (final p in picks) p.item.id], ['c', 'd']);
      expect(picks.first.reason, 'Popular right now');
    });

    test('co-occurrence and exclusions', () {
      final histories = [
        {'a', 'c'},
        {'a', 'c'},
        {'b'},
      ];
      final picks = recommender.recommend(
        catalog: [a, b, c, d],
        liked: {'a'},
        histories: histories,
      );
      final pc = picks.firstWhere((p) => p.item.id == 'c');
      expect(pc.reason, 'Often liked together with your favourites');
      final excluded = recommender.recommend(
        catalog: [a, b, c, d],
        liked: {'a'},
        histories: histories,
        exclude: {'c'},
      );
      expect(excluded.map((p) => p.item.id), isNot(contains('c')));
    });

    test('similarTo and cosine similarity', () {
      expect(cosineSimilarity({'a'}, {}), 0);
      expect(cosineSimilarity({'A', 'b'}, {'a', 'b'}), closeTo(1, 1e-9));
      final similar = recommender.similarTo(a, [a, b, c, d]);
      expect([for (final s in similar) s.item.id], ['b', 'd']);
      expect(similar.first.reason, startsWith('Shares'));
    });
  });

  group('priority scoring', () {
    final now = DateTime(2026, 3, 10, 12);

    test('overdue and important is critical', () {
      final p = scorePriority(
        PriorityInput(due: DateTime(2026, 3, 9, 12), importance: 5),
        now: now,
      );
      expect(p.band, PriorityBand.critical);
      expect(p.score, greaterThanOrEqualTo(80));
      expect(p.reasons, contains('Overdue'));
    });

    test('weighted score with reasons', () {
      final p = scorePriority(
        PriorityInput(
          due: now.add(const Duration(hours: 36)),
          importance: 4,
          effortHours: 0.5,
          createdAt: now.subtract(const Duration(days: 40)),
        ),
        now: now,
      );
      // 0.5·(1 − 36/168) + 0.35·0.75 + 0.1·1 + 0.05·1 = 0.805
      expect(p.score, 81);
      expect(p.band, PriorityBand.critical);
      expect(p.reasons, [
        'Due in 2 days',
        'Importance 4/5',
        'Quick win',
        'Waiting 40 days',
      ]);
      expect(
        scorePriority(const PriorityInput(importance: 1), now: now).band,
        PriorityBand.low,
      );
    });

    test('rules are configurable', () {
      const importanceOnly = PriorityRules(
        urgencyWeight: 0,
        quickWinWeight: 0,
        ageWeight: 0,
      );
      final p = scorePriority(
        const PriorityInput(importance: 5),
        now: now,
        rules: importanceOnly,
      );
      expect(p.score, 100);
    });

    test('rankByPriority is stable and eisenhower classifies', () {
      final tasks = [
        ('later', const PriorityInput(importance: 2)),
        ('urgent', PriorityInput(due: now, importance: 5)),
        ('later2', const PriorityInput(importance: 2)),
      ];
      final ranked = rankByPriority(tasks, (t) => t.$2, now: now);
      expect(
        [for (final (t, _) in ranked) t.$1],
        ['urgent', 'later', 'later2'],
      );

      final soon = now.add(const Duration(days: 1));
      expect(
        eisenhowerQuadrant(PriorityInput(due: soon, importance: 5), now: now),
        EisenhowerQuadrant.doFirst,
      );
      expect(
        eisenhowerQuadrant(const PriorityInput(importance: 5), now: now),
        EisenhowerQuadrant.schedule,
      );
      expect(
        eisenhowerQuadrant(PriorityInput(due: soon, importance: 2), now: now),
        EisenhowerQuadrant.delegate,
      );
      expect(
        eisenhowerQuadrant(const PriorityInput(importance: 2), now: now),
        EisenhowerQuadrant.eliminate,
      );
    });
  });

  group('RiskModel', () {
    final json = {
      'levels': {'moderate': 3, 'high': 6, 'severe': 9},
      'rules': [
        {
          'id': 'late',
          'label': '3+ late submissions',
          'points': 2,
          'when': {'field': 'lateSubmissions', 'op': '>=', 'value': 3},
        },
        {
          'id': 'attendance',
          'label': 'Attendance under 75%',
          'points': 3,
          'when': {'field': 'attendance', 'op': '<', 'value': 0.75},
        },
        {
          'id': 'grades',
          'label': 'Grade average dropping',
          'points': 4,
          'when': {'field': 'gradeTrend', 'op': '<', 'value': -0.1},
        },
        {
          'id': 'mentor',
          'label': 'Has a mentor',
          'points': -2,
          'when': {'field': 'hasMentor', 'op': '==', 'value': true},
        },
      ],
    };
    final model = RiskModel.fromJson(json);

    test('adds points, picks a level and explains biggest first', () {
      final r = model.assess({
        'attendance': 0.7,
        'lateSubmissions': 4,
        'gradeTrend': 0.0,
      });
      expect(r.points, 5);
      expect(r.level, RiskLevel.moderate);
      expect(r.reasons, ['Attendance under 75%', '3+ late submissions']);
      expect(r.maxPoints, 9);
      expect(r.fraction, closeTo(5 / 9, 1e-9));
    });

    test('protective factors and missing data', () {
      final r = model.assess({
        'attendance': 0.5,
        'gradeTrend': -0.3,
        'hasMentor': true,
      });
      expect(r.points, 5);
      expect(model.assess({}).level, RiskLevel.low);
      expect(
        model.assess({'gradeTrend': -1, 'attendance': 0}).level,
        RiskLevel.high,
      );
    });

    test('round-trips JSON and rejects bad rules', () {
      final copy = RiskModel.fromJson(model.toJson());
      expect(copy.rules, hasLength(4));
      expect(copy.assess({'attendance': 0.5}).points, 3);
      expect(
        () => RiskModel.fromJson({
          'rules': [
            {
              'id': 'x',
              'points': 1,
              'when': {'field': 'a', 'op': '??', 'value': 1},
            },
          ],
        }),
        throwsFormatException,
      );
    });
  });
}

double _subjects(Student s, Tutor t) => coverage(s.subjects, t.subjects);
