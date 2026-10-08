import { afterEach, describe, expect, it, vi } from 'vitest';
import type { ScopeDecision } from '../src/curated_web';
import { createWebSearch } from '../src/web_search';

const decision: ScopeDecision = {
  allowed: true,
  queryZh: '紫版 利欧路 捕捉地点',
  queryEn: 'Riolu encounter location',
  pokeApiKind: 'pokemon-species',
  pokeApiSlug: '447',
};
const exaApiKey = 'exa-test-only-key-0123456789';
const tavilyApiKey = 'tavily-test-only-key-0123456789';
const keys = { exaApiKey, tavilyApiKey };
const wikiUrl = 'https://wiki.52poke.com/wiki/Riolu';
const guideUrl = 'https://www.serebii.net/pokedex-sv/riolu/';

function json(value: unknown, status = 200): Response {
  return new Response(JSON.stringify(value), {
    status, headers: { 'content-type': 'application/json' },
  });
}

function source(url = guideUrl, text = 'Riolu appears in South Province Area Four in Pokémon Violet.') {
  return { title: 'Riolu locations', url, highlights: [text], content: text, score: 0.9 };
}

function host(input: RequestInfo | URL): string {
  return new URL(input.toString()).hostname;
}

afterEach(() => vi.restoreAllMocks());

