import 'dart:math';

import 'dex_models.dart';

/// One "who's that Pokémon" round: [answer] plus shuffled [choices] (4).
class SilhouetteQuestion {
  const SilhouetteQuestion({required this.answer, required this.choices});

  final PokemonSummary answer;
  final List<PokemonSummary> choices;
}

/// Draw a question from [pool]; [excludeIds] avoids repeating recent answers.
/// Returns null when the pool cannot fill four distinct choices.
SilhouetteQuestion? buildSilhouetteQuestion(
  List<PokemonSummary> pool,
  Random random, {
  Set<int> excludeIds = const {},
  int choiceCount = 4,
}) {
  if (pool.length < choiceCount) {
    return null;
  }

  final candidates = [
    for (final entry in pool)
      if (!excludeIds.contains(entry.id)) entry,
  ];
  final answerPool = candidates.isEmpty ? pool : candidates;
  final answer = answerPool[random.nextInt(answerPool.length)];

  final decoys = <PokemonSummary>[];
  final usedIds = <int>{answer.id};
  // Bounded attempts keep this safe on small pools with many duplicates.
  var attempts = 0;
  while (decoys.length < choiceCount - 1 && attempts < 200) {
    attempts += 1;
    final candidate = pool[random.nextInt(pool.length)];
    if (usedIds.add(candidate.id)) {
      decoys.add(candidate);
    }
  }
  if (decoys.length < choiceCount - 1) {
    return null;
  }

  final choices = [answer, ...decoys]..shuffle(random);
  return SilhouetteQuestion(answer: answer, choices: choices);
}
