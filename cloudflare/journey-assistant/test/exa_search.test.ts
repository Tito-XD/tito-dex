import { afterEach, describe, expect, it, vi } from 'vitest';
import type { ScopeDecision } from '../src/curated_web';
import { searchExa, searchExaWithStatus } from '../src/exa_search';
import { POKEMON_WEB_ALLOWED_DOMAINS } from '../src/pokemon_web_sources';
import { MAX_SEARCH_RESPONSE_BYTES } from '../src/web_search_common';

const decision: ScopeDecision = {
  allowed: true,
  queryZh: '紫版 利欧路 捕捉地点',
  queryEn: 'Riolu encounter location',
  pokeApiKind: 'pokemon-species',
  pokeApiSlug: '447',
};
const apiKey = 'exa-test-only-key-0123456789';
const wikiUrl = 'https://wiki.52poke.com/wiki/Riolu';
const guideUrl = 'https://www.serebii.net/pokedex-sv/riolu/';

function json(value: unknown, status = 200, headers?: HeadersInit): Response {
  return new Response(JSON.stringify(value), {
    status,
    headers: { 'content-type': 'application/json', ...headers },
  });
}

function result(url = guideUrl, highlights = ['Riolu appears in South Province Area Four in Pokémon Violet.']) {
  return { title: 'Riolu locations', url, highlights };
}

afterEach(() => vi.restoreAllMocks());