describe('request-scoped web search failover', () => {
  it('uses Exa first and never calls Tavily when Exa returns usable evidence', async () => {
    const fetcher = vi.fn<typeof fetch>(async () => json({ results: [source()] }));
    const web = createWebSearch(keys, fetcher);
    expect(web.enabled).toBe(true);
    const sources = await web.searchFallback(decision, 'Pokémon Violet');
    expect(sources.map((value) => value.id)).toEqual(['exa-1']);
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(host(fetcher.mock.calls[0][0])).toBe('api.exa.ai');
  });

  it.each([undefined, '', 'invalid'])('uses Tavily when Exa key is absent or invalid', async (exaKey) => {
    const fetcher = vi.fn<typeof fetch>(async () => json({ results: [source()] }));
    const web = createWebSearch({ exaApiKey: exaKey, tavilyApiKey }, fetcher);
    expect((await web.searchFallback(decision, 'Pokémon Violet'))[0].id).toBe('tavily-1');
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(host(fetcher.mock.calls[0][0])).toBe('api.tavily.com');
  });

  it('is disabled and issues no calls when both keys are missing', async () => {
    const fetcher = vi.fn<typeof fetch>();
    const web = createWebSearch({}, fetcher);
    expect(web.enabled).toBe(false);
    expect(await web.search52Poke(decision, '宝可梦 紫')).toEqual([]);
    expect(await web.searchFallback(decision, 'Pokémon Violet')).toEqual([]);
    expect(await web.searchFallbackCorroborating(decision, 'Pokémon Violet')).toEqual([]);
    expect(fetcher).not.toHaveBeenCalled();
  });

  it.each([
    ['exa', 402, 'api.exa.ai', 'api.tavily.com', 'tavily-1'],
    ['tavily', 432, 'api.tavily.com', 'api.exa.ai', 'exa-1'],
  ] as const)('switches away from an exhausted %s account', async (primarySearchProvider, status, primary, backup, id) => {
    const fetcher = vi.fn<typeof fetch>(async (input) => host(input) === primary
      ? json({ error: 'quota exhausted' }, status)
      : json({ results: [source()] }));
    const web = createWebSearch({ ...keys, primarySearchProvider }, fetcher);
    expect((await web.searchFallback(decision, 'Pokémon Violet'))[0].id).toBe(id);
    expect(fetcher.mock.calls.map(([input]) => host(input))).toEqual([primary, backup]);
  });

  it.each([401, 402, 429, 503])('skips Exa in later stages after HTTP %i and retries Exa in a new request', async (status) => {
    let exaCalls = 0;
    const fetcher = vi.fn<typeof fetch>(async (input, init) => {
      if (host(input) === 'api.exa.ai') {
        exaCalls += 1;
        return exaCalls === 1 ? json({ error: 'not usable' }, status) : json({ results: [source(wikiUrl)] });
      }
      const body = JSON.parse(init?.body as string) as { include_domains: string[] };
      return json({ results: [source(body.include_domains.includes('wiki.52poke.com') ? wikiUrl : guideUrl)] });
    });
    const first = createWebSearch(keys, fetcher);
    expect((await first.search52Poke(decision, '宝可梦 紫'))[0].id).toBe('tavily-52poke-1');
    expect((await first.searchFallback(decision, 'Pokémon Violet'))[0].id).toBe('tavily-1');
    expect(exaCalls).toBe(1);
    const second = createWebSearch(keys, fetcher);
    expect((await second.search52Poke(decision, '宝可梦 紫'))[0].id).toBe('exa-52poke-1');
    expect(exaCalls).toBe(2);
  });

  it('falls back on empty evidence but keeps Exa eligible for the next stage', async () => {
    const fetcher = vi.fn<typeof fetch>(async (input, init) => {
      const body = JSON.parse(init?.body as string) as {
        includeDomains?: string[]; include_domains?: string[];
      };
      const primaryStage = (body.includeDomains ?? body.include_domains)?.includes('wiki.52poke.com');
      return json({ results: primaryStage ? [] : [source()] });
    });
    const web = createWebSearch(keys, fetcher);
    expect(await web.search52Poke(decision, '宝可梦 紫')).toEqual([]);
    expect((await web.searchFallback(decision, 'Pokémon Violet'))[0].id).toBe('exa-1');
    expect(fetcher.mock.calls.map(([input]) => host(input))).toEqual([
      'api.exa.ai', 'api.tavily.com', 'api.exa.ai',
    ]);
  });

  it('revalidates 52Poké-only and fallback domain boundaries even if upstream ignores filters', async () => {
    const fetcher = vi.fn<typeof fetch>(async () => json({ results: [source(wikiUrl), source()] }));
    const web = createWebSearch(keys, fetcher);
    expect((await web.search52Poke(decision, '宝可梦 紫')).map((value) => value.url)).toEqual([wikiUrl]);
    expect((await web.searchFallback(decision, 'Pokémon Violet')).map((value) => value.url)).toEqual([guideUrl]);
    const bodies = fetcher.mock.calls.map(([, init]) => JSON.parse(init?.body as string));
    expect(bodies[0].includeDomains).toEqual(['wiki.52poke.com']);
    expect(bodies[1].includeDomains).not.toContain('wiki.52poke.com');
  });

  it('treats a timeout exception as request-scoped unavailability and uses Tavily', async () => {
    const fetcher = vi.fn<typeof fetch>(async (input) => {
      if (host(input) === 'api.exa.ai') throw new DOMException('timed out', 'TimeoutError');
      return json({ results: [source()] });
    });
    const web = createWebSearch(keys, fetcher);
    expect((await web.searchFallback(decision, 'Pokémon Violet'))[0].id).toBe('tavily-1');
    await web.searchFallback(decision, 'Pokémon Violet');
    expect(fetcher.mock.calls.map(([input]) => host(input))).toEqual([
      'api.exa.ai', 'api.tavily.com', 'api.tavily.com',
    ]);
  });

  it('returns empty when both providers fail and avoids later account calls', async () => {
    const fetcher = vi.fn<typeof fetch>(async () => json({ error: 'quota' }, 402));
    const web = createWebSearch(keys, fetcher);
    expect(await web.search52Poke(decision, '宝可梦 紫')).toEqual([]);
    expect(await web.searchFallbackCorroborating(decision, 'Pokémon Violet')).toEqual([]);
    expect(fetcher).toHaveBeenCalledTimes(2);
  });

  it('merges language pools by URL while preserving complementary snippets', async () => {
    const queries: string[] = [];
    const fetcher = vi.fn<typeof fetch>(async (_input, init) => {
      const body = JSON.parse(init?.body as string) as { query: string; includeDomains: string[] };
      queries.push(body.query);
      expect(body.includeDomains).not.toContain('wiki.52poke.com');
      const english = body.query.includes('competitive ranked battle');
      return json({ results: [source(
        'https://game8.co/games/Pokemon-Scarlet-Violet/archives/401366',
        english
          ? 'Competitive moveset: Close Combat, Bullet Punch, Extreme Speed.'
          : 'Story moveset: Extreme Speed, Close Combat, Dragon Pulse, Swords Dance.',
      )] });
    });
    const web = createWebSearch(keys, fetcher);
    const sources = await web.searchFallbackCorroborating({
      ...decision, queryZh: '紫版 路卡利欧 配招', queryEn: 'Lucario best moveset build',
    }, 'Pokémon Violet');
    expect(queries).toHaveLength(2);
    expect(queries.some((query) => query.includes('competitive ranked battle'))).toBe(true);
    expect(queries.some((query) => query.includes('通关 配招 推荐 招式表'))).toBe(true);
    expect(sources).toHaveLength(1);
    expect(sources[0].text).toContain('Competitive moveset');
    expect(sources[0].text).toContain('Story moveset');
    expect(fetcher.mock.calls.every(([input]) => host(input) === 'api.exa.ai')).toBe(true);
  });

  it('does not call the backup or later stages once the shared 10-second budget expires', async () => {
    let now = 1_000;
    vi.spyOn(Date, 'now').mockImplementation(() => now);
    const fetcher = vi.fn<typeof fetch>(async () => {
      now += 10_000;
      return json({ results: [] });
    });
    const web = createWebSearch(keys, fetcher);
    expect(await web.search52Poke(decision, '宝可梦 紫')).toEqual([]);
    expect(await web.searchFallback(decision, 'Pokémon Violet')).toEqual([]);
    expect(await web.searchFallbackCorroborating(decision, 'Pokémon Violet')).toEqual([]);
    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it('keeps both actual providers when one URL combines their complementary text', async () => {
    const fetcher = vi.fn<typeof fetch>(async (input, init) => {
      const body = JSON.parse(init?.body as string) as { query: string };
      const english = body.query.includes('competitive ranked battle');
      if (host(input) === 'api.exa.ai' && !english) return json({ results: [] });
      return json({ results: [source(guideUrl, english
        ? 'Competitive moveset evidence from the English retrieval pool.'
        : 'Story moveset evidence from the Chinese retrieval pool.')] });
    });
    const sources = await createWebSearch(keys, fetcher).searchFallbackCorroborating({
      ...decision, queryEn: 'Lucario best moveset', queryZh: '路卡利欧配招',
    }, 'Pokémon Violet');
    expect(sources).toHaveLength(1);
    expect(sources[0].searchProviders).toEqual(['exa', 'tavily']);
    expect(sources[0].text).toContain('Competitive moveset');
    expect(sources[0].text).toContain('Story moveset');
  });

  it('counts elapsed time between primary composition and the next search stage', async () => {
    let now = 1_000;
    vi.spyOn(Date, 'now').mockImplementation(() => now);
    const fetcher = vi.fn<typeof fetch>(async () => json({ results: [source(wikiUrl)] }));
    const web = createWebSearch(keys, fetcher);
    expect(await web.search52Poke(decision, '宝可梦 紫')).toHaveLength(1);
    now += 10_001;
    expect(await web.searchFallback(decision, 'Pokémon Violet')).toEqual([]);
    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it('logs only operational fields without query, key, snippets or provider error body', async () => {
    const log = vi.spyOn(console, 'log').mockImplementation(() => undefined);
    const privateQuery = 'private-query-marker';
    const privateBody = 'private-provider-error-marker';
    const fetcher = vi.fn<typeof fetch>(async (input) => host(input) === 'api.exa.ai'
      ? json({ error: `${privateBody} ${exaApiKey}` }, 402)
      : json({ results: [source(guideUrl, `private-source-marker ${'details '.repeat(5)}`)] }));
    await createWebSearch(keys, fetcher).searchFallback({
      ...decision, queryZh: privateQuery, queryEn: privateQuery,
    }, 'Pokémon Violet');
    const messages = log.mock.calls.flat().map(String);
    const serialized = messages.join('\n');
    expect(messages.map((message) => JSON.parse(message))).toEqual([
      {
        event: 'assistant_web_search', provider: 'exa', stage: 'fallback',
        queryMode: 'mixed', status: 'quota_exhausted', sourceCount: 0,
      },
      {
        event: 'assistant_web_search', provider: 'tavily', stage: 'fallback',
        queryMode: 'mixed', status: 'ok', sourceCount: 1,
      },
    ]);
    for (const sensitive of [privateQuery, privateBody, exaApiKey, tavilyApiKey, 'private-source-marker']) {
      expect(serialized).not.toContain(sensitive);
    }
  });
});
