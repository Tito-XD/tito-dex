import 'package:flutter/material.dart';

import '../../models/journey.dart';
import '../dex/ability_type_modifiers.dart';
import '../dex/battle_effectiveness.dart';
import '../dex/dex_models.dart';
import '../dex/dex_repository.dart';
import 'battle_math.dart';

/// A calculation draft owned by one visit to the battle toolbox. It never
/// writes back to the saved party.
class BattleSession extends ChangeNotifier {
  BattleSession({int level = 50})
    : attacker = BattleCombatant(level: level),
      defender = BattleCombatant(level: level, types: const ['fire']) {
    attacker.addListener(notifyListeners);
    defender.addListener(notifyListeners);
  }

  final BattleCombatant attacker;
  final BattleCombatant defender;
  MoveCategory category = MoveCategory.physical;
  bool teamMode = false;
  List<PartyMember>? _party;
  Future<List<BattlePartyEntry>>? _partyFuture;
  final _partyDrafts = <BattleCombatant>[];
  List<BattlePartyEntry>? _entries;
  int teamCount(List<PartyMember> source) => _entries?.length ?? source.length;
  bool _disposed = false;

  void teamChanged() => notifyListeners();

  Future<void> addTeamMember(
    List<PartyMember> party,
    BattlePartyEntry entry,
  ) async {
    final entries = await partyEntries(party);
    if (_disposed || entries.length >= 6) return;
    _partyDrafts.add(entry.combatant);
    entry.combatant.addListener(teamChanged);
    entries.add(entry);
    notifyListeners();
  }

  Future<void> removeTeamMember(
    List<PartyMember> party,
    BattlePartyEntry entry,
  ) async {
    final entries = await partyEntries(party);
    if (_disposed) return;
    entries.remove(entry);
    notifyListeners();
  }

  /// One snapshot per toolbox visit, shared by stats and damage tabs.
  Future<List<BattlePartyEntry>> partyEntries(List<PartyMember> party) {
    if (identical(_party, party) && _partyFuture != null) return _partyFuture!;
    _party = party;
    final drafts = [for (final _ in party) BattleCombatant(level: 50)];
    _partyDrafts.addAll(drafts);
    return _partyFuture = _loadParty(party, drafts);
  }

  Future<List<BattlePartyEntry>> _loadParty(
    List<PartyMember> party,
    List<BattleCombatant> drafts,
  ) async {
    // Move loading errors must not invalidate the ability-value comparison.
    final moves = _loadPartyMoves(party);
    await Future.wait([
      for (var i = 0; i < party.length; i++) drafts[i].selectParty(party[i]),
    ]);
    final catalog = await moves;
    if (!_disposed) {
      for (final draft in drafts) {
        draft.addListener(teamChanged);
      }
    }
    final entries = [
      for (var i = 0; i < party.length; i++)
        BattlePartyEntry(party[i], drafts[i], {
          for (final id in party[i].moveIds.where((id) => id > 0))
            id: catalog[id],
        }),
    ];
    if (identical(_party, party)) _entries = entries;
    return entries;
  }

  Future<Map<int, CachedMove>> _loadPartyMoves(List<PartyMember> party) async {
    if (!party.any((m) => m.moveIds.any((id) => id > 0))) return {};
    try {
      return {
        for (final move in await dexRepository.getAllMoves()) move.id: move,
      };
    } catch (_) {
      return {}; // Preserve assigned IDs so missing moves are visible.
    }
  }

  void changed() {
    attacker.refreshStats();
    defender.refreshStats();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    attacker.removeListener(notifyListeners);
    defender.removeListener(notifyListeners);
    attacker.dispose();
    defender.dispose();
    for (final draft in _partyDrafts) {
      draft.dispose();
    }
    super.dispose();
  }
}

class BattlePartyEntry {
  const BattlePartyEntry(this.member, this.combatant, this.moves);
  final PartyMember member;
  final BattleCombatant combatant;
  final Map<int, CachedMove?> moves;
  String get name => combatant.query.text.isEmpty
      ? member.nickname ?? member.species
      : combatant.query.text;
}

