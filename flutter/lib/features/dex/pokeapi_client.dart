import 'dart:convert';

import 'package:http/http.dart' as http;

import 'dex_game_scope.dart';
import 'dex_models.dart';
import 'dex_sprite_codec.dart';
import 'poke_api_throttle.dart';
import 'type_chart.dart';

class PokeApiClient {
  PokeApiClient({
    http.Client? client,
    PokeApiThrottle? throttle,
    this.maxRetries = 4,
  })  : _client = client ?? http.Client(),
        _throttle = throttle ?? PokeApiThrottle();

  final http.Client _client;
  final PokeApiThrottle _throttle;
  final int maxRetries;
  static const baseUrl = 'https://pokeapi.co/api/v2';

  final Map<String, TypeDamageRelations> _typeRelationsCache = {};

  Future<Map<String, dynamic>> _getJson(String path) {
    return _throttle.run(() => _getJsonWithRetry(path));
  }

  Future<List<dynamic>> _getJsonList(String path) {
    return _throttle.run(() => _getJsonListWithRetry(path));
  }

  Future<List<dynamic>> _getJsonListWithRetry(
    String path, {
    int attempt = 0,
  }) async {
    final response = await _client.get(Uri.parse('$baseUrl$path'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    if (attempt < maxRetries && pokeApiStatusShouldRetry(response.statusCode)) {
      await Future<void>.delayed(pokeApiRetryDelay(attempt));
      return _getJsonListWithRetry(path, attempt: attempt + 1);
    }
    throw PokeApiException(path, response.statusCode);
  }

  Future<Map<String, dynamic>> _getJsonWithRetry(
    String path, {
    int attempt = 0,
  }) async {
    final response = await _client.get(Uri.parse('$baseUrl$path'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    if (attempt < maxRetries && pokeApiStatusShouldRetry(response.statusCode)) {
      await Future<void>.delayed(pokeApiRetryDelay(attempt));
      return _getJsonWithRetry(path, attempt: attempt + 1);
    }
    throw PokeApiException(path, response.statusCode);
  }

  Future<Map<String, TypeDamageRelations>> loadAllTypeRelations() async {
    if (_typeRelationsCache.isNotEmpty) {
      return _typeRelationsCache;
    }

    final index = await _getJson('/type?limit=100');
    final results = index['results'] as List<dynamic>;

    for (final result in results) {
      final name = (result as Map<String, dynamic>)['name'] as String;
      if (!typeNamesZh.containsKey(name)) {
        continue;
      }
      final detail = await _getJson('/type/$name');
      final damage = detail['damage_relations'] as Map<String, dynamic>;
      _typeRelationsCache[name] = parseTypeDamageRelations(damage);
    }

    return _typeRelationsCache;
  }

  Future<PokemonSummary> fetchSummary(int id) async {
    final pokemon = await _getJson('/pokemon/$id');
    final species = await _getJson('/pokemon-species/$id');

    return PokemonSummary(
      id: pokemon['id'] as int,
      nameEn: _capitalize(pokemon['name'] as String),
      nameZh: _localizedName(
        species['names'] as List<dynamic>,
        fallback: pokemon['name'] as String,
      ),
      types: _extractTypes(pokemon['types'] as List<dynamic>),
      spriteUrl: _spriteUrl(pokemon['sprites'] as Map<String, dynamic>),
      artworkUrl: _artworkUrl(pokemon['sprites'] as Map<String, dynamic>) ??
          pokeApiOfficialArtworkUrl(pokemon['id'] as int),
    );
  }

  Future<PokemonDetail> fetchDetail(int id) => fetchDetailWithMoves(id);

  Future<PokemonDetail> fetchDetailWithMoves(int id) async {
    final pokemon = await _getJson('/pokemon/$id');
    final species = await _getJson('/pokemon-species/$id');
    final relations = await loadAllTypeRelations();

    final summary = PokemonSummary(
      id: pokemon['id'] as int,
      nameEn: _capitalize(pokemon['name'] as String),
      nameZh: _localizedName(
        species['names'] as List<dynamic>,
        fallback: pokemon['name'] as String,
      ),
      types: _extractTypes(pokemon['types'] as List<dynamic>),
      spriteUrl: _spriteUrl(pokemon['sprites'] as Map<String, dynamic>),
      artworkUrl: _artworkUrl(pokemon['sprites'] as Map<String, dynamic>) ??
          pokeApiOfficialArtworkUrl(pokemon['id'] as int),
    );

    final profile = computeDefensiveProfile(summary.types, relations);
    final stab = computeStabSuperEffective(summary.types, relations);
    final multipliers =
        computeDefensiveMultipliers(summary.types, relations);
    final baseStats = _parseBaseStats(pokemon['stats'] as List<dynamic>);
    final johtoDex = _johtoDexNumber(
      species['pokedex_numbers'] as List<dynamic>,
    );
    final flavorEntries = _parseFlavorEntries(
      species['flavor_text_entries'] as List<dynamic>,
    );
    final obtainLocations = await _fetchHgssObtainLocations(id);
    final abilities = await _fetchAbilities(pokemon['abilities'] as List<dynamic>);
    final moveSet = await _fetchHgssMoveSet(pokemon['moves'] as List<dynamic>);
    final genderFemalePercent = _genderFemalePercent(
      species['gender_rate'] as int?,
    );
    final eggGroups = _eggGroupsZh(species['egg_groups'] as List<dynamic>);
    final hatchCounter = species['hatch_counter'] as int?;

    final evolutionUrl = species['evolution_chain']?['url'] as String?;
    EvolutionNode? evolution;
    if (evolutionUrl != null) {
      evolution = await _fetchEvolutionChain(evolutionUrl);
    }

    return PokemonDetail(
      summary: summary,
      genusZh: _genusZh(species['genera'] as List<dynamic>),
      heightDm: pokemon['height'] as int? ?? 0,
      weightHg: pokemon['weight'] as int? ?? 0,
      weaknesses: profile.weaknesses,
      resistances: profile.resistances,
      immunities: profile.immunities,
      stabSuperEffective: stab,
      evolutionChain: evolution,
      johtoDexNumber: johtoDex,
      baseStats: baseStats,
      typeMultipliers: multipliers,
      flavorEntries: flavorEntries,
      obtainLocations: obtainLocations,
      abilities: abilities,
      moveSet: moveSet,
      genderFemalePercent: genderFemalePercent,
      eggGroups: eggGroups,
      hatchCounter: hatchCounter,
    );
  }

  PokemonBaseStats _parseBaseStats(List<dynamic> stats) {
    final values = <String, int>{};
    for (final entry in stats) {
      final map = entry as Map<String, dynamic>;
      final stat = map['stat'] as Map<String, dynamic>;
      values[stat['name'] as String] = map['base_stat'] as int? ?? 0;
    }
    return PokemonBaseStats(
      hp: values['hp'] ?? 0,
      attack: values['attack'] ?? 0,
      defense: values['defense'] ?? 0,
      specialAttack: values['special-attack'] ?? 0,
      specialDefense: values['special-defense'] ?? 0,
      speed: values['speed'] ?? 0,
    );
  }

  int? _johtoDexNumber(List<dynamic> entries) {
    for (final entry in entries) {
      final map = entry as Map<String, dynamic>;
      final pokedex = map['pokedex'] as Map<String, dynamic>;
      final name = pokedex['name'] as String;
      if (johtoPokedexNames.contains(name)) {
        return map['entry_number'] as int;
      }
    }
    return null;
  }

  List<FlavorTextEntry> _parseFlavorEntries(List<dynamic> entries) {
    final byVersion = <String, _FlavorBundle>{};
    String? referenceZhHans;
    String? referenceZhHant;

    for (final version in hgssFlavorVersions) {
      byVersion[version] = _FlavorBundle();
    }

    for (final entry in entries) {
      final map = entry as Map<String, dynamic>;
      final version =
          (map['version'] as Map<String, dynamic>)['name'] as String;
      final language =
          (map['language'] as Map<String, dynamic>)['name'] as String;
      final text = (map['flavor_text'] as String)
          .replaceAll('\n', ' ')
          .replaceAll('\f', ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (text.isEmpty) {
        continue;
      }

      switch (language) {
        case 'zh-Hans':
        case 'zh-hans':
          referenceZhHans ??= text;
          if (byVersion.containsKey(version)) {
            byVersion[version]!.zhHans ??= text;
          }
        case 'zh-Hant':
        case 'zh-hant':
          referenceZhHant ??= text;
          if (byVersion.containsKey(version)) {
            byVersion[version]!.zhHant ??= text;
          }
        case 'en':
          if (byVersion.containsKey(version)) {
            byVersion[version]!.english ??= text;
          }
      }
    }

    final results = <FlavorTextEntry>[];
    for (final version in hgssFlavorVersions) {
      final bundle = byVersion[version]!;
      final chosen = bundle.zhHans ?? bundle.zhHant ?? bundle.english;
      if (chosen != null) {
        results.add(FlavorTextEntry(version: version, text: chosen));
      }
    }

    final referenceChinese = referenceZhHans ?? referenceZhHant;
    final hgssHasChinese = results.any(
      (entry) => entry.version != 'zh-reference' && _looksChinese(entry.text),
    );
    if (referenceChinese != null && !hgssHasChinese) {
      results.insert(
        0,
        FlavorTextEntry(version: 'zh-reference', text: referenceChinese),
      );
    }

    return results;
  }

  bool _looksChinese(String text) {
    return RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
  }

  Future<List<PokemonAbility>> _fetchAbilities(List<dynamic> entries) async {
    final abilities = <PokemonAbility>[];
    for (final entry in entries) {
      final map = entry as Map<String, dynamic>;
      final abilityMap = map['ability'] as Map<String, dynamic>;
      final slug = abilityMap['name'] as String;
      final isHidden = map['is_hidden'] as bool? ?? false;
      abilities.add(await _fetchAbility(slug, isHidden: isHidden));
    }
    abilities.sort((a, b) {
      if (a.isHidden == b.isHidden) {
        return a.nameZh.compareTo(b.nameZh);
      }
      return a.isHidden ? 1 : -1;
    });
    return abilities;
  }

  final Map<String, PokemonAbility> _abilityCache = {};

  Future<PokemonAbility> _fetchAbility(
    String slug, {
    required bool isHidden,
  }) async {
    final cacheKey = '$slug:${isHidden ? 1 : 0}';
    if (_abilityCache.containsKey(cacheKey)) {
      return _abilityCache[cacheKey]!;
    }

    final detail = await _getJson('/ability/$slug');
    final ability = PokemonAbility(
      nameEn: _capitalize(detail['name'] as String),
      nameZh: _localizedName(
        detail['names'] as List<dynamic>,
        fallback: detail['name'] as String,
      ),
      descriptionZh: _abilityDescriptionZh(detail),
      isHidden: isHidden,
    );
    _abilityCache[cacheKey] = ability;
    return ability;
  }

  String _abilityDescriptionZh(Map<String, dynamic> detail) {
    for (final entry in detail['effect_entries'] as List<dynamic>? ?? const []) {
      final map = entry as Map<String, dynamic>;
      final language = (map['language'] as Map<String, dynamic>)['name'];
      if (language == 'zh-Hans' || language == 'zh-hans') {
        final short = (map['short_effect'] as String?)?.trim();
        if (short != null && short.isNotEmpty) {
          return short;
        }
        final effect = (map['effect'] as String?)?.trim();
        if (effect != null && effect.isNotEmpty) {
          return effect;
        }
      }
    }
    for (final entry in detail['flavor_text_entries'] as List<dynamic>? ??
        const []) {
      final map = entry as Map<String, dynamic>;
      final language = (map['language'] as Map<String, dynamic>)['name'];
      if (language == 'zh-Hans' || language == 'zh-hans') {
        final text = (map['flavor_text'] as String?)?.trim();
        if (text != null && text.isNotEmpty) {
          return text;
        }
      }
    }
    for (final entry in detail['effect_entries'] as List<dynamic>? ?? const []) {
      final map = entry as Map<String, dynamic>;
      if ((map['language'] as Map<String, dynamic>)['name'] == 'en') {
        final short = (map['short_effect'] as String?)?.trim();
        if (short != null && short.isNotEmpty) {
          return short;
        }
      }
    }
    return '';
  }

  Future<List<ObtainLocationEntry>> _fetchHgssObtainLocations(int id) async {
    try {
      final list = await _getJsonList('/pokemon/$id/encounters');
      final merged = <String, ObtainLocationEntry>{};

      for (final encounter in list) {
        final map = encounter as Map<String, dynamic>;
        final areaUrl = map['location_area']?['url'] as String?;
        if (areaUrl == null) {
          continue;
        }
        final slug = areaUrl.split('/').where((part) => part.isNotEmpty).last;
        var minLevel = 100;
        var maxChance = 0;
        var inHgss = false;

        for (final detail in map['version_details'] as List<dynamic>) {
          final detailMap = detail as Map<String, dynamic>;
          final version =
              (detailMap['version'] as Map<String, dynamic>)['name'] as String;
          if (version != 'heartgold' && version != 'soulsilver') {
            continue;
          }
          inHgss = true;
          final chance = detailMap['max_chance'] as int? ?? 0;
          if (chance > maxChance) {
            maxChance = chance;
          }
          for (final encounterDetail
              in detailMap['encounter_details'] as List<dynamic>? ?? const []) {
            final level = (encounterDetail
                    as Map<String, dynamic>)['min_level'] as int? ??
                100;
            if (level < minLevel) {
              minLevel = level;
            }
          }
        }

        if (!inHgss) {
          continue;
        }

        merged[slug] = ObtainLocationEntry(
          areaSlug: slug,
          areaLabelZh: resolveObtainAreaLabelZh(slug),
          minLevel: minLevel == 100 ? null : minLevel,
          maxChance: maxChance,
        );
      }

      final results = merged.values.toList()
        ..sort((a, b) => a.areaLabelZh.compareTo(b.areaLabelZh));
      return results;
    } catch (_) {
      return const [];
    }
  }

  Future<PokemonMoveSet> _fetchHgssMoveSet(List<dynamic> moveEntries) async {
    final levelUp = <int, PokemonMove>{};
    final machine = <int, PokemonMove>{};
    final egg = <int, PokemonMove>{};

    for (final entry in moveEntries) {
      final map = entry as Map<String, dynamic>;
      final move = map['move'] as Map<String, dynamic>;
      final details = map['version_group_details'] as List<dynamic>;

      for (final detail in details) {
        final detailMap = detail as Map<String, dynamic>;
        final versionGroup =
            (detailMap['version_group'] as Map<String, dynamic>)['name']
                as String;
        if (versionGroup != hgssVersionGroup) {
          continue;
        }
        final method =
            (detailMap['move_learn_method'] as Map<String, dynamic>)['name']
                as String;
        if (method != 'level-up' &&
            method != 'machine' &&
            method != 'egg') {
          continue;
        }

        final moveId = _tryIdFromUrl(move['url'] as String);
        if (moveId == null) {
          continue;
        }

        final level = detailMap['level_learned_at'] as int? ?? 0;
        final target = switch (method) {
          'level-up' => levelUp,
          'machine' => machine,
          _ => egg,
        };
        final existing = target[moveId];
        if (method == 'level-up' &&
            existing != null &&
            (existing.level ?? 0) <= level) {
          continue;
        }
        if (method != 'level-up' && existing != null) {
          continue;
        }

        final cachedMove = await _fetchMove(moveId);
        target[moveId] = PokemonMove(
          move: cachedMove,
          method: method,
          level: method == 'level-up' && level > 0 ? level : null,
        );
      }
    }

    final sortedLevelUp = levelUp.values.toList()
      ..sort((a, b) => (a.level ?? 0).compareTo(b.level ?? 0));
    final sortedMachine = machine.values.toList()
      ..sort((a, b) => a.move.nameZh.compareTo(b.move.nameZh));
    final sortedEgg = egg.values.toList()
      ..sort((a, b) => a.move.nameZh.compareTo(b.move.nameZh));

    return PokemonMoveSet(
      levelUp: sortedLevelUp,
      machine: sortedMachine,
      egg: sortedEgg,
    );
  }

  double? _genderFemalePercent(int? genderRate) {
    if (genderRate == null || genderRate < 0) {
      return null;
    }
    return genderRate / 8 * 100;
  }

  List<String> _eggGroupsZh(List<dynamic> groups) {
    const labels = <String, String>{
      'monster': '怪兽',
      'water1': '水中1',
      'bug': '虫',
      'flying': '飞行',
      'ground': '陆上',
      'fairy': '妖精',
      'plant': '植物',
      'humanshape': '人形',
      'water3': '水中3',
      'mineral': '矿物',
      'indeterminate': '不定形',
      'water2': '水中2',
      'ditto': '百变怪',
      'dragon': '龙',
      'no-eggs': '未发现',
    };
    return groups
        .map((entry) {
          final name = (entry as Map<String, dynamic>)['name'] as String;
          return labels[name] ?? name;
        })
        .toList();
  }

  final Map<int, CachedMove> _moveCache = {};

  void primeMoveCache(Map<int, CachedMove> moves) {
    _moveCache.addAll(moves);
  }

  Future<CachedMove> _fetchMove(int id) async {
    if (_moveCache.containsKey(id)) {
      return _moveCache[id]!;
    }
    final move = await _getJson('/move/$id');
    final cached = CachedMove(
      id: id,
      nameEn: _capitalize(move['name'] as String),
      nameZh: _localizedName(
        move['names'] as List<dynamic>,
        fallback: move['name'] as String,
      ),
      type: (move['type'] as Map<String, dynamic>)['name'] as String,
      category:
          (move['damage_class'] as Map<String, dynamic>)['name'] as String,
      power: move['power'] as int?,
      accuracy: move['accuracy'] as int?,
      pp: move['pp'] as int?,
    );
    _moveCache[id] = cached;
    return cached;
  }

  Future<int?> resolveSpeciesId(String speciesName) async {
    try {
      final pokemon = await _getJson('/pokemon/${speciesName.toLowerCase()}');
      return pokemon['id'] as int;
    } on PokeApiException {
      return null;
    }
  }

  Future<EvolutionNode> _fetchEvolutionChain(String url) async {
    return _throttle.run(() => _fetchEvolutionChainWithRetry(url));
  }

  Future<EvolutionNode> _fetchEvolutionChainWithRetry(
    String url, {
    int attempt = 0,
  }) async {
    final response = await _client.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final chain = jsonDecode(response.body) as Map<String, dynamic>;
      return _parseEvolutionNode(chain['chain'] as Map<String, dynamic>);
    }
    if (attempt < maxRetries && pokeApiStatusShouldRetry(response.statusCode)) {
      await Future<void>.delayed(pokeApiRetryDelay(attempt));
      return _fetchEvolutionChainWithRetry(url, attempt: attempt + 1);
    }
    throw PokeApiException(url, response.statusCode);
  }

  Future<EvolutionNode> _parseEvolutionNode(Map<String, dynamic> node) async {
    final species = node['species'] as Map<String, dynamic>;
    final speciesUrl = species['url'] as String;
    final speciesId = _idFromUrl(speciesUrl);
    final speciesDetail = await _getJson('/pokemon-species/$speciesId');
    final pokemon = await _getJson('/pokemon/$speciesId');

    String? triggerZh;
    final details = node['evolution_details'] as List<dynamic>?;
    if (details != null && details.isNotEmpty) {
      triggerZh = _evolutionTriggerZh(details.first as Map<String, dynamic>);
    }

    final children = <EvolutionNode>[];
    for (final child in node['evolves_to'] as List<dynamic>) {
      children.add(await _parseEvolutionNode(child as Map<String, dynamic>));
    }

    return EvolutionNode(
      id: speciesId,
      nameEn: _capitalize(species['name'] as String),
      nameZh: _localizedName(
        speciesDetail['names'] as List<dynamic>,
        fallback: species['name'] as String,
      ),
      spriteUrl: _spriteUrl(pokemon['sprites'] as Map<String, dynamic>),
      artworkUrl: _artworkUrl(pokemon['sprites'] as Map<String, dynamic>) ??
          pokeApiOfficialArtworkUrl(speciesId),
      evolvesFrom: triggerZh,
      triggerZh: triggerZh,
      children: children,
    );
  }

  List<String> _extractTypes(List<dynamic> types) {
    final sorted = List<Map<String, dynamic>>.from(types)
      ..sort(
        (a, b) => ((a['slot'] as int)).compareTo(b['slot'] as int),
      );
    return sorted
        .map(
          (entry) =>
              (entry['type'] as Map<String, dynamic>)['name'] as String,
        )
        .toList();
  }

  String? _artworkUrl(Map<String, dynamic> sprites) {
    final other = sprites['other'] as Map<String, dynamic>?;
    final artwork = other?['official-artwork'] as Map<String, dynamic>?;
    return artwork?['front_default'] as String?;
  }

  String? _spriteUrl(Map<String, dynamic> sprites) {
    return _artworkUrl(sprites) ?? sprites['front_default'] as String?;
  }

  String _localizedName(List<dynamic> names, {required String fallback}) {
    for (final entry in names) {
      final map = entry as Map<String, dynamic>;
      final language = map['language'] as Map<String, dynamic>;
      final code = language['name'] as String;
      if (code == 'zh-Hans' || code == 'zh-hans') {
        return map['name'] as String;
      }
    }
    for (final entry in names) {
      final map = entry as Map<String, dynamic>;
      final language = map['language'] as Map<String, dynamic>;
      if (language['name'] == 'zh-Hant') {
        return map['name'] as String;
      }
    }
    return _capitalize(fallback);
  }

  String _genusZh(List<dynamic> genera) {
    for (final entry in genera) {
      final map = entry as Map<String, dynamic>;
      final language = map['language'] as Map<String, dynamic>;
      final code = language['name'] as String;
      if (code == 'zh-Hans' || code == 'zh-hans') {
        return map['genus'] as String;
      }
    }
    if (genera.isNotEmpty) {
      return (genera.first as Map<String, dynamic>)['genus'] as String;
    }
    return '';
  }

  String? _evolutionTriggerZh(Map<String, dynamic> detail) {
    final minLevel = detail['min_level'] as int?;
    if (minLevel != null && minLevel > 0) {
      return 'Lv.$minLevel';
    }

    final item = detail['item'] as Map<String, dynamic>?;
    if (item != null) {
      return '道具：${_capitalize(item['name'] as String)}';
    }

    final trigger = detail['trigger'] as Map<String, dynamic>?;
    final triggerName = trigger?['name'] as String?;
    return switch (triggerName) {
      'level-up' => '升级',
      'use-item' => '使用道具',
      'trade' => '交换',
      'shed' => '蜕壳',
      'spin' => '旋转',
      'tower-of-darkness' => '恶之塔',
      'tower-of-waters' => '水之塔',
      'three-critical-hits' => '三次要害',
      'take-damage' => '受到伤害',
      'other' => '特殊条件',
      _ => triggerName != null ? _capitalize(triggerName) : null,
    };
  }

  int? _tryIdFromUrl(String url) {
    final segments = Uri.parse(url).pathSegments;
    for (var i = segments.length - 1; i >= 0; i--) {
      final id = int.tryParse(segments[i]);
      if (id != null) {
        return id;
      }
    }
    return null;
  }

  int _idFromUrl(String url) {
    final id = _tryIdFromUrl(url);
    if (id == null) {
      throw FormatException('No numeric id in PokeAPI url: $url');
    }
    return id;
  }

  String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value[0].toUpperCase() + value.substring(1);
  }
}

class _FlavorBundle {
  String? zhHans;
  String? zhHant;
  String? english;
}

class PokeApiException implements Exception {
  PokeApiException(this.path, this.statusCode);

  final String path;
  final int statusCode;

  @override
  String toString() => 'PokeAPI $statusCode for $path';
}
