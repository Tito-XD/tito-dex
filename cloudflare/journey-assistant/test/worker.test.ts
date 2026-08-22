import { env, SELF } from 'cloudflare:test';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { AssistantRequest, AssistantResponse } from '../src/contract';
import { buildDexBundleSources } from '../src/dex_bundle_retrieval';
import worker, { reconcileParallelAnswers } from '../src/index';
import { progressionHints } from '../src/progression_hints';

function body(overrides: Record<string, unknown> = {}): string {
  return JSON.stringify({
    question: '挡路的树怎么过？',
    context: {
      game: 'soulsilver',
      generation: 4,
      locationId: 'johto-route-36-area',
      badgeIds: ['plain_badge'],
      milestoneIds: [],
      locale: 'zh-Hans',
      parserRevision: 2,
    },
    ...overrides,
  });
}

async function post(payload: string, deviceKey = 'test-device-key-12345'): Promise<Response> {
  return SELF.fetch('https://assistant.test/v1/ask', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-titodex-device-key': deviceKey,
    },
    body: payload,
  });
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

async function publishJourneyPackFixture(
  pack: Record<string, unknown>,
  overrides: Record<string, unknown> = {},
): Promise<Record<string, unknown>> {
  const body = JSON.stringify(pack);
  const descriptor = {
    id: pack.id,
    gameFamily: pack.gameFamily,
    games: pack.games,
    version: pack.version,
    contentPath: `/v1/journey-packs/objects/${String(pack.id)}/${String(pack.version)}.json`,
    sizeBytes: new TextEncoder().encode(body).byteLength,
    sha256: await sha256Hex(body),
    titleZh: '测试旅程资料',
    entryCount: Array.isArray(pack.entries) ? pack.entries.length : 1,
    bundleVersionRequired: 20,
    ...overrides,
  };
  await env.JOURNEY_CONTENT.put(
    `journey-packs/objects/${String(pack.id)}/${String(pack.version)}.json`,
    body,
  );
  await env.JOURNEY_CONTENT.put(
    'journey-packs/catalog.json',
    JSON.stringify({
      schemaVersion: 1,
      generatedAt: '2026-08-22T00:00:00Z',
      packs: [descriptor],
    }),
  );
  return descriptor;
}

