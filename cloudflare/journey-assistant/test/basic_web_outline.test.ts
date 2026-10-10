import { env, runInDurableObject } from 'cloudflare:test';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { AssistantRequest, AssistantResponse } from '../src/contract';
import { basicSnapshotFallback, basicSnapshotSources, isBasicOutlineRequest, normalizeBasicGameTitles, hasUsefulBasicAnswerContent, sanitizeBasicCatchExamples } from '../src/basic_web_outline';
import { buildDexBundleSources } from '../src/dex_bundle_retrieval';
import { questionEvidenceDomain } from '../src/question_evidence_scope';
import { researchCuratedWeb, type CuratedSource, type CuratedWebModelRunner } from '../src/curated_web';
import worker from '../src/index';

const request: AssistantRequest = { question: '伊布怎么进化？',
  context: { game: 'general', generation: 0, badgeIds: [], milestoneIds: [], locale: 'zh-Hans', parserRevision: 2,
    contextReliability: { game: 'user_selected', location: 'unknown', badges: 'unknown', milestones: 'unsupported' } } };
const key = 'exa-basic-test-key-123456789';
const date = () => new Date('2026-10-08T00:00:00Z');
const quote = '伊布可使用水之石进化为水伊布，使用雷之石进化为雷伊布，使用火之石进化为火伊布。';
function json(value: unknown) { return new Response(JSON.stringify(value), { headers: { 'content-type': 'application/json' } }); }
function fetchSources(text: string, title = '宝可梦通用机制资料') {
  return vi.fn<typeof fetch>(async (input, init) => {
    expect(input.toString()).toBe('https://api.exa.ai/search');
    expect(JSON.parse(init?.body as string)).not.toHaveProperty('includeDomains');
    return json({ results: [{ title, url: 'https://pokemon-reference.org/general', highlights: [text] }] });
  });
}
function sourceRunner(answer: string, verdict: 'supported' | 'unsupported' | 'contradicted' = 'supported'): CuratedWebModelRunner {
  return async (phase, messages) => {
    const prompt = JSON.parse(messages.at(-1)!.content);
    if (phase === 'curated-web-compose') {
      expect(messages[0].content).toContain('先回答来源能支持的版本无关基础知识');
      return { supported: true, answer, usedSourceIds: [prompt.sources.find((source: CuratedSource) => source.id.startsWith('exa-')).id] };
    }
    if (phase === 'curated-web-verify') {
      const evidence = prompt.sources.find((source: CuratedSource) => source.id.startsWith('exa-'));
      return { claims: prompt.claims.map((claim: { index: number }) => ({
      index: claim.index, verdict, sourceId: verdict === 'unsupported' ? '' : evidence.id,
      quote: verdict === 'unsupported' ? '' : evidence.text.slice(0, 220),
    })) }; }
    throw new Error(`unexpected phase ${phase}`);
  };
}
async function seed(id: number, detail: Record<string, unknown>) {
  await env.DEX_CONTENT.put('bundle-manifest.json', JSON.stringify({
    complete: true, exactVersionLocations: true, bundleVersion: 20, cdnPrefix: 'v5',
  }));
  await env.DEX_CONTENT.put(`v5/details/${id}.json`, JSON.stringify({ summary: { id }, ...detail }));
}

beforeEach(async () => {
  const objects = await env.DEX_CONTENT.list();
  await Promise.all(objects.objects.map((object) => env.DEX_CONTENT.delete(object.key)));
  await runInDurableObject(env.QUESTION_BUDGET.getByName('journey-questions-v1'), async (_instance, state) => { await state.storage.deleteAll(); });
});
afterEach(() => { vi.restoreAllMocks(); vi.unstubAllGlobals(); });

