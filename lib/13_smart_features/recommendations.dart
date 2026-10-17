/// Recommendations: "you might also like…" from item tags (content-based),
/// from what other users did together (co-occurrence), with popularity as
/// a fallback for new users — each suggestion with a reason.
///
/// **Statistical, not AI.** Scores are counts and cosine similarities over
/// tags and interaction logs. No model is trained; results are fully
/// reproducible and explainable ("Because you liked Lentil soup").
///
/// Suits: recipes, courses, articles, events, products, study resources,
/// exercises, places to visit, people to follow.
///
/// ```dart
/// final recommender = Recommender<Recipe>(
///   idOf: (r) => r.id,
///   tagsOf: (r) => {...r.tags, r.cuisine, 'diet:${r.diet}'},
///   weights: const RecommenderWeights(content: 0.6, together: 0.3, popularity: 0.1),
/// );
/// final picks = recommender.recommend(
///   catalog: allRecipes,
///   liked: myFavouriteIds,
///   histories: everyonesFavourites,     // optional: List<Set<String>>, one per user
///   limit: 10,
/// );
/// picks.first.reason;   // "Similar to Lentil soup"
/// ```
library;

import 'dart:math' as math;

class RecommenderWeights {
  const RecommenderWeights({
    this.content = 0.6,
    this.together = 0.3,
    this.popularity = 0.1,
  });

  /// Tag similarity to what the user liked.
  final double content;

  /// "People who liked X also liked Y".
  final double together;

  /// How many people liked it overall (the cold-start fallback).
  final double popularity;
}

class Recommendation<T> {
  const Recommendation({
    required this.item,
    required this.score,
    required this.reason,
  });

  final T item;

  /// Blended 0…1 (relative — compare within one call only).
  final double score;
  final String reason;
}

class Recommender<T> {
  const Recommender({
    required this.idOf,
    required this.tagsOf,
    this.titleOf,
    this.weights = const RecommenderWeights(),
  });

  final String Function(T item) idOf;
  final Set<String> Function(T item) tagsOf;

  /// Used in reasons ("Similar to …"). Defaults to the id.
  final String Function(T item)? titleOf;
  final RecommenderWeights weights;

  /// Items the user has not [liked] or [exclude]d, best first.
  ///
  /// [histories]: what each user (including others) liked, as id sets — for
  /// the co-occurrence and popularity signals. Leave empty to use tags only.
  List<Recommendation<T>> recommend({
    required List<T> catalog,
    required Set<String> liked,
    List<Set<String>> histories = const [],
    Set<String> exclude = const {},
    int limit = 10,
  }) {
    final byId = {for (final item in catalog) idOf(item): item};
    final likedItems = [for (final id in liked) ?byId[id]];
    final popularity = _popularity(histories);
    final maxPopularity = popularity.values.fold<int>(0, math.max);
    final together = _coOccurrence(histories, liked);
    final maxTogether = together.values.fold<double>(0, math.max);

    final results = <Recommendation<T>>[];
    for (final item in catalog) {
      final id = idOf(item);
      if (liked.contains(id) || exclude.contains(id)) continue;

      // Content: best cosine similarity to any liked item.
      var bestSimilarity = 0.0;
      T? mostSimilar;
      for (final likedItem in likedItems) {
        final similarity = cosineSimilarity(tagsOf(item), tagsOf(likedItem));
        if (similarity > bestSimilarity) {
          bestSimilarity = similarity;
          mostSimilar = likedItem;
        }
      }
      final togetherScore = maxTogether == 0
          ? 0.0
          : (together[id] ?? 0) / maxTogether;
      final popularityScore = maxPopularity == 0
          ? 0.0
          : (popularity[id] ?? 0) / maxPopularity;

      final score =
          weights.content * bestSimilarity +
          weights.together * togetherScore +
          weights.popularity * popularityScore;
      if (score <= 0) continue;

      // The reason names the strongest contribution.
      final contributions = {
        'content': weights.content * bestSimilarity,
        'together': weights.together * togetherScore,
        'popular': weights.popularity * popularityScore,
      };
      final strongest = contributions.entries
          .reduce((a, b) => b.value > a.value ? b : a)
          .key;
      final reason = switch (strongest) {
        'content' => 'Similar to ${_title(mostSimilar as T)}',
        'together' => 'Often liked together with your favourites',
        _ => 'Popular right now',
      };
      results.add(Recommendation(item: item, score: score, reason: reason));
    }
    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(limit).toList();
  }

  /// Items similar to one item ("More like this").
  List<Recommendation<T>> similarTo(T item, List<T> catalog, {int limit = 5}) {
    final tags = tagsOf(item);
    final results = [
      for (final other in catalog)
        if (idOf(other) != idOf(item))
          Recommendation(
            item: other,
            score: cosineSimilarity(tags, tagsOf(other)),
            reason:
                'Shares ${tags.intersection(tagsOf(other)).take(3).join(', ')}',
          ),
    ]..removeWhere((r) => r.score == 0);
    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(limit).toList();
  }

  String _title(T item) => titleOf?.call(item) ?? idOf(item);

  Map<String, int> _popularity(List<Set<String>> histories) {
    final counts = <String, int>{};
    for (final history in histories) {
      for (final id in history) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// For each item, how strongly it co-occurs with the user's likes,
  /// normalised by how many items each history contains (so one user who
  /// liked everything counts for less).
  Map<String, double> _coOccurrence(
    List<Set<String>> histories,
    Set<String> liked,
  ) {
    final scores = <String, double>{};
    if (liked.isEmpty) return scores;
    for (final history in histories) {
      final overlap = history.intersection(liked).length;
      if (overlap == 0) continue;
      final weight = overlap / history.length;
      for (final id in history) {
        if (!liked.contains(id)) scores[id] = (scores[id] ?? 0) + weight;
      }
    }
    return scores;
  }
}

/// Cosine similarity of two tag sets treated as binary vectors:
/// |A ∩ B| / √(|A|·|B|). Case-insensitive. 0 when either is empty.
double cosineSimilarity(Set<String> a, Set<String> b) {
  if (a.isEmpty || b.isEmpty) return 0;
  final x = {for (final t in a) t.toLowerCase()};
  final y = {for (final t in b) t.toLowerCase()};
  return x.intersection(y).length / math.sqrt(x.length * y.length);
}
