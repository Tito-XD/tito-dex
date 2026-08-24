import { describe, expect, it } from 'vitest';
import { generatedAnswerGuardFailure } from '../src/answer_quality_guards';

const moveNames = ['波导弹', '真空波', '剑舞', '彗星拳', '近身战', '帮助'];

function bundleSource(
  learnableNames: readonly string[],
  move?: Record<string, unknown>,
): {
  id: string;
  title: string;
  text: string;
} {
  return {
    id: 'dex-bundle-v20',
    title: 'TitoDex Dex bundle v20 · 结构化事实',
    text: JSON.stringify({
      species: {
        moveSet: {
          levelUp: [],
          machine: learnableNames.map((nameZh, id) => ({ id: id + 1, nameZh })),
          egg: [],
          tutor: [],
          truncated: true,
        },
      },
      ...(move ? { move } : {}),
    }),
  };
}

function guard(
  answer: string,
  sources: Array<{ id: string; title: string; text: string; url?: string }>,
  includeAdviceSource = true,
): ReturnType<typeof generatedAnswerGuardFailure> {
  return generatedAnswerGuardFailure({
    answer,
    question: '紫里路卡利欧适合学哪些招式？',
    game: 'violet',
    knownMoveNames: moveNames,
    structuredSources: [
      ...sources,
      ...(includeAdviceSource
        ? [{
            id: 'strategy-guide',
            title: 'Bounded strategy guide',
            url: 'https://www.serebii.net/pokedex-sv/lucario/',
            text: '路卡利欧培养与招式用途参考。',
          }]
        : []),
    ],
  });
}

describe('structured move advice guard', () => {
  it('allows useful recommendations without unsupported move metadata', () => {
    expect(guard(
      '- 波导弹：用于稳定的本系输出。\n- 剑舞：用于强化物攻路线。',
      [bundleSource(['波导弹', '剑舞'])],
    )).toBeNull();
  });

  it('allows a transparent candidate-only caveat when an online guide is present', () => {
    expect(guard(
      '- 波导弹：选择时需结合队伍缺口；攻略只支持它是候选，未说明更细取舍。',
      [bundleSource(['波导弹'])],
    )).toBeNull();
  });

  it('does not turn a selected-game moveSet into unsupported strategy advice', () => {
    expect(guard(
      '波导弹：用于稳定的本系输出。',
      [bundleSource(['波导弹'])],
      false,
    )).toBe('move_advice_missing_source');
  });

  it('does not mistake an ordinary word that is also a move name for a candidate', () => {
    expect(guard(
      '波导弹：用于帮助通关。',
      [bundleSource(['波导弹'])],
    )).toBeNull();
  });

  it('does not treat a selected-game moveSet as attribute or numeric evidence', () => {
    expect(guard(
      '波导弹（特殊格斗系，威力120）：用于本系输出。',
      [bundleSource(['波导弹'])],
    )).toBe('move_fact_unverified');
  });

  it('rejects the exact live wrong-value pattern even when every move is learnable', () => {
    expect(guard(
      [
        '- 波导弹（特殊格斗系，威力120）：用于本系输出。',
        '- 真空波（物理格斗系，威力40）：用于先手收割。',
        '- 彗星拳（物理钢系，威力140）：用于物攻路线。',
      ].join('\n'),
      [bundleSource(['波导弹', '真空波', '彗星拳'])],
    )).toBe('move_fact_unverified');
  });

  it('accepts matching structured type, category, power, accuracy and PP', () => {
    expect(guard(
      '波导弹（特殊格斗系，威力80，命中100，PP20）：用于本系输出。',
      [
        bundleSource(['波导弹']),
        {
          id: 'pokeapi-move-396',
          title: 'PokéAPI · 波导弹',
          url: 'https://pokeapi.co/api/v2/move/396/',
          text: JSON.stringify({
            versionScope: { exactGame: true, game: 'violet' },
            gameValues: {
              type: 'fighting',
              damageClass: 'special',
              power: 80,
              accuracy: 100,
              pp: 20,
            },
          }),
        },
      ],
    )).toBeNull();
  });

  it('rejects a structured category or value conflict', () => {
    expect(guard(
      '波导弹（物理格斗系，威力120，PP20）：用于本系输出。',
      [
        bundleSource(['波导弹'], {
          nameZh: '波导弹',
          type: 'fighting',
          category: 'special',
          power: 80,
          pp: 20,
        }),
      ],
    )).toBe('move_fact_conflict');
  });

  it('requires every recommended move to be in the selected-game moveSet', () => {
    expect(guard(
      '近身战：用于物攻路线的本系输出。',
      [bundleSource(['波导弹'])],
    )).toBe('move_candidate_not_learnable');
  });

  it('does not let a move reference shard prove that a species can learn it', () => {
    expect(guard(
      '波导弹：用于稳定的本系输出。',
      [{
        id: 'pokeapi-move-396',
        title: 'PokéAPI · 波导弹',
        url: 'https://pokeapi.co/api/v2/move/396/',
        text: JSON.stringify({
          versionScope: { exactGame: true, game: 'violet' },
          gameValues: {
            type: 'fighting',
            damageClass: 'special',
            power: 80,
            pp: 20,
          },
        }),
      }],
    )).toBe('move_candidate_not_learnable');
  });

  it('requires a use or selection condition rather than a learnset restatement', () => {
    expect(guard(
      '可学习的招式包括：波导弹。',
      [bundleSource(['波导弹'])],
    )).toBe('move_advice_missing_rationale');
  });

  it('rejects qualitative accuracy claims when structured accuracy is absent', () => {
    expect(guard(
      '波导弹：这是必中招式，用于稳定的本系输出。',
      [
        bundleSource(['波导弹'], {
          nameZh: '波导弹',
          type: 'fighting',
          category: 'special',
          power: 80,
          pp: 20,
        }),
      ],
    )).toBe('move_fact_unverified');
  });

  it('rejects an implicit damage category when structured category is absent', () => {
    expect(guard(
      '波导弹：特殊攻击，用于稳定的本系输出。',
      [bundleSource(['波导弹'])],
    )).toBe('move_fact_unverified');
  });

  it('rejects qualitative power claims when structured power is absent', () => {
    expect(guard(
      '波导弹：威力较高，用于稳定的本系输出。',
      [bundleSource(['波导弹'])],
    )).toBe('move_fact_unverified');
  });

  it('rejects implicit category, qualitative power, and fake inline lists', () => {
    expect(guard(
      '波导弹：特殊攻击，威力较高，用于输出。- 剑舞：用于强化。',
      [bundleSource(['波导弹', '剑舞'])],
    )).toBe('move_advice_not_structured');
  });
});