describe('journey assistant Worker contract', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  beforeEach(async () => {
    const [journeyObjects, dexObjects] = await Promise.all([
      env.JOURNEY_CONTENT.list(),
      env.DEX_CONTENT.list(),
    ]);
    await Promise.all([
      ...journeyObjects.objects.map((object) => env.JOURNEY_CONTENT.delete(object.key)),
      ...dexObjects.objects.map((object) => env.DEX_CONTENT.delete(object.key)),
    ]);
  });

  it('reports sanitized configured capabilities without secrets or URLs', async () => {
    const response = await SELF.fetch('https://assistant.test/health');
    expect(response.status).toBe(200);
    const value = await response.json() as Record<string, unknown>;
    expect(value).toMatchObject({
      ok: true,
      schemaVersion: 2,
      capabilities: {
        worker: true,
        publicModel: 'unavailable',
        aiSearch: false,
        curatedSources: false,
        sourceProviders: ['pokeapi', 'strategywiki', 'wikidata'],
        webSearch: false,
        webSearchProviders: [],
        braveSearch: false,
        externalProvider: false,
      },
    });
    expect(JSON.stringify(value)).not.toContain('account');
    expect(JSON.stringify(value)).not.toContain('https://');
  });

  it('answers an unsupported selected-game Mega request without model or web fallback', async () => {
    const response = await post(body({
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
    }));
    const value = await response.json() as AssistantResponse;

    expect(value).toMatchObject({
      status: 'answered',
      answerMode: 'local_audited',
      modelUsed: false,
      aiSearchUsed: false,
      sourceKinds: [],
      contextUsed: { game: 'violet' },
    });
    expect(value.answer).toContain('《宝可梦 紫》没有 Mega 进化机制');
    expect(value.answer).not.toContain('白天');
  });

  it('answers the reviewed Team Rocket quote without selected-game context', async () => {
    const response = await post(body({
      question: '好讨厌的感觉是谁的台词？',
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
    }));
    const value = await response.json() as AssistantResponse;

    expect(value).toMatchObject({
      status: 'answered',
      answerMode: 'local_audited',
      modelUsed: false,
      aiSearchUsed: false,
      contextUsed: { scope: 'pokemon_franchise' },
    });
    expect(value.answer).toContain('武藏、小次郎和喵喵');
    expect(JSON.stringify(value.contextUsed)).not.toContain('violet');
  });

  it('reports DeepSeek native search only from fixed server configuration', async () => {
    const fakeEnv = deepSeekEnv({
      aiRun: vi.fn(),
    });
    const response = await worker.fetch(
      new Request('https://assistant.test/health'),
      fakeEnv,
    );
    expect(await response.json()).toMatchObject({
      capabilities: {
        webSearch: true,
        webSearchProviders: ['deepseek-native'],
      },
    });
  });

  it('accepts a real DeepSeek server-search result only after Qwen support verification', async () => {
    const aiRun = vi.fn(async (
      _model: string,
      _input: Record<string, unknown>,
      options?: AiOptions,
    ) => {
      const phase = options?.gateway?.metadata?.phase;
      if (phase === 'curated-web-route') {
        return {
          response: {
            hintId: '',
            webAllowed: true,
            queryZh: '宝可梦 紫 悖谬宝可梦',
            queryEn: 'Pokémon Violet Paradox Pokémon',
            pokeApiKind: '',
            pokeApiSlug: '',
          },
        };
      }
      if (phase === 'deepseek-native-verify') {
        return {
          response: {
            supported: true,
            answer: '悖谬宝可梦是《宝可梦 紫》中与未来意象有关的一组宝可梦。',
          },
        };
      }
      throw new Error(`unexpected_phase_${String(phase)}`);
    });
    const gatewayRun = vi.fn(async () => new Response(JSON.stringify({
      type: 'message',
      stop_reason: 'end_turn',
      content: [
        {
          type: 'server_tool_use',
          id: 'srvtoolu_paradox',
          name: 'web_search',
          input: { query: 'Pokémon Violet Paradox Pokémon' },
        },
        {
          type: 'web_search_tool_result',
          tool_use_id: 'srvtoolu_paradox',
          content: [{
            type: 'web_search_result',
            title: 'Paradox Pokémon - Bulbapedia',
            url: 'https://bulbapedia.bulbagarden.net/wiki/Paradox_Pok%C3%A9mon',
          }],
        },
        {
          type: 'text',
          text: '悖谬宝可梦是《宝可梦 紫》中与未来意象有关的一组宝可梦。',
          citations: [{
            type: 'web_search_result_location',
            title: 'Paradox Pokémon - Bulbapedia',
            url: 'https://bulbapedia.bulbagarden.net/wiki/Paradox_Pok%C3%A9mon',
            cited_text: 'Pokémon Violet features a group of futuristic Paradox Pokémon.',
          }],
        },
      ],
    }), { headers: { 'content-type': 'application/json' } }));
    vi.stubGlobal('fetch', gatewayRun);
    const fakeEnv = deepSeekEnv({ aiRun });
    const response = await worker.fetch(
      new Request('https://assistant.test/v1/ask', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-titodex-device-key': 'deepseek-test-key-12345',
        },
        body: JSON.stringify({
          question: '紫里未来主题的神秘宝可梦都是什么来历？',
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
        }),
      }),
      fakeEnv,
    );
    const value = await response.json() as Record<string, unknown>;
    expect(value).toMatchObject({
      status: 'answered',
      answerMode: 'deepseek_native_search',
      modelUsed: true,
      sourceKinds: ['deepseek-native'],
      sources: [{ title: 'Paradox Pokémon - Bulbapedia' }],
    });
    expect(JSON.stringify(value)).not.toContain('snippet');
    expect(gatewayRun).toHaveBeenCalledTimes(1);
    expect(aiRun).toHaveBeenCalledTimes(2);
  });

  it('accepts cited DeepSeek trial output at low confidence when snippets are absent', async () => {
    const aiRun = vi.fn(async (
      _model: string,
      _input: Record<string, unknown>,
      options?: AiOptions,
    ) => options?.gateway?.metadata?.phase === 'deepseek-native-topic-check'
      ? { response: { onTopic: true } }
      : {
          response: {
            hintId: '',
            webAllowed: true,
            queryZh: '宝可梦 紫 利欧路 培养',
            queryEn: 'Pokémon Violet Riolu training guide',
            pokeApiKind: 'pokemon-species',
            pokeApiSlug: 'riolu',
          },
        });
    const gatewayRun = vi.fn(async () => new Response(JSON.stringify({
      type: 'message',
      stop_reason: 'end_turn',
      content: [
        {
          type: 'server_tool_use',
          id: 'srvtoolu_riolu',
          name: 'web_search',
          input: { query: 'Pokémon Violet Riolu training guide' },
        },
        {
          type: 'web_search_tool_result',
          tool_use_id: 'srvtoolu_riolu',
          content: [{
            type: 'web_search_result',
            title: 'Riolu guide',
            url: 'https://www.serebii.net/pokedex-sv/riolu/',
          }],
        },
        {
          type: 'text',
          text: '利欧路可以进化为路卡利欧，是否培养取决于队伍需求。',
        },
      ],
    }), { headers: { 'content-type': 'application/json' } }));
    vi.stubGlobal('fetch', gatewayRun);
    const fakeEnv = deepSeekEnv({ aiRun, experimental: true });

    const response = await worker.fetch(
      new Request('https://assistant.test/v1/ask', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-titodex-device-key': 'deepseek-relaxed-key-12345',
        },
        body: violetBody('利欧路值得培养吗？'),
      }),
      fakeEnv,
    );

    expect(await response.json()).toMatchObject({
      status: 'answered',
      confidence: 'low',
      answerMode: 'deepseek_native_search',
      answer: '利欧路可以进化为路卡利欧，是否培养取决于队伍需求。',
      sources: [{ title: 'Riolu guide' }],
    });
    expect(gatewayRun).toHaveBeenCalledTimes(1);
  });

  it('rejects an off-topic Paradox answer even in the relaxed trial mode', async () => {
    const aiRun = vi.fn(async (
      _model: string,
      _input: Record<string, unknown>,
      options?: AiOptions,
    ) => options?.gateway?.metadata?.phase === 'deepseek-native-topic-check'
      ? { response: { onTopic: false } }
      : {
          response: {
            hintId: 'sv-violet-paradox-overview',
            webAllowed: true,
            queryZh: '宝可梦 紫 属性克制',
            queryEn: 'Pokémon Violet type matchups',
            pokeApiKind: '',
            pokeApiSlug: '',
          },
        });
    const gatewayRun = vi.fn(async () => new Response(JSON.stringify({
      type: 'message',
      stop_reason: 'end_turn',
      content: [
        {
          type: 'server_tool_use',
          id: 'srvtoolu_wrong_paradox',
          name: 'web_search',
          input: { query: 'Pokémon Violet type matchups' },
        },
        {
          type: 'web_search_tool_result',
          tool_use_id: 'srvtoolu_wrong_paradox',
          content: [{
            type: 'web_search_result',
            title: 'Paradox Pokémon - Bulbapedia',
            url: 'https://bulbapedia.bulbagarden.net/wiki/Paradox_Pok%C3%A9mon',
          }],
        },
        {
          type: 'text',
          text: '悖谬宝可梦是带有古代或未来特征的独立宝可梦。',
        },
      ],
    }), { headers: { 'content-type': 'application/json' } }));
    vi.stubGlobal('fetch', gatewayRun);

    const response = await worker.fetch(
      new Request('https://assistant.test/v1/ask', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-titodex-device-key': 'deepseek-topic-key-12345',
        },
        body: violetBody('紫里属性克制关系怎么看？'),
      }),
      deepSeekEnv({ aiRun, experimental: true }),
    );

    const value = await response.json() as AssistantResponse;
    expect(value).toMatchObject({ status: 'no_match', answer: null });
    expect(value.answer ?? '').not.toContain('悖谬');
    expect(aiRun.mock.calls.some((call) =>
      (call[2] as AiOptions | undefined)?.gateway?.metadata?.phase ===
        'deepseek-native-topic-check')).toBe(true);
  });

  it('marks Qwen and DeepSeek as dual-source only after an explicit cross-check', async () => {
    const aiRun = vi.fn(async (
      _model: string,
      _input: Record<string, unknown>,
      options?: AiOptions,
    ) => {
      expect(options?.gateway?.metadata?.phase).toBe(
        'parallel-answer-cross-check',
      );
      return { response: { corroborated: true, conflict: false } };
    });
    const request = JSON.parse(violetBody('利欧路值得培养吗？')) as AssistantRequest;
    const curated: AssistantResponse = {
      status: 'answered',
      answer: '限定来源整理：\n利欧路可以进化为路卡利欧。',
      confidence: 'medium',
      followUp: null,
      onlineComposed: true,
      answerMode: 'curated_sources_qwen',
      sourceKinds: ['tavily'],
      sources: [{
        title: 'Riolu guide',
        url: 'https://www.serebii.net/pokedex-sv/riolu/',
        accessedAt: '2026-08-16',
      }],
    };
    const deepSeekResponse: AssistantResponse = {
      status: 'answered',
      answer: 'DeepSeek 原生联网参考：\n利欧路可以进化为路卡利欧。',
      confidence: 'low',
      followUp: null,
      onlineComposed: true,
      answerMode: 'deepseek_native_search',
      sourceKinds: ['deepseek-native'],
      sources: [{
        title: 'Riolu - Bulbapedia',
        url: 'https://bulbapedia.bulbagarden.net/wiki/Riolu_(Pok%C3%A9mon)',
        accessedAt: '2026-08-16',
      }],
    };

    const result = await reconcileParallelAnswers(
      deepSeekEnv({ aiRun }),
      request,
      curated,
      {
        response: deepSeekResponse,
        draft: '利欧路可以进化为路卡利欧。',
      },
    );

    expect(result).toMatchObject({
      answerMode: 'multi_source_qwen',
      sourceKinds: ['tavily', 'deepseek-native'],
      sources: [{ title: 'Riolu guide' }, { title: 'Riolu - Bulbapedia' }],
    });
    expect(result?.answer).toBe(curated.answer);
    expect(result?.unknowns?.at(-1)).toContain('独立交叉核对');
    expect(aiRun).toHaveBeenCalledTimes(1);
  });

  it('serves local HGSS answers without an AI binding', async () => {
    const response = await post(body(), 'local-answer-key-123');
    expect(response.status).toBe(200);
    const value = await response.json() as {
      status: string;
      onlineComposed: boolean;
      answerMode: string;
      modelUsed: boolean;
      aiSearchUsed: boolean;
    };
    expect(value.status).toBe('answered');
    expect(value.onlineComposed).toBe(false);
    expect(value.answerMode).toBe('local_audited');
    expect(value.modelUsed).toBe(false);
    expect(value.aiSearchUsed).toBe(false);
    expect(response.headers.get('cache-control')).toBe('no-store');
  });
  it('streams only the completed verified answer with final metadata', async () => {
    const response = await SELF.fetch('https://assistant.test/v1/ask', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'accept': 'application/x-ndjson',
        'x-titodex-device-key': 'stream-answer-key-12345',
      },
      body: body(),
    });

    expect(response.status).toBe(200);
    expect(response.headers.get('content-type')).toContain('application/x-ndjson');
    const events = new TextDecoder().decode(await response.arrayBuffer())
      .trim()
      .split('\n')
      .map((line) => JSON.parse(line) as Record<string, unknown>);
    expect(events[0]).toEqual({ type: 'progress', stage: 'retrieving' });
    expect(events.at(-1)?.type).toBe('result');
    const result = events.at(-1)?.result as AssistantResponse;
    const streamedAnswer = events
      .filter((event) => event.type === 'answer_delta')
      .map((event) => event.delta)
      .join('');
    expect(result.status).toBe('answered');
    expect(streamedAnswer).toBe(result.answer);
    expect(JSON.stringify(events)).not.toContain('stream-answer-key');
  });


  it('answers exact-version encounter questions from the bounded Dex R2 bundle first', async () => {
    await seedDexBundle({
      violet: [
        encounter('south-province-area-two', '南第２区', 16, 20, ['wild']),
        encounter('south-province-area-four', '南第４区', 16, 16, ['fixed'], {
          isFixedEncounter: true,
        }),
        encounter('tera-raid-paldea', '帕底亚太晶结晶', 35, 35, ['raid'], {
          isRaid: true,
        }),
      ],
    });
    const response = await post(violetBody('紫里在哪里可以抓利欧路？'), 'dex-riolu-key-12345');
    expect(response.status).toBe(200);
    const value = await response.json() as Record<string, unknown>;
    expect(value).toMatchObject({
      status: 'answered',
      answerMode: 'local_audited',
      modelUsed: false,
      aiSearchUsed: false,
      matchedHintIds: ['dex-bundle-encounter-violet-447'],
      confidence: 'high',
    });
    expect(value.answer).toContain('TitoDex v19');
    expect(value.answer).toContain('南第2区');
    expect(value.answer).toContain('Lv.16–20');
    expect(value.answer).toContain('帕底亚太晶结晶');
    expect(JSON.stringify(value)).not.toContain('https://');
  });

  it('never leaks encounters from the paired game when the exact version has no rows', async () => {
    await seedDexBundle({
      scarlet: [encounter('scarlet-only-area', '朱版限定地点', 20, 22, ['wild'])],
    });
    const response = await post(violetBody('紫里在哪里可以抓利欧路？'), 'dex-isolation-key-123');
    expect(response.status).toBe(200);
    const value = await response.json() as Record<string, unknown>;
    expect(value).toMatchObject({ status: 'no_match', answerMode: 'no_match' });
    expect(JSON.stringify(value)).not.toContain('朱版限定地点');
  });

  it('rejects unsafe prefixes and does not treat a generic evolution chain as versioned fact', async () => {
    await env.DEX_CONTENT.put('bundle-manifest.json', JSON.stringify({
      bundleVersion: 19,
      cdnPrefix: '../private',
      complete: true,
      exactVersionLocations: true,
    }));
    await env.DEX_CONTENT.put('v5/details/447.json', JSON.stringify({
      summary: { id: 447 },
      obtainLocationsByVersion: {
        violet: [encounter('should-not-load', '不应读取', 1, 1, ['wild'])],
      },
    }));
    const unsafe = await post(violetBody('紫里在哪里可以抓利欧路？'), 'dex-prefix-key-1234');
    expect(await unsafe.json()).toMatchObject({ status: 'no_match' });

    await seedDexBundle(
      { violet: [encounter('south-province-area-two', '南第２区', 16, 20, ['wild'])] },
      {
        evolutionChain: {
          id: 447,
          nameZh: '利欧路',
          children: [{
            id: 448,
            nameZh: '路卡利欧',
            children: [],
            triggers: [{ trigger: 'level-up', minHappiness: 160, timeOfDay: 'day' }],
          }],
        },
      },
    );
    const evolution = await post(violetBody('利欧路怎么进化？'), 'dex-intent-key-1234');
    const value = await evolution.json() as Record<string, unknown>;
    expect(value).toMatchObject({ status: 'no_match', answerMode: 'no_match' });
    expect(JSON.stringify(value)).not.toContain('亲密度至少 160');
  });

  it('uses exact-version held-item rates and keeps their provenance warning', async () => {
    await seedDexBundle({}, {
      heldItems: [{
        slug: 'light-ball',
        rarityByVersion: { violet: 5, scarlet: 7 },
        maxRarity: 7,
      }],
    });
    await env.DEX_CONTENT.put('v5/items.json', JSON.stringify({
      213: {
        id: 213,
        slug: 'light-ball',
        nameZh: '电气球',
        categoryZh: '携带道具',
        cost: 1000,
      },
    }));
    const response = await post(violetBody('利欧路会携带什么道具？'), 'dex-held-key-123456');
    const value = await response.json() as Record<string, unknown>;
    expect(value).toMatchObject({ status: 'answered', modelUsed: false });
    expect(value.answer).toContain('电气球：5%');
    expect(value.answer).not.toContain('7%');
    expect(JSON.stringify(value)).toContain('52Poké');
  });

  it('uses the selected game version-group for move learning', async () => {
    await seedDexBundle({}, {
      moveSets: {
        'scarlet-violet': {
          levelUp: [{ moveId: 14, method: 'level-up', level: 40 }],
          machine: [{ moveId: 14, method: 'machine' }],
          egg: [],
          tutor: [],
        },
        'heartgold-soulsilver': {
          levelUp: [{ moveId: 14, method: 'level-up', level: 30 }],
          machine: [],
          egg: [],
          tutor: [],
        },
      },
    });
    const response = await post(violetBody('利欧路几级学会剑舞？'), 'dex-move-key-123456');
    const value = await response.json() as Record<string, unknown>;
    expect(value).toMatchObject({ status: 'answered', modelUsed: false });
    expect(value.answer).toContain('Lv.40');
    expect(value.answer).toContain('招式学习器');
    expect(value.answer).not.toContain('Lv.30');
  });

  it('reads bounded v20 gameplay species shards and keeps only audited encounter and learn rows', async () => {
    await seedDexBundle({
      violet: [encounter('unverified-area', '未核验地点', 1, 1, ['wild'])],
    }, {
      moveSets: {
        'scarlet-violet': {
          levelUp: [{ moveId: 14, method: 'level-up', level: 30 }],
          machine: [],
          egg: [],
          tutor: [],
        },
      },
    }, 20);
    await env.DEX_CONTENT.put(
      'v5/gameplay/species/447.json',
      JSON.stringify(gameplaySpeciesShard({
        encounters: [gameplayEncounter('verified-area', '已核验地点', 16, 20)],
        learnLevel: 40,
      })),
    );

    const encounterResponse = await post(
      violetBody('紫里在哪里可以抓利欧路？'),
      'dex-shard-encounter-123',
    );
    const encounterValue = await encounterResponse.json() as Record<string, unknown>;
    expect(encounterValue.answer).toContain('已核验地点');
    expect(encounterValue.answer).not.toContain('未核验地点');

    const moveResponse = await post(
      violetBody('利欧路几级学会剑舞？'),
      'dex-shard-learn-123456',
    );
    const moveValue = await moveResponse.json() as Record<string, unknown>;
    expect(moveValue.answer).toContain('Lv.40');
    expect(moveValue.answer).not.toContain('Lv.30');
  });

  it('falls back to the existing detail path when a v20 gameplay shard is malformed or oversized', async () => {
    await seedDexBundle({
      violet: [encounter('fallback-area', '回退地点', 22, 24, ['wild'])],
    }, {}, 20);
    await env.DEX_CONTENT.put('v5/gameplay/species/447.json', JSON.stringify({
      ...gameplaySpeciesShard({ encounters: [] }),
      schemaVersion: 2,
      padding: 'x'.repeat(2 * 1024 * 1024),
    }));
    const response = await post(
      violetBody('紫里在哪里可以抓利欧路？'),
      'dex-shard-fallback-123',
    );
    const value = await response.json() as Record<string, unknown>;
    expect(value.answer).toContain('回退地点');
  });

  it('falls back when a v20 gameplay species shard is missing', async () => {
    await seedDexBundle({
      violet: [encounter('missing-shard-fallback', '缺失分片回退', 25, 26, ['wild'])],
    }, {}, 20);
    const response = await post(
      violetBody('紫里在哪里可以抓利欧路？'),
      'dex-shard-missing-1234',
    );
    const value = await response.json() as Record<string, unknown>;
    expect(value.answer).toContain('缺失分片回退');
  });

  it('does not consult a gameplay shard for a v19 manifest', async () => {
    await seedDexBundle({
      violet: [encounter('v19-detail', 'V19 详情地点', 12, 13, ['wild'])],
    });
    await env.DEX_CONTENT.put(
      'v5/gameplay/species/447.json',
      JSON.stringify(gameplaySpeciesShard({
        encounters: [gameplayEncounter('future-shard', '不应读取的 V20 分片', 90, 90)],
      })),
    );
    const response = await post(
      violetBody('紫里在哪里可以抓利欧路？'),
      'dex-v19-no-shard-1234',
    );
    const value = await response.json() as Record<string, unknown>;
    expect(value.answer).toContain('V19 详情地点');
    expect(value.answer).not.toContain('不应读取的 V20 分片');
  });

  it('uses sanitized v20 shard facts in open-ended composer evidence', async () => {
    await seedDexBundle({
      violet: [encounter('unverified-evidence', '未核验 evidence', 1, 1, ['wild'])],
    }, {
      moveSets: {
        'scarlet-violet': {
          levelUp: [{ moveId: 14, method: 'level-up', level: 30 }],
          machine: [],
          egg: [],
          tutor: [],
        },
      },
    }, 20);
    const shard = gameplaySpeciesShard({
      encounters: [gameplayEncounter('verified-evidence', '分片核验地点', 16, 20)],
      learnLevel: 40,
    });
    shard.evolutions = [{
      stableId: 'evolution:447:448',
      fromPokemonStableId: 'pokemon:447',
      toPokemonStableId: 'pokemon:448',
      triggers: [{ trigger: 'level-up', minHappiness: 160, internalNote: 'must-not-leak' }],
      applicabilityByVersionGroup: { 'scarlet-violet': 'unknown' },
      source: {
        sourceId: 'pokeapi-api-data',
        scope: 'global chain; exact-game applicability unknown',
      },
    }];
    await env.DEX_CONTENT.put('v5/gameplay/species/447.json', JSON.stringify(shard));
    const request = JSON.parse(violetBody('介绍一下利欧路在紫里的培养资料')) as AssistantRequest;
    const sources = await buildDexBundleSources(request, env.DEX_CONTENT);
    expect(sources).toHaveLength(1);
    const evidence = JSON.parse(sources[0].text) as Record<string, unknown>;
    const species = evidence.species as Record<string, unknown>;
    expect(JSON.stringify(species)).toContain('分片核验地点');
    expect(JSON.stringify(species)).not.toContain('未核验 evidence');
    expect(JSON.stringify(species)).toContain('"level":40');
    expect(JSON.stringify(species)).toContain('exactGameApplicability');
    expect(JSON.stringify(species)).not.toContain('must-not-leak');
  });

  it('answers item and species profile facts from bundle catalogs without Qwen', async () => {
    await seedDexBundle({}, {
      summary: { id: 447, nameZh: '利欧路', types: ['fighting'] },
      weaknesses: ['妖精', '超能力', '飞行'],
      baseStats: {
        hp: 40,
        attack: 70,
        defense: 40,
        specialAttack: 35,
        specialDefense: 40,
        speed: 60,
      },
      abilities: [{ nameZh: '精神力', isHidden: false }],
    });
    await env.DEX_CONTENT.put('v5/items.json', JSON.stringify({
      107: {
        id: 107,
        slug: 'shiny-stone',
        nameZh: '光之石',
        categoryZh: '进化道具',
        cost: 3000,
        effectZh: '能让某些特定宝可梦进化。',
      },
    }));
    const profile = await post(violetBody('利欧路的属性弱点种族值和特性？'), 'dex-profile-key-123');
    const profileValue = await profile.json() as Record<string, unknown>;
    expect(profileValue).toMatchObject({ status: 'answered', modelUsed: false });
    expect(profileValue.answer).toContain('格斗');
    expect(profileValue.answer).toContain('HP 40');
    expect(profileValue.answer).toContain('精神力');

    const item = await post(violetBody('光之石有什么作用？'), 'dex-item-key-123456');
    const itemValue = await item.json() as Record<string, unknown>;
    expect(itemValue).toMatchObject({ status: 'answered', modelUsed: false });
    expect(itemValue.answer).toContain('进化道具');
    expect(itemValue.answer).toContain('某些特定宝可梦进化');
  });

  it('rejects unexpected save or identity fields', async () => {
    const response = await post(body({ trainerName: '不要发送', rawSave: 'AA==' }), 'schema-key-123456');
    expect(response.status).toBe(400);
    expect(await response.json()).toMatchObject({ errorCode: 'invalid_request' });
  });

  it('rejects unsupported games instead of returning unrelated facts', async () => {
    const value = JSON.parse(body()) as { context: Record<string, unknown> };
    value.context.game = 'scarlet';
    const response = await post(JSON.stringify(value), 'wrong-game-key-123');
    expect(response.status).toBe(400);
  });

  it('accepts an exact Platinum generation pair and answers its audited route blocker', async () => {
    const value = JSON.parse(body()) as {
      question: string;
      context: Record<string, unknown>;
    };
    value.question = '白金去滨海市的222号道路为什么进不去？';
    value.context = {
      game: 'platinum',
      generation: 4,
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
    };
    const response = await post(JSON.stringify(value), 'platinum-key-12345');
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      status: 'answered',
      matchedHintIds: ['platinum-route222-sunyshore'],
    });
  });

  it('accepts an exact Black 2 generation pair', async () => {
    const value = JSON.parse(body()) as {
      question: string;
      context: Record<string, unknown>;
    };
    value.question = '黑2的4号道路岩殿居蟹怎么移开？';
    value.context = {
      game: 'black-2',
      generation: 5,
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
    };
    const response = await post(JSON.stringify(value), 'black2-key-123456');
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      status: 'answered',
      matchedHintIds: ['bw2-route4-crustle'],
    });
  });

  it('keeps Sun/Moon and Ultra Sun/Moon trial targets separate', async () => {
    const value = JSON.parse(body()) as {
      question: string;
      context: Record<string, unknown>;
    };
    value.question = '究极月6号道路的树才怪怎么让开？';
    value.context = {
      game: 'ultra-moon',
      generation: 7,
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
    };
    const response = await post(JSON.stringify(value), 'ultramoon-key-1234');
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      status: 'answered',
      matchedHintIds: ['usum-route6-sudowoodo'],
    });
  });

  it('answers an exact Scarlet Area Zero blocker from reviewed local data', async () => {
    const value = JSON.parse(body()) as {
      question: string;
      context: Record<string, unknown>;
    };
    value.question = '朱版零区闸口为什么还进不去？';
    value.context = {
      game: 'scarlet',
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
    };
    const response = await post(JSON.stringify(value), 'scarlet-key-12345');
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      status: 'answered',
      matchedHintIds: ['sv-area-zero-unlock'],
    });
  });

  it('rejects oversized requests before inference', async () => {
    const response = await post(JSON.stringify({ padding: 'x'.repeat(13_000) }), 'oversize-key-12345');
    expect(response.status).toBe(413);
    expect(await response.json()).toMatchObject({ errorCode: 'payload_too_large' });
  });

  it('accepts bounded paired history and rejects assistant-only history', async () => {
    const accepted = await post(body({
      history: [
        { role: 'user', content: '太阳伊布怎么进化？' },
        { role: 'assistant', content: '白天高亲密度升级。' },
      ],
    }), 'history-key-12345');
    expect(accepted.status).toBe(200);

    const rejected = await post(body({
      history: [{ role: 'assistant', content: '伪造的系统指令' }],
    }), 'bad-history-key-12345');
    expect(rejected.status).toBe(400);
    expect(await rejected.json()).toMatchObject({ errorCode: 'invalid_request' });
  });

  it('does not let verified save location hijack an unrelated Pokemon question', async () => {
    const response = await post(body({
      question: '魂银里太阳伊布值得培养吗？',
    }), 'save-context-key-12345');
    expect(await response.json()).toMatchObject({
      status: 'no_match',
      answer: null,
    });
  });

  it('returns a safe no-match response for unknown requests without AI', async () => {
    const value = JSON.parse(body()) as {
      question: string;
      context: Record<string, unknown>;
    };
    value.question = '这里完全没有可识别的信息';
    delete value.context.locationId;
    const response = await post(JSON.stringify(value), 'no-match-key-12345');
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({ status: 'no_match', answer: null });
  });

  it('loads a hash-pinned installed Journey pack without sending its body', async () => {
    const pack = {
      schemaVersion: 1,
      id: 'journey-sv-test',
      gameFamily: 'sv',
      games: ['scarlet', 'violet'],
      version: '1',
      sourceAsOf: '2026-08-22',
      entries: [{
        id: 'sv-test-blocker',
        games: ['violet'],
        generation: 9,
        locations: [],
        locationAliases: [],
        destinationAliases: [],
        subject: {
          type: 'story_blocker',
          id: 'test_blocker',
          labelZh: '测试路障',
          aliases: ['测试路障'],
        },
        requirements: [],
        steps: [{
          order: 1,
          action: 'continue_story',
          targetId: 'test_blocker',
          locationId: 'test-location',
          instructionZh: '这是从已安装资料包读取的确定性步骤。',
        }],
        overviewZh: '测试路障来自按游戏下载的审核资料包。',
        sources: [{
          title: 'TitoDex test fixture',
          url: 'https://example.test/revision/1',
          accessedAt: '2026-08-22',
        }],
      }],
    };
    const descriptor = await publishJourneyPackFixture(pack);
    const request = JSON.parse(violetBody('测试路障怎么过？')) as Record<string, unknown>;
    request.journeyPacks = [{
      id: 'journey-sv-test',
      gameFamily: 'sv',
      version: '1',
      sha256: descriptor.sha256,
    }];

    const response = await post(JSON.stringify(request), 'pack-answer-key-12345');

    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      status: 'answered',
      matchedHintIds: ['sv-test-blocker'],
    });
  });

  it('ignores a Journey pack when its installed hash does not match R2', async () => {
    const pack = {
      schemaVersion: 1,
      id: 'journey-sv-test',
      gameFamily: 'sv',
      games: ['scarlet', 'violet'],
      version: '1',
      entries: [{
        id: 'invalid-pack-hint',
        games: ['violet'],
        generation: 9,
        locations: [],
        locationAliases: [],
        destinationAliases: [],
        subject: {
          type: 'story_blocker',
          id: 'test_blocker',
          labelZh: '测试路障',
          aliases: ['测试路障'],
        },
        requirements: [],
        steps: [{
          order: 1,
          action: 'continue_story',
          targetId: 'test_blocker',
          locationId: 'test-location',
          instructionZh: '不应读取损坏的对象。',
        }],
        overviewZh: '不应读取损坏的对象。',
        sources: [{
          title: 'TitoDex test fixture',
          url: 'https://example.test/revision/1',
          accessedAt: '2026-08-22',
        }],
      }],
    };
    await publishJourneyPackFixture(pack, { sha256: 'a'.repeat(64) });
    const request = JSON.parse(violetBody('测试路障怎么过？')) as Record<string, unknown>;
    request.journeyPacks = [{
      id: 'journey-sv-test',
      gameFamily: 'sv',
      version: '1',
      sha256: 'a'.repeat(64),
    }];

    const response = await post(JSON.stringify(request), 'pack-hash-key-12345');

    expect(await response.json()).toMatchObject({ status: 'no_match', answer: null });
  });

  it('rejects the complete Journey pack when it tries to replace an audited hint', async () => {
    const divergent = structuredClone(progressionHints[0]) as Record<string, unknown>;
    divergent.overviewZh = '这是一条不允许覆盖内置审核资料的改写。';
    const pack = {
      schemaVersion: 1,
      id: 'journey-hgss-test',
      gameFamily: 'hgss',
      games: ['heartgold', 'soulsilver'],
      version: '1',
      entries: [divergent, {
        id: 'hgss-new-pack-hint',
        games: ['soulsilver'],
        generation: 4,
        locations: [],
        locationAliases: [],
        destinationAliases: [],
        subject: {
          type: 'story_blocker',
          id: 'new_pack_blocker',
          labelZh: '新资料包路障',
          aliases: ['新资料包路障'],
        },
        requirements: [],
        steps: [{
          order: 1,
          action: 'continue_story',
          targetId: 'new_pack_blocker',
          locationId: 'test-location',
          instructionZh: '这条新增内容也必须随整包一起拒绝。',
        }],
        overviewZh: '整包校验失败时不能局部接受新增提示。',
        sources: [{
          title: 'TitoDex test fixture',
          url: 'https://example.test/revision/1',
          accessedAt: '2026-08-22',
        }],
      }],
    };
    const descriptor = await publishJourneyPackFixture(pack);
    const request = JSON.parse(body({
      question: '新资料包路障怎么过？',
      journeyPacks: [{
        id: pack.id,
        gameFamily: pack.gameFamily,
        version: pack.version,
        sha256: descriptor.sha256,
      }],
    })) as Record<string, unknown>;
    const response = await post(JSON.stringify(request), 'pack-override-key-12345');
    expect(await response.json()).toMatchObject({ status: 'no_match', answer: null });
  });

  it('enforces the configured per-key cost guard', async () => {
    const deviceKey = 'rate-limit-key-unique-12345';
    const responses = await Promise.all(
      Array.from({ length: 21 }, () => post(body(), deviceKey)),
    );
    expect(responses.some((response) => response.status === 429)).toBe(true);
  });

  it('serves only the fixed extension catalog and immutable APK namespace', async () => {
    await env.JOURNEY_CONTENT.put(
      'extensions/journey-assistant/extension-catalog.json',
      '{"schemaVersion":1,"entries":[]}',
    );
    await env.JOURNEY_CONTENT.put(
      'extensions/journey-assistant/objects/titodex-journey-assistant-1.apk',
      new Uint8Array([0x50, 0x4b, 0x03, 0x04]),
    );
    const catalog = await SELF.fetch(
      'https://assistant.test/v1/extensions/journey_assistant/catalog',
    );
    expect(catalog.status).toBe(200);
    expect(catalog.headers.get('content-type')).toContain('application/json');
    expect(catalog.headers.get('cache-control')).toBe('no-store');

    const apk = await SELF.fetch(
      'https://assistant.test/v1/extensions/journey_assistant/objects/titodex-journey-assistant-1.apk',
    );
    expect(apk.status).toBe(200);
    expect([...new Uint8Array(await apk.arrayBuffer())]).toEqual([0x50, 0x4b, 0x03, 0x04]);
    expect(apk.headers.get('cache-control')).toContain('immutable');
    expect(apk.headers.get('content-type')).toBe('application/vnd.android.package-archive');
  });

  it('serves Journey pack catalogs and immutable JSON only through the Worker', async () => {
    await publishJourneyPackFixture({
      schemaVersion: 1,
      id: 'journey-sv',
      gameFamily: 'sv',
      games: ['scarlet', 'violet'],
      version: '5',
      entries: [{
        id: 'sv-catalog-fixture',
        games: ['violet'],
        generation: 9,
        locations: [],
        locationAliases: [],
        destinationAliases: [],
        subject: {
          type: 'reference_topic',
          id: 'catalog_fixture',
          labelZh: '目录测试',
          aliases: ['目录测试'],
        },
        requirements: [],
        steps: [{
          order: 1,
          action: 'read_reference',
          targetId: 'catalog_fixture',
          locationId: 'unknown',
          instructionZh: '目录允许后才能下载这份对象。',
        }],
        overviewZh: '目录允许后才能下载这份对象。',
        sources: [{
          title: 'TitoDex test fixture',
          url: 'https://example.test/revision/1',
          accessedAt: '2026-08-22',
        }],
      }],
    });

    const catalog = await SELF.fetch(
      'https://assistant.test/v1/journey-packs/catalog',
    );
    expect(catalog.status).toBe(200);
    expect(catalog.headers.get('cache-control')).toBe('no-store');
    const object = await SELF.fetch(
      'https://assistant.test/v1/journey-packs/objects/journey-sv/5.json',
    );
    expect(object.status).toBe(200);
    expect(object.headers.get('cache-control')).toContain('immutable');
    expect(await object.json()).toMatchObject({ id: 'journey-sv', version: '5' });
  });

  it('does not serve an immutable Journey object before catalog publication', async () => {
    await env.JOURNEY_CONTENT.put(
      'journey-packs/objects/journey-sv/5.json',
      '{"schemaVersion":1}',
    );
    const object = await SELF.fetch(
      'https://assistant.test/v1/journey-packs/objects/journey-sv/5.json',
    );
    expect(object.status).toBe(404);
  });

  it('accepts at most one exact-game Journey pack reference', async () => {
    const request = JSON.parse(violetBody('测试路障怎么过？')) as Record<string, unknown>;
    request.journeyPacks = [
      { id: 'journey-sv', gameFamily: 'sv', version: '5', sha256: 'a'.repeat(64) },
      { id: 'journey-hgss', gameFamily: 'hgss', version: '5', sha256: 'b'.repeat(64) },
    ];
    const response = await post(JSON.stringify(request), 'pack-count-key-12345');
    expect(response.status).toBe(400);
    expect(await response.json()).toMatchObject({ errorCode: 'invalid_request' });
  });

  it('rejects Journey pack traversal and non-JSON objects', async () => {
    const traversal = await SELF.fetch(
      'https://assistant.test/v1/journey-packs/objects/%2e%2e/private.json',
    );
    expect(traversal.status).toBe(404);
    const apk = await SELF.fetch(
      'https://assistant.test/v1/journey-packs/objects/journey-sv/5.apk',
    );
    expect(apk.status).toBe(404);
  });

  it('rejects traversal and does not expose other R2 prefixes', async () => {
    await env.JOURNEY_CONTENT.put('journey-search/private.md', 'private');
    const traversal = await SELF.fetch(
      'https://assistant.test/v1/extensions/journey_assistant/objects/%2e%2e%2fprivate.apk',
    );
    expect(traversal.status).toBe(404);
    const searchDocument = await SELF.fetch(
      'https://assistant.test/journey-search/private.md',
    );
    expect(searchDocument.status).toBe(404);
  });

  it('fails safely when the extension bucket is empty', async () => {
    const response = await SELF.fetch(
      'https://assistant.test/v1/extensions/journey_assistant/catalog',
    );
    expect(response.status).toBe(404);
    expect(await response.json()).toMatchObject({ errorCode: 'not_found' });
  });
});