describe('bounded Exa allowlist retrieval', () => {
  it('uses fixed search endpoint, domain filters and bounded highlights without score', async () => {
    const fetcher = vi.fn<typeof fetch>(async (input, init) => {
      expect(input.toString()).toBe('https://api.exa.ai/search');
      expect(init?.method).toBe('POST');
      expect(new Request(input, init).redirect).toBe('manual');
      const headers = new Headers(init?.headers);
      expect(headers.get('x-api-key')).toBe(apiKey);
      expect(headers.get('authorization')).toBeNull();
      const body = JSON.parse(init?.body as string) as Record<string, unknown>;
      expect(body).toMatchObject({
        type: 'auto',
        numResults: 6,
        includeDomains: POKEMON_WEB_ALLOWED_DOMAINS,
        contents: {
          highlights: { maxCharacters: 1_500 },
          livecrawlTimeout: 2_000,
        },
      });
      expect(body.query).toBe('Pokémon Violet Riolu encounter location 紫版 利欧路 捕捉地点');
      expect(body).not.toHaveProperty('outputSchema');
      expect(body.contents).not.toHaveProperty('text');
      expect(body.contents).not.toHaveProperty('summary');
      expect(init?.signal).toBeInstanceOf(AbortSignal);
      return json({ results: [result(`${guideUrl}#Game_locations`)] });
    });

    expect(await searchExa(decision, 'Pokémon Violet', apiKey, fetcher)).toEqual([{
      id: 'exa-1',
      title: 'Riolu locations',
      url: guideUrl,
      text: 'Riolu appears in South Province Area Four in Pokémon Violet.',
    }]);
    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it('isolates Chinese 52Poké results and excludes 52Poké from fallback results', async () => {
    const bodies: Record<string, unknown>[] = [];
    const fetcher = vi.fn<typeof fetch>(async (_input, init) => {
      bodies.push(JSON.parse(init?.body as string) as Record<string, unknown>);
      return json({ results: [result(wikiUrl), result(guideUrl)] });
    });
    const primary = await searchExa(
      decision, '宝可梦 紫', apiKey, fetcher, 'chinese', 'exa-52poke', '52poke',
    );
    const fallback = await searchExa(
      decision, 'Pokémon Violet', apiKey, fetcher, 'mixed', 'exa', 'fallback',
    );

    expect(bodies[0].includeDomains).toEqual(['wiki.52poke.com']);
    expect(bodies[0].query).toBe('宝可梦 紫 紫版 利欧路 捕捉地点');
    expect(primary.map((source) => source.url)).toEqual([wikiUrl]);
    expect(primary[0].id).toBe('exa-52poke-1');
    expect(bodies[1].includeDomains).toEqual(
      POKEMON_WEB_ALLOWED_DOMAINS.filter((host) => host !== 'wiki.52poke.com'),
    );
    expect(fallback.map((source) => source.url)).toEqual([guideUrl]);
  });

  it('never substitutes full text, generated summaries or top-level synthesized output', async () => {
    const fetcher = vi.fn<typeof fetch>(async () => json({
      results: [
        { title: 'Text only', url: guideUrl, text: 'A full page with enough text must never become evidence.' },
        { title: 'Summary only', url: wikiUrl, summary: 'Generated text is long enough but cannot become evidence.' },
        { ...result(), highlights: [] },
        { ...result(), highlights: ['Valid fragment with enough characters.', 123] },
      ],
      output: { content: 'An externally generated answer must be ignored.' },
      context: 'Legacy combined full text must also be ignored.',
    }));

    expect(await searchExaWithStatus(decision, 'Pokémon Violet', apiKey, fetcher)).toEqual({
      status: 'empty', sources: [],
    });
  });

  it.each([
    'https://example.com/pokemon',
    'https://www.serebii.net.attacker.test/riolu',
    'https://evil.www.serebii.net/riolu',
    'http://www.serebii.net/riolu',
    'https://user:password@www.serebii.net/riolu',
    'https://www.serebii.net:8443/riolu',
    'javascript:alert(1)',
    'not a URL',
  ])('rejects result URL %s while retaining a valid allowlisted source', async (url) => {
    const fetcher = vi.fn<typeof fetch>(async () => json({
      results: [result(url), result(guideUrl)],
    }));
    const sources = await searchExa(decision, 'Pokémon Violet', apiKey, fetcher);
    expect(sources).toHaveLength(1);
    expect(sources[0].url).toBe(guideUrl);
  });

  it('deduplicates fragment variants of the same URL', async () => {
    const fetcher = vi.fn<typeof fetch>(async () => json({
      results: [result(`${guideUrl}#first`), result(`${guideUrl}#second`)],
    }));
    const sources = await searchExa(decision, 'Pokémon Violet', apiKey, fetcher);
    expect(sources).toHaveLength(1);
    expect(sources[0].url).toBe(guideUrl);
  });

  it('bounds accepted result count and total text even when upstream ignores limits', async () => {
    const fetcher = vi.fn<typeof fetch>(async () => json({
      results: Array.from({ length: 8 }, (_, index) => result(
        `${guideUrl}${index}`, ['X'.repeat(3_000)],
      )),
    }));
    const sources = await searchExa(decision, 'Pokémon Violet', apiKey, fetcher);
    expect(sources.length).toBeLessThanOrEqual(6);
    expect(sources.every((source) => source.text.length <= 1_500)).toBe(true);
    expect(sources.reduce((total, source) => total + source.text.length, 0)).toBe(5_000);
  });

  it('requests a bounded larger highlight budget only for strategy questions', async () => {
    const fetcher = vi.fn<typeof fetch>(async (_input, init) => {
      expect(JSON.parse(init?.body as string).contents.highlights.maxCharacters).toBe(3_000);
      return json({ results: [result(guideUrl, ['A'.repeat(4_000)])] });
    });
    const sources = await searchExa({
      ...decision, queryZh: '紫版 路卡利欧 配招', queryEn: 'Lucario moveset training guide',
    }, 'Pokémon Violet', apiKey, fetcher);
    expect(sources[0].text).toHaveLength(3_000);
  });

  it.each(['', 'short', 'contains secret spaces', 'x'.repeat(257)])(
    'rejects invalid key without issuing a request', async (key) => {
      const fetcher = vi.fn<typeof fetch>();
      expect(await searchExaWithStatus(decision, 'Pokémon Violet', key, fetcher)).toEqual({
        status: 'invalid_key', sources: [],
      });
      expect(fetcher).not.toHaveBeenCalled();
    },
  );

  it.each([
    [402, 'quota_exhausted'],
    [429, 'rate_limited'],
    [401, 'invalid_key'],
    [403, 'unavailable'],
    [503, 'unavailable'],
  ] as const)('returns status for HTTP %i and cancels the error body without reading it', async (status, expected) => {
    const cancelled = vi.fn();
    const body = new ReadableStream<Uint8Array>({ cancel: cancelled });
    const fetcher = vi.fn<typeof fetch>(async () => new Response(body, { status }));
    expect(await searchExaWithStatus(decision, 'Pokémon Violet', apiKey, fetcher)).toEqual({
      status: expected, sources: [],
    });
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(cancelled).toHaveBeenCalledTimes(1);
  });

  it('cancels a stream whose actual UTF-8 bytes exceed the bound despite a false content length', async () => {
    const cancelled = vi.fn();
    const bytes = new TextEncoder().encode(JSON.stringify({
      results: [result(guideUrl, ['汉'.repeat(30_000)])],
    }));
    expect(bytes.byteLength).toBeGreaterThan(MAX_SEARCH_RESPONSE_BYTES);
    const body = new ReadableStream<Uint8Array>({
      start(controller) {
        controller.enqueue(bytes.slice(0, 32_000));
        controller.enqueue(bytes.slice(32_000, 64_000));
        controller.enqueue(bytes.slice(64_000));
      },
      cancel: cancelled,
    });
    const fetcher = vi.fn<typeof fetch>(async () => new Response(body, {
      headers: { 'content-length': '1' },
    }));
    expect(await searchExaWithStatus(decision, 'Pokémon Violet', apiKey, fetcher)).toEqual({
      status: 'unavailable', sources: [],
    });
    expect(cancelled).toHaveBeenCalledTimes(1);
  });

  it('rejects a redirect without forwarding the key to another endpoint', async () => {
    const fetcher = vi.fn<typeof fetch>(async (input, init) => {
      expect(new Request(input, init).redirect).toBe('manual');
      return new Response(null, { status: 302, headers: { location: 'https://example.com/collect' } });
    });
    expect(await searchExaWithStatus(decision, 'Pokémon Violet', apiKey, fetcher))
      .toEqual({ status: 'unavailable', sources: [] });
    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it('cancels a declared oversized response', async () => {
    const cancelled = vi.fn();
    const fetcher = vi.fn<typeof fetch>(async () => new Response(
      new ReadableStream<Uint8Array>({ cancel: cancelled }),
      { headers: { 'content-length': String(MAX_SEARCH_RESPONSE_BYTES + 1) } },
    ));
    expect((await searchExaWithStatus(decision, 'Pokémon Violet', apiKey, fetcher)).status)
      .toBe('unavailable');
    expect(cancelled).toHaveBeenCalledTimes(1);
  });

  it.each([
    null, [], {}, { results: {} },
  ])('fails closed on malformed result containers', async (value) => {
    const fetcher = vi.fn<typeof fetch>(async () => json(value));
    expect((await searchExaWithStatus(decision, 'Pokémon Violet', apiKey, fetcher)).status)
      .toBe('unavailable');
  });

  it('fails closed on invalid JSON without retrying', async () => {
    const fetcher = vi.fn<typeof fetch>(async () => new Response('{not JSON'));
    expect(await searchExa(decision, 'Pokémon Violet', apiKey, fetcher)).toEqual([]);
    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it('lets the supplied timeout abort the request and returns unavailable without retrying', async () => {
    const fetcher = vi.fn<typeof fetch>(async (_input, init) => new Promise<Response>((_resolve, reject) => {
      const signal = init?.signal;
      if (!signal) throw new Error('expected timeout signal');
      const abort = () => reject(signal.reason);
      if (signal.aborted) abort();
      else signal.addEventListener('abort', abort, { once: true });
    }));
    expect(await searchExaWithStatus(
      decision, 'Pokémon Violet', apiKey, fetcher, 'mixed', 'exa', 'all', 20,
    )).toEqual({ status: 'unavailable', sources: [] });
    expect(fetcher).toHaveBeenCalledTimes(1);
  });
});
