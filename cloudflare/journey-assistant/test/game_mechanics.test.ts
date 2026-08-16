import { describe, expect, it } from 'vitest';
import type { AssistantRequest } from '../src/contract';
import {
  answerKnownPokemonFranchiseFact,
  answerSelectedGameMechanic,
} from '../src/game_mechanics';

const violetRequest: AssistantRequest = {
  question: '怎么 mega 进化路卡利欧',
  context: {
    game: 'violet',
    generation: 9,
    badgeIds: [],
    milestoneIds: [],
    locale: 'zh-Hans',
    parserRevision: 0,
    contextReliability: {
      game: 'user_selected',
      location: 'unknown',
      badges: 'unknown',
      milestones: 'unsupported',
    },
  },
};

describe('selected-game mechanic guard', () => {
  it('answers unsupported Mega Evolution before ordinary evolution retrieval', () => {
    const result = answerSelectedGameMechanic(violetRequest);

    expect(result).toMatchObject({
      status: 'answered',
      confidence: 'high',
      answerMode: 'local_audited',
      contextUsed: { game: 'violet' },
    });
    expect(result).not.toHaveProperty('modelUsed');
    expect(result?.answer).toContain('《宝可梦 紫》没有 Mega 进化机制');
    expect(result?.answer).toContain('路卡利欧在这个版本中无法 Mega 进化');
    expect(result?.answer).toContain('普通进化条件');
  });

  it('leaves supported Mega games and ordinary evolution questions to research', () => {
    expect(answerSelectedGameMechanic({
      ...violetRequest,
      context: { ...violetRequest.context, game: 'x', generation: 6 },
    })).toBeNull();
    expect(answerSelectedGameMechanic({
      ...violetRequest,
      question: '利欧路怎么进化成路卡利欧',
    })).toBeNull();
  });
});

describe('reviewed franchise facts', () => {
  it('answers the Team Rocket quote without applying the selected game', () => {
    const result = answerKnownPokemonFranchiseFact({
      ...violetRequest,
      question: '好讨厌的感觉是谁的台词？',
    });

    expect(result).toMatchObject({
      status: 'answered',
      confidence: 'high',
      answerMode: 'local_audited',
      contextUsed: { scope: 'pokemon_franchise' },
    });
    expect(result?.answer).toContain('武藏、小次郎和喵喵');
    expect(result?.answer).toContain('不是其中某一个人的专属台词');
  });
});
