import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/features/dex/version_availability.dart';

const _entry = ObtainLocationEntry(areaSlug: 'route-1', areaLabelZh: '1号道路');

EvolutionNode _node(
  int id,
  String nameZh, {
  String? triggerZh,
  List<EvolutionTrigger> triggers = const [],
  List<EvolutionNode> children = const [],
}) => EvolutionNode(
  id: id,
  nameEn: 'Mon$id',
  nameZh: nameZh,
  triggerZh: triggerZh,
  triggers: triggers,
  children: children,
);

void main() {
  group('isTradeTriggerZh', () {
    test('matches trade labels only', () {
      expect(isTradeTriggerZh('交换'), isTrue);
      expect(isTradeTriggerZh('通讯交换'), isTrue);
      expect(isTradeTriggerZh('Lv.36'), isFalse);
      expect(isTradeTriggerZh('道具：Metal-coat'), isFalse);
      expect(isTradeTriggerZh(null), isFalse);
    });
  });

  group('evolutionRequiresTrade', () {
    test('structured trade trigger wins even with a misleading label', () {
      // 巨钳螳螂: trade while holding Metal Coat — triggerZh reads bare 交换,
      // but detection must come from the structured field, not the string.
      final scizor = _node(
        212,
        '巨钳螳螂',
        triggerZh: '交换',
        triggers: const [
          EvolutionTrigger(trigger: 'trade', heldItem: 'metal-coat'),
        ],
      );
      expect(evolutionRequiresTrade(scizor), isTrue);
      expect(scizor.triggers.single.requiresHeldItem, isTrue);
    });

    test('a non-trade alternative unlocks the step', () {
      // 美纳斯-style: beauty level-up OR trade holding prism scale.
      final milotic = _node(
        350,
        '美纳斯',
        triggerZh: '交换',
        triggers: const [
          EvolutionTrigger(trigger: 'level-up', minBeauty: 171),
          EvolutionTrigger(trigger: 'trade', heldItem: 'prism-scale'),
        ],
      );
      expect(evolutionRequiresTrade(milotic), isFalse);
    });

    test('falls back to the display string on pre-trigger bundles', () {
      final legacy = _node(76, '隆隆岩', triggerZh: '交换');
      expect(evolutionRequiresTrade(legacy), isTrue);
      final legacyLevel = _node(15, '大针蜂', triggerZh: 'Lv.10');
      expect(evolutionRequiresTrade(legacyLevel), isFalse);
    });
  });

  group('versionExclusivity', () {
    test('classifies paired-version presence', () {
      const byVersion = {
        'soulsilver': [_entry],
        'heartgold': <ObtainLocationEntry>[],
      };
      expect(
        versionExclusivity(
          byVersion: byVersion,
          version: 'soulsilver',
          pairedVersion: 'heartgold',
        ),
        VersionExclusivity.onlyThis,
      );
      expect(
        versionExclusivity(
          byVersion: byVersion,
          version: 'heartgold',
          pairedVersion: 'soulsilver',
        ),
        VersionExclusivity.onlyOther,
      );
      expect(
        versionExclusivity(
          byVersion: const {},
          version: 'diamond',
          pairedVersion: 'pearl',
        ),
        VersionExclusivity.neither,
      );
      expect(
        versionExclusivity(
          byVersion: const {
            'diamond': [_entry],
            'pearl': [_entry],
          },
          version: 'diamond',
          pairedVersion: 'pearl',
        ),
        VersionExclusivity.both,
      );
    });
  });

  group('exact-version helpers', () {
    test('DLC versions inherit their base-game encounters', () {
      expect(accessibleEncounterVersions('the-crown-tundra-sword'), {
        'sword',
        'the-isle-of-armor-sword',
        'the-crown-tundra-sword',
      });
      expect(accessibleEncounterVersions('mega-dimension'), {
        'legends-za',
        'mega-dimension',
      });
    });

    test('paired versions include matching DLC flavors', () {
      expect(pairedEncounterVersion('soulsilver'), 'heartgold');
      expect(
        pairedEncounterVersion('the-indigo-disk-scarlet'),
        'the-indigo-disk-violet',
      );
      expect(pairedEncounterVersion('legends-arceus'), isNull);
    });

    test('progress bucket includes chain-derived methods only', () {
      expect(chainStageNeedsEvolutionOrTrade(ChainStageMethod.evolve), isTrue);
      expect(
        chainStageNeedsEvolutionOrTrade(ChainStageMethod.tradeRequired),
        isTrue,
      );
      expect(
        chainStageNeedsEvolutionOrTrade(ChainStageMethod.breedRequired),
        isTrue,
      );
      expect(
        chainStageNeedsEvolutionOrTrade(ChainStageMethod.catchable),
        isFalse,
      );
      expect(
        chainStageNeedsEvolutionOrTrade(ChainStageMethod.unavailable),
        isFalse,
      );
    });
  });

  group('planChainCompletion', () {
    // 独角虫系 shape: base catchable, both evolutions by level.
    final levelChain = _node(
      13,
      '独角虫',
      children: [
        _node(
          14,
          '铁壳蛹',
          triggerZh: 'Lv.7',
          children: [_node(15, '大针蜂', triggerZh: 'Lv.10')],
        ),
      ],
    );

    test('level chain from catchable base is self-contained', () {
      final plan = planChainCompletion(
        chain: levelChain,
        isCatchable: (id) => id == 13,
      );

      expect(plan.selfContained, isTrue);
      expect(plan.completable, isTrue);
      expect(plan.stages.map((s) => s.method), const [
        ChainStageMethod.catchable,
        ChainStageMethod.evolve,
        ChainStageMethod.evolve,
      ]);
    });

    test('trade evolution blocks self-containment but not completion', () {
      // 小拳石 → 隆隆石 → 隆隆岩(通信交换), structured triggers present.
      final chain = _node(
        74,
        '小拳石',
        children: [
          _node(
            75,
            '隆隆石',
            triggerZh: 'Lv.25',
            triggers: const [
              EvolutionTrigger(trigger: 'level-up', minLevel: 25),
            ],
            children: [
              _node(
                76,
                '隆隆岩',
                triggerZh: '交换',
                triggers: const [EvolutionTrigger(trigger: 'trade')],
              ),
            ],
          ),
        ],
      );

      final plan = planChainCompletion(
        chain: chain,
        isCatchable: (id) => id == 74 || id == 75,
      );

      expect(plan.selfContained, isFalse);
      expect(plan.completable, isTrue);
      expect(plan.blockers.single.speciesId, 76);
      expect(plan.blockers.single.method, ChainStageMethod.tradeRequired);
    });

    test('a catchable final stage neutralizes its trade trigger', () {
      // If the evolved form itself appears in the wild, no trade is needed.
      final chain = _node(
        74,
        '小拳石',
        children: [
          _node(
            75,
            '隆隆石',
            triggerZh: 'Lv.25',
            children: [_node(76, '隆隆岩', triggerZh: '交换')],
          ),
        ],
      );

      final plan = planChainCompletion(chain: chain, isCatchable: (id) => true);

      expect(plan.selfContained, isTrue);
      expect(plan.stages.last.method, ChainStageMethod.catchable);
    });

    test('breeding rescues an uncatchable baby stage', () {
      // 皮丘 not in the wild, 皮卡丘 is — breed down, then evolve back up.
      final chain = _node(
        172,
        '皮丘',
        children: [
          _node(
            25,
            '皮卡丘',
            triggerZh: '亲密度',
            children: [_node(26, '雷丘', triggerZh: '道具：Thunder-stone')],
          ),
        ],
      );

      final plan = planChainCompletion(
        chain: chain,
        isCatchable: (id) => id == 25,
      );

      expect(plan.stages.first.method, ChainStageMethod.breedRequired);
      expect(plan.selfContained, isTrue);
      expect(plan.completable, isTrue);
    });

    test('no breeding rescue when the game has none', () {
      final chain = _node(
        172,
        '皮丘',
        children: [_node(25, '皮卡丘', triggerZh: '亲密度')],
      );

      final plan = planChainCompletion(
        chain: chain,
        isCatchable: (id) => id == 25,
        supportsBreeding: false,
      );

      expect(plan.stages.first.method, ChainStageMethod.unavailable);
      expect(plan.completable, isFalse);
    });

    test('fully absent chain is unavailable end to end', () {
      final plan = planChainCompletion(
        chain: levelChain,
        isCatchable: (id) => false,
      );

      expect(plan.completable, isFalse);
      expect(
        plan.stages.every((s) => s.method == ChainStageMethod.unavailable),
        isTrue,
      );
    });

    test('branched chain resolves each branch independently', () {
      // 伊布: catchable; one branch stone-evolves, the other trade-locked
      // (synthetic) — only the trade branch blocks.
      final chain = _node(
        133,
        '伊布',
        children: [
          _node(134, '水伊布', triggerZh: '道具：Water-stone'),
          _node(196, '太阳伊布', triggerZh: '交换'),
        ],
      );

      final plan = planChainCompletion(
        chain: chain,
        isCatchable: (id) => id == 133,
      );

      expect(plan.completable, isTrue);
      expect(plan.selfContained, isFalse);
      expect(plan.blockers.single.speciesId, 196);
    });
  });
}