class BattleCombatant extends ChangeNotifier {
  BattleCombatant({required int level, this.types = const []})
    : defaultLevel = level,
      level = TextEditingController(text: '$level') {
    for (final stat in BattleStat.values) {
      base[stat] = TextEditingController(text: '100');
      iv[stat] = TextEditingController(text: '31');
      ev[stat] = TextEditingController(text: '0');
      raw[stat] = TextEditingController();
      for (final controller in [base[stat]!, iv[stat]!, ev[stat]!]) {
        controller.addListener(_inputsChanged);
      }
      var previousText = '';
      raw[stat]!.addListener(() {
        final text = raw[stat]!.text;
        if (text == previousText) return;
        previousText = text;
        if (_updating) return;
        overrides.add(stat);
        notifyListeners();
      });
    }
    this.level.addListener(_inputsChanged);
    refreshStats();
  }

  final int defaultLevel;
  final query = TextEditingController();
  final TextEditingController level;
  final base = <BattleStat, TextEditingController>{};
  final iv = <BattleStat, TextEditingController>{};
  final ev = <BattleStat, TextEditingController>{};

  /// Unmodified, nature-adjusted stats. Damage applies battle bonuses once.
  final raw = <BattleStat, TextEditingController>{};
  final overrides = <BattleStat>{};
  final _fingerprints = <BattleStat, String>{};
  NatureModifier nature = battleNatures[12];
  List<String> types;
  int? pokemonId;
  PokemonDetail? detail;
  List<PokemonAbility> abilities = const [];
  String? abilitySlug;
  bool terastallized = false;
  String? teraType;
  BattleHeldItem heldItem = BattleHeldItem.none;
  BattleStatusCondition status = BattleStatusCondition.none;
  String? typeBoostItemType;
  bool loading = false;
  bool selectionFailed = false;
  bool partyDefaults = false;
  bool unsupportedItem = false;
  int _revision = 0;
  bool _disposed = false;
  bool _updating = false;

  int number(TextEditingController controller, int fallback) =>
      int.tryParse(controller.text) ?? fallback;

  void _inputsChanged() {
    if (_updating) return;
    refreshStats();
    notifyListeners();
  }

  void refreshStats() {
    _updating = true;
    for (final stat in BattleStat.values) {
      final fingerprint =
          '${base[stat]!.text}/${iv[stat]!.text}/'
          '${ev[stat]!.text}/${level.text}/${nature.key}';
      if (_fingerprints[stat] == fingerprint) continue;
      _fingerprints[stat] = fingerprint;
      overrides.remove(stat);
      raw[stat]!.text = pokemonId == 292 && stat == BattleStat.hp
          ? '1'
          : '${computeBattleStat(stat: stat, base: number(base[stat]!, 100), level: number(level, defaultLevel), iv: number(iv[stat]!, 31), ev: number(ev[stat]!, 0), nature: nature)}';
    }
    _updating = false;
  }

  int effectiveStat(BattleStat stat, {int generation = 9}) {
    var value = number(raw[stat]!, 0);
    if (stat == BattleStat.attack) {
      value = applyAttackerAbilityToAttackStat(value, true, abilitySlug);
      value = applyHeldItemToAttackStat(value, true, heldItem);
      if (abilitySlug == 'guts' && status != BattleStatusCondition.none) {
        value = (value * 1.5).floor();
      } else if (abilitySlug != 'water-bubble') {
        value = applyStatusToAttackStat(value, true, status);
      }
    } else if (stat == BattleStat.specialAttack) {
      value = applyHeldItemToAttackStat(value, false, heldItem);
    } else if (stat == BattleStat.speed) {
      value = applyStatusToSpeedStat(value, status, generation: generation);
    }
    return value;
  }

  void restoreStats() {
    _fingerprints.clear();
    refreshStats();
    notifyListeners();
  }

  void clearIdentity() {
    _revision++;
    loading = false;
    selectionFailed = false;
    pokemonId = null;
    detail = null;
    query.clear();
    abilities = const [];
    abilitySlug = null;
    partyDefaults = false;
  }

  Future<void> selectParty(PartyMember member) async {
    final revision = ++_revision;
    loading = true;
    selectionFailed = false;
    notifyListeners();
    try {
      PokemonSummary? summary;
      if (member.speciesId != null) {
        summary = await dexRepository.getSummary(member.speciesId!);
      } else {
        final matches = await dexRepository.search(member.species);
        summary = matches
            .where(
              (p) =>
                  p.nameZh == member.species ||
                  p.nameEn.toLowerCase() == member.species.toLowerCase(),
            )
            .firstOrNull;
      }
      if (_disposed || revision != _revision) return;
      if (summary == null) throw StateError('Unknown party species');
      await selectPokemon(summary, member: member);
    } catch (_) {
      if (_disposed || revision != _revision) return;
      loading = false;
      selectionFailed = true;
      notifyListeners();
    }
  }

