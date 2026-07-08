import 'type_chart.dart';

// Data models for the national dex backed by PokeAPI.
class PokemonSummary {
  const PokemonSummary({
    required this.id,
    required this.nameEn,
    required this.nameZh,
    required this.types,
    required this.spriteUrl,
  });

  final int id;
  final String nameEn;
  final String nameZh;
  final List<String> types;
  final String? spriteUrl;

  String get typesLabel => types.map(typeNameZh).join('/');
}

enum DexEncounterStatus {
  caught,
  seen,
  unknown,
}

class PokemonDetail {
  const PokemonDetail({
    required this.summary,
    required this.genusZh,
    required this.heightDm,
    required this.weightHg,
    required this.weaknesses,
    required this.resistances,
    required this.immunities,
    required this.stabSuperEffective,
    required this.evolutionChain,
  });

  final PokemonSummary summary;
  final String genusZh;
  final int heightDm;
  final int weightHg;
  final List<String> weaknesses;
  final List<String> resistances;
  final List<String> immunities;
  final List<String> stabSuperEffective;
  final EvolutionNode? evolutionChain;
}

class EvolutionNode {
  const EvolutionNode({
    required this.id,
    required this.nameEn,
    required this.nameZh,
    required this.spriteUrl,
    this.evolvesFrom,
    this.triggerZh,
    this.children = const [],
  });

  final int id;
  final String nameEn;
  final String nameZh;
  final String? spriteUrl;
  final String? evolvesFrom;
  final String? triggerZh;
  final List<EvolutionNode> children;

  bool containsId(int pokemonId) {
    if (id == pokemonId) {
      return true;
    }
    return children.any((child) => child.containsId(pokemonId));
  }
}