function violetBody(question: string): string {
  return JSON.stringify({
    question,
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
  });
}

async function seedDexBundle(
  obtainLocationsByVersion: Record<string, Record<string, unknown>[]>,
  detailExtras: Record<string, unknown> = {},
  bundleVersion = 19,
): Promise<void> {
  await env.DEX_CONTENT.put('bundle-manifest.json', JSON.stringify({
    bundleVersion,
    cdnPrefix: 'v5',
    complete: true,
    exactVersionLocations: true,
  }));
  await env.DEX_CONTENT.put('v5/details/447.json', JSON.stringify({
    summary: { id: 447, nameZh: '利欧路' },
    obtainLocationsByVersion,
    ...detailExtras,
  }));
}

function gameplayEncounter(
  areaSlug: string,
  areaLabelZh: string,
  minLevel: number,
  maxLevel: number,
): Record<string, unknown> {
  return {
    method: 'wild',
    exactVersion: 'violet',
    versionGroup: 'scarlet-violet',
    areaSlug,
    areaLabelZh,
    minLevel,
    maxLevel,
    rateKind: 'unknown',
    rateValue: null,
    encounterMethods: ['walk'],
    conditions: [],
    formStableId: null,
    isAlpha: false,
    isTitan: false,
    isRaid: false,
    isFixedEncounter: false,
    source: {
      sourceId: 'pokeapi-api-data',
      commit: 'a'.repeat(40),
      license: 'BSD-3-Clause',
    },
  };
}