describe('source-supported basic outlines without a selected edition', () => {
  it.each([
    ['伊布怎么进化？', quote],
    ['利欧路怎么进化？', '利欧路需要较高亲密度，并在白天升级时进化为路卡利欧。'],
    ['皮卡丘有什么弱点？', '皮卡丘是电属性宝可梦，通常弱于地面属性；特性和场地效果需要另行考虑。'],
    ['利欧路在哪里抓？', '捕捉时先削减目标体力，避免使其失去战斗能力，再利用适合场景的精灵球；具体出现地点随游戏而异。'],
    ['皮卡丘在哪里捕捉？', '捕捉时先削减目标体力，避免使其失去战斗能力，再利用适合场景的精灵球；具体出现地点随游戏而异。'],
    ['路卡利欧怎么配招？', '配招先区分物理或特殊输出方向，再选择本系输出和弥补队伍缺口的招式；可学招式随游戏而异。'],
  ])('answers the supported common portion with one website: %s', async (question, answer) => {
    expect(questionEvidenceDomain({ ...request, question })).toBe('mechanics');
    const fetcher = fetchSources(answer);
    const runner = vi.fn(sourceRunner(answer));
    const result = await researchCuratedWeb({ ...request, question }, runner, fetcher, date, undefined, { exaApiKey: key });
    expect(result).toMatchObject({ status: 'answered', answer, outlineMode: 'basic_web_outline', followUp: null,
      evidence: { basis: 'sources', scope: 'general', complete: false }, sourceKinds: ['exa'] });
    expect(result!.sources).toHaveLength(1);
    expect(result!.sources![0].url).toBe('https://pokemon-reference.org/general');
    expect(fetcher).toHaveBeenCalledTimes(2);
    expect(runner.mock.calls.map(([phase]) => phase)).toEqual(['curated-web-compose', 'curated-web-verify']);
    expect(result!.answer).not.toContain('请先选择');
    const queries = fetcher.mock.calls.map(([, init]) => JSON.parse(init?.body as string).query).join(' ');
    if (question.includes('捕捉') || question.includes('抓')) {
      expect(queries).toContain('where to find catch obtain location');
      expect(queries).not.toContain('catching preparation');
    }
    if (question.includes('配招')) expect(queries).toContain('moveset selection principles');
  });

  it('answers where-to-catch intent using a source-backed edition-labelled example', async () => {
    const answer = '《宝可梦 朱／紫》：利欧路可在南第4区遇到；其他游戏的地点需要分别核对。';
    const fetcher = fetchSources(answer, '宝可梦 朱／紫 利欧路捕捉地点');
    const result = await researchCuratedWeb({ ...request, question: '利欧路在哪里抓？' },
      sourceRunner(answer), fetcher, date, undefined, { exaApiKey: key });
    expect(result).toMatchObject({ status: 'answered', answer, outlineMode: 'basic_web_outline' });
    expect(result?.contextUsed).not.toMatchObject({ game: 'scarlet' });
    expect(result?.sources?.[0].url).toBe('https://pokemon-reference.org/general');
    expect(fetcher).toHaveBeenCalledTimes(2);
    const queries = fetcher.mock.calls.map(([, init]) => JSON.parse(init?.body as string).query).join(' ');
    expect(queries).toContain('location encounter');
    expect(queries).toContain('利欧路在哪里抓');
  });

  it('keeps readable snapshot evidence separate from the old unconfirmed answer while retaining raw fact guards', async () => {
    await seed(447, { evolutionChain: { id: 447, nameZh: '利欧路', children: [
      { id: 448, nameZh: '路卡利欧', triggers: [{ trigger: 'level-up', minHappiness: 220, timeOfDay: 'day' }], children: [] },
    ] } });
    const riolu = { ...request, question: '利欧路怎么进化？' };
    const local = await buildDexBundleSources(riolu, env.DEX_CONTENT);
    const answer = '利欧路亲密度较高时，在白天升级可进化为路卡利欧。';
    const phases: string[] = [];
    const result = await researchCuratedWeb(riolu, async (phase, messages, ...rest) => {
      phases.push(phase);
      const input = JSON.parse(messages.at(-1)!.content);
      expect(input.sources.some((source: CuratedSource) => /^dex-bundle-v/u.test(source.id))).toBe(false);
      expect(input.sources.some((source: CuratedSource) => source.id === 'local-basic-snapshot-447')).toBe(true);
      return sourceRunner(answer)(phase, messages, ...rest);
    }, fetchSources(answer), date, undefined, { exaApiKey: key, localSources: [
      { id: 'dex-bundle-v20-answer', title: '旧底稿', text: JSON.stringify({ answer: '进化条件尚未确认，不能作为本版本操作要求。' }) }, ...local,
    ] });
    expect(result?.answer).toBe(answer);
    expect(phases).toEqual(['curated-web-compose', 'curated-web-verify']);
  });

  it('retains the complete raw evolution guard when a draft cites only web evidence', async () => {
    await seed(447, { evolutionChain: { id: 447, nameZh: '利欧路', children: [
      { id: 448, nameZh: '路卡利欧', triggers: [{ trigger: 'level-up', minHappiness: 220, timeOfDay: 'day' }], children: [] },
    ] } });
    const riolu = { ...request, question: '利欧路怎么进化？' };
    const runner = vi.fn(sourceRunner('利欧路可直接进化为皮卡丘。'));
    expect(await researchCuratedWeb(riolu, runner,
      fetchSources('利欧路可直接进化为皮卡丘，这是一条错误网页关系。'), date, undefined,
      { exaApiKey: key, localSources: await buildDexBundleSources(riolu, env.DEX_CONTENT) })).toBeNull();
    expect(runner).toHaveBeenCalledTimes(1);
  });

  it('restores actual cached conditions when verification retains only a real-world introductory fragment', async () => {
    await seed(133, { evolutionChain: { id: 133, nameZh: '伊布', children: [
      { id: 134, nameZh: '水伊布', triggers: [{ trigger: 'use-item', item: 'water-stone' }], children: [] },
    ] } });
    const runner = vi.fn(sourceRunner('伊布可以通过以下方式进化：'));
    const fetcher = fetchSources('伊布可以通过以下方式进化：原页面后文的实际进化方法未在此次截取中出现。');
    const result = await researchCuratedWeb(request, runner, fetcher, date, undefined, { exaApiKey: key,
      localSources: await buildDexBundleSources(request, env.DEX_CONTENT) });
    expect(result?.answer).toContain('- 水伊布：使用水之石');
    expect(result?.answer).not.toBe('伊布可以通过以下方式进化：');
    expect(result?.onlineComposed).toBe(false);
    expect(result?.sourceKinds).toEqual([]);
    expect(result?.sources?.[0].url).toBe('https://pokeapi.co/api/v2/pokemon-species/133/');
    expect(runner.mock.calls.map(([phase]) => phase)).toEqual(['curated-web-compose', 'curated-web-verify']);
    expect(fetcher).toHaveBeenCalledTimes(2);
  });

  it.each([
    ['伊布可以通过以下方式进化：', '伊布怎么进化？'],
    ['伊布的进化方法如下。', '伊布怎么进化？'],
    ['皮卡丘有什么弱点？', '皮卡丘有什么弱点？'],
    ['具体地点需要确认游戏版本。', '利欧路在哪里抓？'],
    ['请先选择游戏版本。', '利欧路在哪里抓？'],
  ])('does not count question echoes, introductions or version prompts as facts: %s', (answer, question) => {
    expect(hasUsefulBasicAnswerContent(answer, question)).toBe(false);
  });
  it.each([
    ['皮卡丘弱于地面属性。', '皮卡丘有什么弱点？'],
    ['利欧路需要亲密度较高，在白天升级。', '利欧路怎么进化？'],
    ['《朱／紫》：利欧路可在南第4区遇到。', '利欧路在哪里抓？'],
    ['配招先选择物理或特殊输出方向，结合队伍缺口选招。', '路卡利欧怎么配招？'],
  ])('keeps source-backed substantive partial answers: %s', (answer, question) => {
    expect(hasUsefulBasicAnswerContent(answer, question)).toBe(true);
  });

  it('removes a full malformed location/weather clause and keeps two clear edition examples', () => {
    const question = '利欧路在哪里抓？';
    const answer = '《剑／盾》：巨人帽岩、雹、海鸣洞窟可见。\n《朱／紫》：南第4区。\n《黑2／白2》：算木牧场。\n《X／Y》：22号道路。';
    expect(sanitizeBasicCatchExamples(answer, question)).toBe('《朱／紫》：南第4区。\n《黑2／白2》：算木牧场。');
    expect(sanitizeBasicCatchExamples('《剑／盾》：巨人帽岩（冰雹时）。', question)).toBe('《剑／盾》：巨人帽岩（冰雹时）。');
  });

  it('normalizes only reliable delimited game titles after grounded verification', async () => {
    const draft = '《 Scarlet/Violet》：利欧路可在 South Province (Area Four) 遇到。';
    const result = await researchCuratedWeb({ ...request, question: '利欧路在哪里抓？' },
      sourceRunner(draft), fetchSources(draft), date, undefined, { exaApiKey: key });
    expect(result?.answer).toBe('《朱／紫》：利欧路可在 South Province (Area Four) 遇到。');
    expect(normalizeBasicGameTitles('《Moon Stone》与《Black Comedy》不是游戏标题。')).toBe('《Moon Stone》与《Black Comedy》不是游戏标题。');
    expect(normalizeBasicGameTitles('《Diamond/Pearl/Platinum》')).toBe('《钻石／珍珠／白金》');
    expect(normalizeBasicGameTitles('《Sword (Isle of Armor)》')).toBe('《Sword (Isle of Armor)》');
  });

  it('keeps supported basic content when an unsupported specific place is removed', async () => {
    const supported = '捕捉时可削减目标体力并施加适当的异常状态。';
    const runner: CuratedWebModelRunner = async (phase, messages) => {
      const prompt = JSON.parse(messages.at(-1)!.content);
      if (phase === 'curated-web-compose') return { supported: true,
        answer: supported + '皮卡丘必定在一号道路出现。', usedSourceIds: [prompt.sources[0].id] };
      return { claims: prompt.claims.map((claim: { index: number }) => ({ index: claim.index,
        verdict: claim.index === 0 ? 'supported' : 'unsupported',
        sourceId: claim.index === 0 ? prompt.sources[0].id : '', quote: claim.index === 0 ? supported : '' })) };
    };
    const result = await researchCuratedWeb({ ...request, question: '皮卡丘在哪里捕捉？' }, runner,
      fetchSources(supported), date, undefined, { exaApiKey: key });
    expect(result?.answer).toBe(supported);
    expect(result?.confidence).toBe('low');
    expect(result?.unknowns?.join('')).toContain('资料不足的断言已省略');
  });

  it('does not accept model memory when every claim is unsupported', async () => {
    const result = await researchCuratedWeb(request, sourceRunner(quote, 'unsupported'),
      fetchSources('这里只介绍伊布的外观和生活习性，没有任何进化方法。'), date, undefined, { exaApiKey: key });
    expect(result).toBeNull();
  });

  it('does not accept concrete moves without a selected-game learnset', async () => {
    const runner = vi.fn(sourceRunner('路卡利欧推荐波导弹和剑舞。'));
    expect(await researchCuratedWeb({ ...request, question: '路卡利欧怎么配招？' }, runner,
      fetchSources('路卡利欧推荐波导弹和剑舞，但是此资料没有说明适用游戏。'), date, undefined, { exaApiKey: key })).toBeNull();
    expect(runner).toHaveBeenCalledTimes(1);
  });

  it.each(['漫画中的伊布怎么进化？', '伊布卡牌有什么弱点？', '动画中皮卡丘怎么进化？'])('keeps work grounding outside basic mode: %s', (question) => {
    expect(isBasicOutlineRequest({ ...request, question })).toBe(false);
  });
  it('keeps explicit unsupported and comparative editions outside basic mode', () => {
    const questionGameScope = { mode: 'multiple' as const, titles: [
      { game: null, zh: '红宝石', en: 'Ruby' }, { game: null, zh: '蓝宝石', en: 'Sapphire' } ] };
    expect(isBasicOutlineRequest({ ...request, questionGameScope })).toBe(false);
    expect(isBasicOutlineRequest({ ...request, context: { ...request.context, game: 'soulsilver', generation: 4 } })).toBe(false);
  });
});

