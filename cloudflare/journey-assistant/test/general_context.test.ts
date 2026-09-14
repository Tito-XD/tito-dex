import { env } from 'cloudflare:test';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { answerQuestion } from '../src/assistant';
import { parseAssistantRequest, type AssistantRequest } from '../src/contract';
import { isExplicitFollowUpQuestion, recentConversationForQuestion } from '../src/conversation_context';
import { answerFromDexBundle, buildDexBundleSources } from '../src/dex_bundle_retrieval';
import { isPokemonScopedQuestion } from '../src/deepseek_native_search';
import { deterministicCuratedScopeDecision } from '../src/curated_web';
import { answerSelectedGameMechanic } from '../src/game_mechanics';
import { isGeneralPokemonFranchiseRequest } from '../src/pokemon_question_scope';
import { sourceMatchesPokemonQuestion } from '../src/pokemon_source_scope';

const request: AssistantRequest = {
  question: 'PTCG中基本能量和特殊能量有什么区别？',
  context: {
    game: 'general', generation: 0, badgeIds: [], milestoneIds: [],
    locale: 'zh-Hans', parserRevision: 0,
    contextReliability: {
      game: 'user_selected', location: 'unknown', badges: 'unknown', milestones: 'unsupported',
    },
  },
};
const gameRequest: AssistantRequest = {
  ...request,
  question: '魂银的拉普拉斯在哪里捕捉？',
  context: { ...request.context, game: 'soulsilver', generation: 4 },
};

afterEach(() => vi.restoreAllMocks());

describe('general Pokemon context', () => {
  it('accepts versionless questions without pretending to have save facts', () => {
    expect(parseAssistantRequest(request)?.context).toEqual(request.context);
    expect(parseAssistantRequest({ ...request, context: { ...request.context, generation: 9 } })).toBeNull();
    expect(parseAssistantRequest({ ...request, context: { ...request.context, locationId: 'johto-route-36' } })).toBeNull();
    expect(parseAssistantRequest({ ...request, context: { ...request.context, badgeIds: ['plain_badge'] } })).toBeNull();
    expect(parseAssistantRequest({
      ...request,
      context: {
        ...request.context,
        contextReliability: { ...request.context.contextReliability, game: 'save_verified' },
      },
    })).toBeNull();
    expect(parseAssistantRequest(gameRequest)?.context.game).toBe('soulsilver');
  });

  it.each([
    'PTCG中基本能量和特殊能量有什么区别？',
    'TCG中基本能量和特殊能量有什么区别？',
    '卡牌里基本能量和特殊能量有什么区别？',
    'How do Pokemon trading card game Energy cards work?',
    'Who voices Ash Ketchum in the Pokemon anime?',
    '宝可梦动画里火箭队有哪些经典台词？',
  ])('routes %s through franchise research in either context', async (question) => {
    for (const base of [request, gameRequest]) {
      const input = { ...base, question };
      expect(isPokemonScopedQuestion(input)).toBe(true);
      expect(isGeneralPokemonFranchiseRequest(input)).toBe(true);
      expect((await answerQuestion(input)).status).toBe('no_match');
      expect((await answerQuestion(input)).followUp).not.toContain('游戏版本');
    }
  });

  it('uses card queries without injecting anime terminology', () => {
    const decision = deterministicCuratedScopeDecision(request);
    expect(decision?.allowed).toBe(true);
    expect(decision?.queryEn).toContain('trading card game');
    expect(decision?.queryZh).not.toContain('动画');
  });

  it.each(['树才怪属性是什么？', '大葱鸭种族值是多少？', '树才怪会哪些招式？', '火箭队口号是什么？'])(
    'does not mistake %s for a story blocker', async (question) => {
      expect((await answerQuestion({ ...gameRequest, question })).status).toBe('no_match');
    },
  );

  it('does not apply version-specific Dex or Mega rules to a general/card question', async () => {
    const get = vi.spyOn(env.DEX_CONTENT, 'get');
    expect(await answerFromDexBundle(request, env.DEX_CONTENT)).toBeNull();
    expect(await buildDexBundleSources(request, env.DEX_CONTENT)).toEqual([]);
    expect(get).not.toHaveBeenCalled();
    expect(answerSelectedGameMechanic({ ...request, question: '路卡利欧怎么超级进化？' })).toBeNull();
    expect(answerSelectedGameMechanic({ ...gameRequest, question: 'PTCG中路卡利欧怎么超级进化？' })).toBeNull();
  });

  it('keeps general species facts and evolution relationships without game projections', async () => {
    const general = { ...request, question: '皮卡丘属性是什么？' };
    expect(isGeneralPokemonFranchiseRequest(general)).toBe(false);
    await env.DEX_CONTENT.put('bundle-manifest.json', JSON.stringify({
      complete: true, exactVersionLocations: true, bundleVersion: 20, cdnPrefix: 'v5',
    }));
    await env.DEX_CONTENT.put('v5/details/25.json', JSON.stringify({
      summary: { id: 25, types: ['electric'] },
      baseStats: { hp: 35, attack: 55, defense: 40, specialAttack: 50, specialDefense: 50, speed: 90 },
      evolutionChain: {
        id: 172, nameZh: '皮丘', children: [{
          id: 25, nameZh: '皮卡丘', children: [{ id: 26, nameZh: '雷丘', children: [] }],
        }],
      },
      obtainLocationsByVersion: { general: [{ areaLabelZh: '不得使用的地点' }] },
      moveSets: { '': { levelUp: [{ moveId: 85, level: 1 }] } },
    }));
    for (const [question, expected] of [
      ['皮卡丘属性是什么？', '电'],
      ['皮卡丘种族值是多少？', '55'],
      ['皮卡丘进化链是什么？', '皮丘 → 皮卡丘 → 雷丘'],
    ]) {
      const result = await answerFromDexBundle({ ...general, question }, env.DEX_CONTENT);
      expect(result?.response.status).toBe('answered');
      expect(result?.response.answer).toContain(expected);
      expect(result?.response.evidence?.scope).toBe('general');
      expect(result?.requiresOnlineVerification).toBe(question === '皮卡丘属性是什么？');
    }
    const sources = await buildDexBundleSources(general, env.DEX_CONTENT);
    const facts = JSON.parse(sources[0].text);
    expect(facts.exactGame).toBe(false);
    expect(facts.species.baseStats.attack).toBe(55);
    expect(facts.species.evolutionChain.edges).toHaveLength(2);
    expect(facts.species.versionedFor).toBeUndefined();
    expect(facts.species.encounters).toBeUndefined();
    expect(facts.species.moveSet).toBeUndefined();
    const explanation = { ...general, question: '皮卡丘为什么会进化成雷丘？' };
    expect(await answerFromDexBundle(explanation, env.DEX_CONTENT)).toBeNull();
    const explanationSources = await buildDexBundleSources(explanation, env.DEX_CONTENT);
    expect(JSON.parse(explanationSources[0].text).species.evolutionChain.edges).toHaveLength(2);
    expect(await answerFromDexBundle({ ...general, question: '皮卡丘在哪里捕捉？' }, env.DEX_CONTENT)).toBeNull();
  });
});