  /// Loading is atomic: an error keeps the previous draft intact. The revision
  /// also protects consecutive selections of the same species and disposal.
  Future<void> selectPokemon(
    PokemonSummary summary, {
    PartyMember? member,
    Future<PokemonDetail> Function(int)? loadDetail,
    Future<List<PokemonAbility>> Function(int)? loadAbilities,
  }) async {
    final revision = ++_revision;
    loading = true;
    selectionFailed = false;
    notifyListeners();
    try {
      final detail = await (loadDetail ?? dexRepository.getDetail)(summary.id);
      final choices =
          await (loadAbilities ?? dexRepository.abilitiesForPokemon)(
            summary.id,
          );
      var preferredAbility = member?.abilitySlug;
      if (preferredAbility == null && member?.abilityId != null) {
        for (final ability in await dexRepository.getAllAbilities()) {
          if (ability.id == member!.abilityId) {
            preferredAbility = abilitySlugFromNameEn(ability.nameEn);
            break;
          }
        }
      }
      if (_disposed || revision != _revision) return;
      if (detail.baseStats == null) throw StateError('Missing base stats');
      _apply(detail, choices, member, preferredAbility);
    } catch (_) {
      if (_disposed || revision != _revision) return;
      selectionFailed = true;
    }
    if (_disposed || revision != _revision) return;
    loading = false;
    notifyListeners();
  }

  void _apply(
    PokemonDetail detail,
    List<PokemonAbility> choices,
    PartyMember? member,
    String? preferredAbility,
  ) {
    _updating = true;
    this.detail = detail;
    pokemonId = detail.summary.id;
    query.text = member?.nickname ?? detail.summary.nameZh;
    types = List.of(detail.summary.types);
    abilities = choices;
    abilitySlug =
        preferredAbility ??
        (choices.length == 1
            ? abilitySlugFromNameEn(choices.single.nameEn)
            : null);
    terastallized = false;
    teraType = types.firstOrNull;
    // Save item IDs have generation-specific numbering. Until a verified
    // mapping exists, require an explicit choice instead of guessing an item.
    heldItem = BattleHeldItem.none;
    unsupportedItem = member?.heldItemId != null;
    typeBoostItemType = null;
    status = switch (member?.status?.toLowerCase()) {
      '灼伤' || 'burn' => BattleStatusCondition.burn,
      '麻痹' || 'paralysis' => BattleStatusCondition.paralysis,
      _ => BattleStatusCondition.none,
    };
    level.text = '${member?.level ?? defaultLevel}';
    final matchedNature = battleNatures
        .where(
          (n) =>
              n.key == member?.nature?.toLowerCase() ||
              n.labelZh == member?.nature,
        )
        .firstOrNull;
    nature = matchedNature ?? battleNatures[12];
    partyDefaults =
        member != null &&
        (member.level == null ||
            member.ivs.length != 6 ||
            member.evs.length != 6 ||
            matchedNature == null ||
            (member.abilitySlug == null && member.abilityId == null));
    final bases = Map.fromEntries(detail.baseStats!.entries);
    // Save order is HP, Atk, Def, Speed, Sp.Atk, Sp.Def (not enum order).
    const saveOrder = [
      BattleStat.hp,
      BattleStat.attack,
      BattleStat.defense,
      BattleStat.speed,
      BattleStat.specialAttack,
      BattleStat.specialDefense,
    ];
    for (final stat in BattleStat.values) {
      final index = saveOrder.indexOf(stat);
      base[stat]!.text = '${bases[stat.apiKey]}';
      iv[stat]!.text =
          '${member != null && member.ivs.length > index ? member.ivs[index] : 31}';
      ev[stat]!.text =
          '${member != null && member.evs.length > index ? member.evs[index] : 0}';
    }
    _fingerprints.clear();
    refreshStats();
  }

  @override
  void dispose() {
    _disposed = true;
    query.dispose();
    level.dispose();
    for (final controller in [
      ...base.values,
      ...iv.values,
      ...ev.values,
      ...raw.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }
}