describe('honest cached general facts with real upstream links', () => {
  it('supplies real Eevee conditions from the snapshot without numeric friendship claims', async () => {
    await seed(133, { evolutionChain: { id: 133, nameZh: '伊布', children: [
      { id: 134, nameZh: '水伊布', triggers: [{ trigger: 'use-item', item: 'water-stone' }], children: [] },
      { id: 196, nameZh: '太阳伊布', triggers: [{ trigger: 'level-up', minHappiness: 220, timeOfDay: 'day' }], children: [] },
    ] } });
    const sources = await buildDexBundleSources(request, env.DEX_CONTENT);
    const result = basicSnapshotFallback(request, sources, date);
    expect(result?.answer).toContain('- 水伊布：使用水之石');
    expect(result?.answer).not.toContain('该路线并不表示');
    expect(result?.answer?.match(/具体条件可能因游戏版本而异/gu)).toHaveLength(1);
    expect(result?.answer).toContain('亲密度较高、白天');
    expect(result?.answer).not.toContain('220');
    expect(result?.sources?.[0].url).toBe('https://pokeapi.co/api/v2/pokemon-species/133/');
    expect(result?.onlineComposed).toBe(false);
    expect(result?.evidence).toMatchObject({ basis: 'structured', complete: false });
    expect(result?.unknowns?.join('')).toContain('未实时读取');
  });
  it('answers Riolu level-up action and daytime without claiming a fixed level', async () => {
    const riolu = { ...request, question: '利欧路怎么进化？' };
    await seed(447, { evolutionChain: { id: 447, nameZh: '利欧路', children: [
      { id: 448, nameZh: '路卡利欧', triggers: [{ trigger: 'level-up', minHappiness: 220, timeOfDay: 'day' }], children: [] },
    ] } });
    const result = basicSnapshotFallback(riolu, await buildDexBundleSources(riolu, env.DEX_CONTENT), date);
    expect(result?.answer).toContain('升级、亲密度较高、白天');
    expect(result?.answer).not.toMatch(/220|等级门槛|\d+级/u);
  });
  it('uses actual stored Pikachu weakness rather than inferring attack matchups from its own type', async () => {
    const pikachu = { ...request, question: '皮卡丘有什么弱点？' };
    await seed(25, { summary: { id: 25, types: ['electric'] }, weaknesses: ['地面'] });
    const sources = await buildDexBundleSources(pikachu, env.DEX_CONTENT);
    expect(basicSnapshotFallback(pikachu, sources, date)?.answer).toContain('地面属性');
    expect(basicSnapshotSources(pikachu, sources)[0].url).toBe('https://pokeapi.co/api/v2/pokemon/25/');
    const typeOnly = [{ ...sources[0], text: JSON.stringify({ exactGame: false, species: { id: 25, types: ['electric'] } }) }];
    expect(basicSnapshotFallback(pikachu, typeOnly, date)).toBeNull();
  });
  it('does not drop extra evolution constraints to manufacture a simple method', async () => {
    await seed(133, { evolutionChain: { id: 133, nameZh: '伊布', children: [
      { id: 700, nameZh: '仙子伊布', triggers: [{ trigger: 'level-up', knownMoveType: 'fairy', minAffection: 2 }], children: [] },
    ] } });
    const result = basicSnapshotFallback(request, await buildDexBundleSources(request, env.DEX_CONTENT), date);
    expect(result?.answer).toContain('- 仙子伊布：已确认进化关系');
    expect(result?.answer).not.toContain('条件路线');
    expect(result?.answer).toContain('具体条件尚未确认');
  });
  it('does not use a snapshot fact as a substitute for missing catching or moveset instructions', () => {
    const source = { id: 'dex-bundle-v20', title: 'Dex', text: JSON.stringify({ exactGame: false, species: { id: 133, types: ['normal'] } }) };
    expect(basicSnapshotFallback({ ...request, question: '伊布在哪捕捉？' }, [source], date)).toBeNull();
    expect(basicSnapshotFallback({ ...request, question: '伊布怎么配招？' }, [source], date)).toBeNull();
  });
});