describe('follow-up language and evidence scope', () => {
  const history = [
    { role: 'user' as const, content: 'In SoulSilver where can I catch Lapras?' },
    { role: 'assistant' as const, content: 'Lapras appears in Union Cave on Friday.' },
  ];

  it.each([
    'What day of the week can I catch it?', 'Where can I find it?', 'How does it work?', 'Which ones?',
    'Can I attach it twice per turn?', 'How many of those cards can I include in my deck?',
    'Does that card work while it is in the discard pile?',
  ])(
    'keeps relevant history for %s', (question) => {
      const input = { ...gameRequest, question, history };
      expect(isExplicitFollowUpQuestion(question)).toBe(true);
      expect(recentConversationForQuestion(input)).toEqual(history);
      expect(isPokemonScopedQuestion(input)).toBe(true);
    },
  );

  it.each(['What is the weather today?', 'What about pasta?', 'How do I make pizza?', 'What is the capital of France?'])(
    'does not turn %s into a Pokemon follow-up', (question) => {
      const input = { ...gameRequest, question, history };
      expect(recentConversationForQuestion(input)).toEqual([]);
      expect(isPokemonScopedQuestion(input)).toBe(false);
    },
  );

  it('keeps an elliptical card follow-up independent of the selected game', () => {
    const input = {
      ...gameRequest, question: 'How does it work?',
      history: [
        { role: 'user' as const, content: 'What is PTCG special Energy?' },
        { role: 'assistant' as const, content: 'Its effect is printed on the card.' },
      ],
    };
    expect(isGeneralPokemonFranchiseRequest(input)).toBe(true);
    expect(isPokemonScopedQuestion(input)).toBe(true);
    expect(isGeneralPokemonFranchiseRequest({ ...input, question: '那它每回合能用几次？' })).toBe(true);
    expect(isGeneralPokemonFranchiseRequest({
      ...input, question: '那《魂银》中拉普拉斯在哪里抓？',
    })).toBe(false);
    expect(isGeneralPokemonFranchiseRequest({
      ...input, question: '皮卡丘种族值是多少？',
    })).toBe(false);
  });

  it.each(['游戏王卡牌规则是什么？', 'Yu-Gi-Oh TCG deck rules', '万智牌里能用几张？'])(
    'does not classify another card franchise as Pokemon: %s', (question) => {
      expect(isPokemonScopedQuestion({ ...request, question })).toBe(false);
    },
  );

  it('rejects card pages for gameplay and gameplay pages for card rules', () => {
    const card = {
      title: 'Lapras (HeartGold & SoulSilver 24)',
      url: 'https://bulbapedia.bulbagarden.net/wiki/Lapras_(HeartGold_%26_SoulSilver_24)',
    };
    const game = {
      title: 'Lapras (Pokémon)',
      url: 'https://bulbapedia.bulbagarden.net/wiki/Lapras_(Pok%C3%A9mon)#Game_locations',
    };
    expect(sourceMatchesPokemonQuestion(gameRequest, card)).toBe(false);
    expect(sourceMatchesPokemonQuestion(request, game)).toBe(false);
    expect(sourceMatchesPokemonQuestion(request, card)).toBe(true);
    expect(sourceMatchesPokemonQuestion(gameRequest, game)).toBe(true);
    expect(sourceMatchesPokemonQuestion(gameRequest, {
      ...game, url: 'https://bulbapedia.bulbagarden.net/w/index.php?title=Lapras&diff=123',
    })).toBe(false);
  });
});
