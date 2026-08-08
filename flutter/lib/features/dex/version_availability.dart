/// Phase 2 logic layer: version exclusivity and whether an evolution chain can
/// be completed inside one game version, derived entirely from data already in
/// the offline bundle (`obtainLocationsByVersion` + `evolutionChain`).
///
/// UI wiring (获取 tab second segment / evolution cards) is deliberately not
/// part of this file — those widgets are being reworked on the search branch.
///
/// Trade detection reads the structured `EvolutionNode.triggers` (all
/// alternative conditions, held items included) and falls back to the display
/// string for bundles built before that field existed.
library;

import 'dex_models.dart';

/// Game-mechanics gates used when an evolution has alternative triggers.
///
/// Encounter data answers where a species exists; this profile answers whether
/// a route such as Feebas's Beauty evolution can actually be performed in the
/// selected game. Add rules here only when they affect route availability.
class MechanicsProfile {
  const MechanicsProfile({
    required this.versionGroup,
    required this.supportsBreeding,
    required this.supportsBeautyEvolution,
  });

  final String versionGroup;
  final bool supportsBreeding;
  final bool supportsBeautyEvolution;

  factory MechanicsProfile.forVersionGroup(String versionGroup) {
    return MechanicsProfile(
      versionGroup: versionGroup,
      supportsBreeding: supportsBreedingInVersionGroup(versionGroup),
      supportsBeautyEvolution: const {
        'ruby-sapphire',
        'emerald',
        'diamond-pearl',
        'platinum',
        'omega-ruby-alpha-sapphire',
        'brilliant-diamond-shining-pearl',
      }.contains(versionGroup),
    );
  }

  bool supportsTrigger(EvolutionTrigger trigger) {
    if (trigger.minBeauty != null && !supportsBeautyEvolution) {
      return false;
    }
    if ((trigger.item == 'prism-scale' || trigger.heldItem == 'prism-scale') &&
        const {
          'red-blue',
          'yellow',
          'gold-silver',
          'crystal',
          'ruby-sapphire',
          'emerald',
          'firered-leafgreen',
          'diamond-pearl',
          'platinum',
          'heartgold-soulsilver',
        }.contains(versionGroup)) {
      return false;
    }
    return true;
  }
}

/// Whether [triggerZh] describes a link-trade evolution — the one evolution
/// step that can never be done alone in a single cartridge.
///
/// String fallback only: prefer [evolutionRequiresTrade], which reads the
/// structured triggers when the bundle carries them.
bool isTradeTriggerZh(String? triggerZh) {
  if (triggerZh == null) {
    return false;
  }
  // '交换' (bundle) / '通讯交换' (legacy display copy). Item evolutions render
  // as '道具：…' and never collide with this.
  return triggerZh == '交换' || triggerZh == '通讯交换';
}

/// Whether this evolution step can only happen through a link trade.
///
/// Prefers the structured [EvolutionNode.triggers] (covers 巨钳螳螂-style
/// trade-while-holding, which the display string flattens to a bare 「交换」).
/// Bundles built before the structured field lack `triggers`, so this falls
/// back to the display string.
///
/// When alternatives exist, only an all-trade set counts as trade-locked:
/// a non-trade alternative (e.g. 美纳斯 beauty level-up vs trade+prism-scale)
/// is assumed reachable unless [mechanics] filters that route out for the
/// selected version.
bool evolutionRequiresTrade(EvolutionNode node, {MechanicsProfile? mechanics}) {
  final triggers = mechanics == null
      ? node.triggers
      : node.triggers.where(mechanics.supportsTrigger).toList();
  if (triggers.isNotEmpty) {
    return triggers.every((trigger) => trigger.isTrade);
  }
  if (mechanics != null && node.triggers.isNotEmpty) {
    return false;
  }
  return isTradeTriggerZh(node.triggerZh);
}

/// Presence of wild/static encounters for a species in one exact version key
/// of `obtainLocationsByVersion` (e.g. 'soulsilver', 'sword', 'scarlet').
bool hasEncountersInVersion(
  Map<String, List<ObtainLocationEntry>> byVersion,
  String versionKey,
) {
  final entries = byVersion[versionKey];
  return entries != null && entries.isNotEmpty;
}

/// How a species compares between the two flavors of a paired edition.
enum VersionExclusivity {
  /// Obtainable in both flavors.
  both,

  /// Only in the queried flavor — the partner version must trade for it.
  onlyThis,

  /// Only in the partner flavor — this version must trade for it.
  onlyOther,

  /// In neither flavor (evolution-only, event-only, or absent).
  neither,
}