function basicEnv(run: ReturnType<typeof vi.fn>): Env {
  return { ...env, AI: { run }, AI_MODEL: '@cf/qwen/qwen3-30b-a3b-fp8', AI_GATEWAY_ID: 'titodex-journey-assistant',
    AI_SEARCH_ENABLED: 'false', CURATED_WEB_ENABLED: 'true', TAVILY_WEB_ENABLED: 'false', EXA_WEB_ENABLED: 'true',
    EXA_API_KEY: key, DEEPSEEK_NATIVE_SEARCH_ENABLED: 'false', DEEPSEEK_TEXT_FALLBACK_ENABLED: 'false',
  } as unknown as Env;
}
async function ask(run: ReturnType<typeof vi.fn>): Promise<AssistantResponse> {
  const response = await worker.fetch(new Request('https://assistant.test/v1/ask', { method: 'POST',
    headers: { 'content-type': 'application/json', 'x-titodex-device-key': 'basic-test-12345678', 'cf-connecting-ip': '203.0.113.2' },
    body: JSON.stringify(request) }), basicEnv(run));
  expect(response.status).toBe(200);
  return response.json() as Promise<AssistantResponse>;
}
describe('final basic outline ownership', () => {
  it('keeps a sourced useful answer instead of replacing it with the old relationship-only owner', async () => {
    await seed(133, { evolutionChain: { id: 133, nameZh: '伊布', children: [
      { id: 134, nameZh: '水伊布', triggers: [{ trigger: 'use-item', item: 'water-stone' }], children: [] },
    ] } });
    const answer = '伊布可使用水之石进化为水伊布。';
    vi.stubGlobal('fetch', fetchSources(quote));
    const run = vi.fn(async (_model, input, options) => {
      const phase = options.gateway.metadata.phase;
      return { response: await sourceRunner(answer)(phase, input.messages, {}, 0, 0) };
    });
    const result = await ask(run);
    expect(result.answer).toBe(answer);
    expect(result.sources?.[0].url).toBe('https://pokemon-reference.org/general');
    expect(result.outlineMode).toBe('basic_web_outline');
    expect(result.modelProviders).toEqual(['workers-ai-qwen']);
  });
  it('keeps a contradiction blocked through local fallback and final structured fact ownership', async () => {
    await seed(133, { evolutionChain: { id: 133, nameZh: '伊布', children: [
      { id: 134, nameZh: '水伊布', triggers: [{ trigger: 'use-item', item: 'water-stone' }], children: [] },
    ] } });
    vi.stubGlobal('fetch', fetchSources(quote));
    const run = vi.fn(async (_model, input, options) => {
      const phase = options.gateway.metadata.phase;
      return { response: await sourceRunner('伊布可进化为水伊布。', 'contradicted')(phase, input.messages, {}, 0, 0) };
    });
    const result = await ask(run);
    expect(result).toMatchObject({ status: 'no_match', answer: null, errorCode: 'basic_outline_conflict' });
    expect(result.sources?.length).toBeGreaterThan(0);
  });
});
