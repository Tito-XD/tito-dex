import { env, SELF } from 'cloudflare:test';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import worker from '../src/index';

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
    const response = await post(JSON.stringify({ padding: 'x'.repeat(5000) }), 'oversize-key-12345');
    expect(response.status).toBe(413);
    expect(await response.json()).toMatchObject({ errorCode: 'payload_too_large' });
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
): Promise<void> {
  await env.DEX_CONTENT.put('bundle-manifest.json', JSON.stringify({
    bundleVersion: 19,
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
}: {
  aiRun: ReturnType<typeof vi.fn>;
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