/// Compares encounter presence between [version] and its [pairedVersion]
/// (e.g. 'diamond' vs 'pearl'). Single-flavor editions should not call this.
VersionExclusivity versionExclusivity({
  required Map<String, List<ObtainLocationEntry>> byVersion,
  required String version,
  required String pairedVersion,
}) {
  final here = hasEncountersInVersion(byVersion, version);
  final there = hasEncountersInVersion(byVersion, pairedVersion);
  if (here && there) {
    return VersionExclusivity.both;
  }
  if (here) {
    return VersionExclusivity.onlyThis;
  }
  if (there) {
    return VersionExclusivity.onlyOther;
  }
  return VersionExclusivity.neither;
}

/// How one stage of an evolution chain is obtained in the selected version.
enum ChainStageMethod {
  /// Direct wild/static encounter exists.
  catchable,

  /// Evolves from an obtainable earlier stage without trading.
  evolve,

  /// Reachable only through a link-trade evolution.
  tradeRequired,

  /// Base stage reachable only by breeding down from a later stage.
  breedRequired,

  /// Not obtainable inside this version at all.
  unavailable,
}

class ChainStagePlan {
  const ChainStagePlan({
    required this.speciesId,
    required this.nameZh,
    required this.method,
    this.triggerZh,
  });

  final int speciesId;
  final String nameZh;
  final ChainStageMethod method;

  /// The evolution condition leading *into* this stage, when there is one.
  final String? triggerZh;
}

class ChainCompletionPlan {
  const ChainCompletionPlan({required this.stages});

  final List<ChainStagePlan> stages;

  /// Every stage obtainable without trading or external help.
  bool get selfContained => stages.every(
    (stage) =>
        stage.method == ChainStageMethod.catchable ||
        stage.method == ChainStageMethod.evolve ||
        stage.method == ChainStageMethod.breedRequired,
  );

  /// Every stage obtainable at all (possibly via trade).
  bool get completable =>
      stages.every((stage) => stage.method != ChainStageMethod.unavailable);

  /// Stages that block a solo playthrough from finishing the chain.
  List<ChainStagePlan> get blockers => stages
      .where(
        (stage) =>
            stage.method == ChainStageMethod.tradeRequired ||
            stage.method == ChainStageMethod.unavailable,
      )
      .toList(growable: false);
}

/// Whether a missing stage is obtained from another member of its chain rather
/// than by catching that stage directly.
///
/// Breeding is included because the player still needs another chain member;
/// the Dex UI groups it with evolution/trade instead of ordinary encounters.
bool chainStageNeedsEvolutionOrTrade(ChainStageMethod method) =>
    switch (method) {
      ChainStageMethod.evolve ||
      ChainStageMethod.tradeRequired ||
      ChainStageMethod.breedRequired => true,
      ChainStageMethod.catchable || ChainStageMethod.unavailable => false,
    };

/// Exact-version keys that are already accessible when the selected entry is
/// a DLC overlay. A Crown Tundra save, for example, can still catch base Sword
/// encounters; treating the overlay as a standalone cartridge would create
/// false trade blockers.
Set<String> accessibleEncounterVersions(String version) => switch (version) {
  'the-isle-of-armor-sword' => {'sword', version},
  'the-isle-of-armor-shield' => {'shield', version},
  'the-crown-tundra-sword' => {'sword', 'the-isle-of-armor-sword', version},
  'the-crown-tundra-shield' => {'shield', 'the-isle-of-armor-shield', version},
  'the-teal-mask-scarlet' => {'scarlet', version},
  'the-teal-mask-violet' => {'violet', version},
  'the-indigo-disk-scarlet' => {'scarlet', 'the-teal-mask-scarlet', version},
  'the-indigo-disk-violet' => {'violet', 'the-teal-mask-violet', version},
  'mega-dimension' => {'legends-za', version},
  _ => {version},
};