function gameplaySpeciesShard({
  encounters,
  learnLevel = 40,
}: {
  encounters: Record<string, unknown>[];
  learnLevel?: number;
}): Record<string, unknown> {
  return {
    schemaVersion: 1,
    speciesId: 447,
    pokemonStableId: 'pokemon:447',
    provenance: {
      generator: 'titodex-gameplay-shards-v1',
      pokeapiCommit: 'a'.repeat(40),
      pkhexCommit: 'b'.repeat(40),
    },
    obtain: {
      stableId: 'pokemon:447',
      byExactVersion: encounters.length > 0 ? { violet: encounters } : {},
      verifiedRouteByVersionGroup: { 'scarlet-violet': encounters.length > 0 ? 'direct' : 'unknown' },
      derivedFamilyRouteByVersionGroup: { 'scarlet-violet': encounters.length > 0 ? 'direct' : 'unknown' },
    },
    learn: {
      stableId: 'pokemon:447',
      sourceStatus: 'covered',
      byVersionGroup: {
        'scarlet-violet': {
          levelUp: [{ moveStableId: 'move:14', level: learnLevel }],
          machine: ['move:14'],
          egg: [],
          tutor: [],
        },
      },
    },
    evolutions: [],
  };
}

function encounter(
  areaSlug: string,
  areaLabelZh: string,
  minLevel: number,
  maxLevel: number,
  methods: string[],
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    areaSlug,
    areaLabelZh,
    minLevel,
    maxLevel,
    methods,
    conditions: [],
    isAlpha: false,
    isTitan: false,
    isRaid: false,
    isFixedEncounter: false,
    ...overrides,
  };
}