/// Paired cartridge/DLC flavor for an exact encounter key.
///
/// Single-version games and Japanese Gen-I variants intentionally return null.
String? pairedEncounterVersion(String version) => switch (version) {
  'red' => 'blue',
  'blue' => 'red',
  'gold' => 'silver',
  'silver' => 'gold',
  'ruby' => 'sapphire',
  'sapphire' => 'ruby',
  'firered' => 'leafgreen',
  'leafgreen' => 'firered',
  'diamond' => 'pearl',
  'pearl' => 'diamond',
  'heartgold' => 'soulsilver',
  'soulsilver' => 'heartgold',
  'black' => 'white',
  'white' => 'black',
  'black-2' => 'white-2',
  'white-2' => 'black-2',
  'x' => 'y',
  'y' => 'x',
  'omega-ruby' => 'alpha-sapphire',
  'alpha-sapphire' => 'omega-ruby',
  'sun' => 'moon',
  'moon' => 'sun',
  'ultra-sun' => 'ultra-moon',
  'ultra-moon' => 'ultra-sun',
  'lets-go-pikachu' => 'lets-go-eevee',
  'lets-go-eevee' => 'lets-go-pikachu',
  'sword' => 'shield',
  'shield' => 'sword',
  'the-isle-of-armor-sword' => 'the-isle-of-armor-shield',
  'the-isle-of-armor-shield' => 'the-isle-of-armor-sword',
  'the-crown-tundra-sword' => 'the-crown-tundra-shield',
  'the-crown-tundra-shield' => 'the-crown-tundra-sword',
  'brilliant-diamond' => 'shining-pearl',
  'shining-pearl' => 'brilliant-diamond',
  'scarlet' => 'violet',
  'violet' => 'scarlet',
  'the-teal-mask-scarlet' => 'the-teal-mask-violet',
  'the-teal-mask-violet' => 'the-teal-mask-scarlet',
  'the-indigo-disk-scarlet' => 'the-indigo-disk-violet',
  'the-indigo-disk-violet' => 'the-indigo-disk-scarlet',
  _ => null,
};

/// Games whose normal progression has no breeding system.
bool supportsBreedingInVersionGroup(String versionGroup) => !{
  'lets-go-pikachu-lets-go-eevee',
  'legends-arceus',
  'legends-za',
  'champions',
}.contains(versionGroup);

/// Plans how every stage of [chain] is obtained in one version.
///
/// [isCatchable] answers whether a species has any encounter in the selected
/// version (typically [hasEncountersInVersion] over that species' detail).
/// [supportsBreeding] should be false for games without breeding
/// (PLA, LGPE and LZA). Pass [mechanics] to filter evolution alternatives that
/// do not exist in the selected version.
ChainCompletionPlan planChainCompletion({
  required EvolutionNode chain,
  required bool Function(int speciesId) isCatchable,
  bool supportsBreeding = true,
  MechanicsProfile? mechanics,
}) {
  // Collect stages parent-first so each node sees its parent's resolution.
  final order = <(_StageRef, _StageRef?)>[];
  void walk(EvolutionNode node, _StageRef? parent) {
    final ref = _StageRef(node);
    order.add((ref, parent));
    for (final child in node.children) {
      walk(child, ref);
    }
  }

  walk(chain, null);

  ChainStageMethod resolve(_StageRef ref, _StageRef? parent) {
    if (isCatchable(ref.node.id)) {
      return ChainStageMethod.catchable;
    }
    final parentMethod = parent?.method;
    if (parentMethod != null && parentMethod != ChainStageMethod.unavailable) {
      final triggers = ref.node.triggers;
      if (mechanics != null &&
          triggers.isNotEmpty &&
          !triggers.any(mechanics.supportsTrigger)) {
        return ChainStageMethod.unavailable;
      }
      return evolutionRequiresTrade(ref.node, mechanics: mechanics)
          ? ChainStageMethod.tradeRequired
          : ChainStageMethod.evolve;
    }
    return ChainStageMethod.unavailable;
  }

  for (final (ref, parent) in order) {
    ref.method = resolve(ref, parent);
  }

  // Breeding rescue: an unavailable base stage is reachable by breeding when
  // any later stage is obtainable. Then re-resolve descendants that were
  // unavailable only because the base was.
  final root = order.first.$1;
  if (supportsBreeding &&
      root.method == ChainStageMethod.unavailable &&
      order.any(
        (entry) =>
            entry.$1 != root && entry.$1.method != ChainStageMethod.unavailable,
      )) {
    root.method = ChainStageMethod.breedRequired;
    for (final (ref, parent) in order.skip(1)) {
      if (ref.method == ChainStageMethod.unavailable) {
        ref.method = resolve(ref, parent);
      }
    }
  }

  return ChainCompletionPlan(
    stages: [
      for (final (ref, _) in order)
        ChainStagePlan(
          speciesId: ref.node.id,
          nameZh: ref.node.nameZh,
          method: ref.method,
          triggerZh: ref.node.triggerZh,
        ),
    ],
  );
}

class _StageRef {
  _StageRef(this.node);

  final EvolutionNode node;
  ChainStageMethod method = ChainStageMethod.unavailable;
}