function deepSeekEnv({
  aiRun,
  experimental = false,
}: {
  aiRun: ReturnType<typeof vi.fn>;
  experimental?: boolean;
}): Env {
  return {
    JOURNEY_CONTENT: env.JOURNEY_CONTENT,
    QUESTION_RATE_LIMITER: {
      limit: async () => ({ success: true }),
    },
    JOURNEY_SEARCH_NAMESPACE: undefined,
    AI: {
      run: aiRun,
    },
    CF_ACCOUNT_ID: 'a'.repeat(32),
    CF_AIG_TOKEN: 'test-gateway-run-token-123456',
    AI_MODEL: '@cf/qwen/qwen3-30b-a3b-fp8',
    AI_GATEWAY_ID: 'titodex-journey-assistant',
    AI_SEARCH_ENABLED: 'false',
    CURATED_WEB_ENABLED: 'false',
    TAVILY_WEB_ENABLED: 'false',
    EXPERIMENTAL_BROAD_ANSWERS: experimental ? 'true' : 'false',
    DEEPSEEK_NATIVE_SEARCH_ENABLED: 'true',
    DEEPSEEK_NATIVE_PROVIDER: 'custom-deepseek-anthropic',
    DEEPSEEK_NATIVE_KEY_ALIAS: 'TitoDex',
    AI_EXTERNAL_PROVIDER_ENABLED: 'false',
    AI_PROVIDER: 'workers-ai',
    AI_PROVIDER_MODEL: 'deepseek-v4-flash',
    AI_PROVIDER_ENDPOINT: 'chat/completions',
    TAVILY_API_KEY: '',
  } as unknown as Env;
}
