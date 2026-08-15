import { describe, expect, it, vi } from 'vitest';
import type { ScopeDecision } from '../src/curated_web';
import {
  searchTavily,
  TAVILY_ALLOWED_DOMAINS,
} from '../src/tavily_search';

const decision: ScopeDecision = {
  allowed: true,
  queryZh: '紫版 利欧路 捕捉地点',
  queryEn: 'Riolu encounter location',
  pokeApiKind: 'pokemon-species',
  pokeApiSlug: '447',
};

const apiKey = 'x'.repeat(32);

function json(value: unknown, status = 200, headers?: HeadersInit): Response {
  return new Response(JSON.stringify(value), {
    status,
    headers: { 'content-type': 'application/json', ...headers },
  });
}

describe('bounded Tavily allowlist search', () => {
  it('makes one basic search with only server-owned domains and accepts allowlisted results', async () => {
    const fetcher = vi.fn<typeof fetch>(async (input, init) => {
      expect(input.toString()).toBe('https://api.tavily.com/search');
      expect(init?.method).toBe('POST');
      expect(new Headers(init?.headers).get('authorization')).toBe(`Bearer ${apiKey}`);
      const body = JSON.parse(init?.body as string) as Record<string, unknown>;
      expect(body).toMatchObject({
        search_depth: 'basic',
        chunks_per_source: 2,
        max_results: 4,
        include_answer: false,
        include_raw_content: false,
        auto_parameters: false,
      });
      expect(body.query).toContain('Pokémon Violet');
      expect(body.include_domains).toEqual(TAVILY_ALLOWED_DOMAINS);
      expect(JSON.stringify(body)).not.toContain('example.com');
      return json({
        results: [{
          title: 'Riolu - Bulbapedia',
          url: 'https://bulbapedia.bulbagarden.net/wiki/Riolu_(Pok%C3%A9mon)#Game_locations',
          content: 'In Pokémon Scarlet and Violet, Riolu appears in South Province Area Four.',
          score: 0.91,
        }],
      });
    });

    const result = await searchTavily(decision, 'Pokémon Violet', apiKey, fetcher);

    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(result).toEqual([{
      id: 'tavily-1',
      title: 'Riolu - Bulbapedia',
      url: 'https://bulbapedia.bulbagarden.net/wiki/Riolu_(Pok%C3%A9mon)#Game_locations'.replace('#Game_locations', ''),
      text: 'In Pokémon Scarlet and Violet, Riolu appears in South Province Area Four.',
    }]);
  });

  it('drops arbitrary and credentialed result URLs', async () => {
    const fetcher = vi.fn<typeof fetch>(async () => json({
      results: [
        {
          title: 'Untrusted result',
          url: 'https://example.com/pokemon',
          content: 'This content must never become a source even if it looks relevant.',
          score: 0.99,
        },
        {
          title: 'Credentialed result',
          url: 'https://user:pass@www.serebii.net/scarletviolet/riolu.shtml',
          content: 'This URL is syntactically valid but must still be rejected.',
          score: 0.95,
        },
      ],
    }));

    expect(await searchTavily(decision, 'Pokémon Violet', apiKey, fetcher)).toEqual([]);
    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it('keeps broad overview queries exact-game English without mixed wiki terms', async () => {
    const fetcher = vi.fn<typeof fetch>(async (_input, init) => {
      const body = JSON.parse(init?.body as string) as Record<string, unknown>;
      expect(body.query).toBe(
        'Pokémon Violet Paradox Pokémon Bulbapedia definition future Pokémon Area Zero Violet',
      );
      expect(body.query).not.toContain('悖谬');
      return json({ results: [] });
    });

    await searchTavily({
      allowed: true,
      queryZh: '宝可梦 紫 悖谬宝可梦 未来种 第零区',
      queryEn: 'Paradox Pokémon Bulbapedia definition future Pokémon Area Zero Violet',
      pokeApiKind: '',
      pokeApiSlug: '',
    }, 'Pokémon Violet', apiKey, fetcher);

    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it('fails closed on quota errors and oversized responses without retrying', async () => {
    const quotaFetcher = vi.fn<typeof fetch>(async () => json({ detail: 'quota' }, 429));
    expect(await searchTavily(decision, 'Pokémon Violet', apiKey, quotaFetcher)).toEqual([]);
    expect(quotaFetcher).toHaveBeenCalledTimes(1);

    const oversizedFetcher = vi.fn<typeof fetch>(async () => json(
      { results: [] },
      200,
      { 'content-length': String(65 * 1024) },
    ));
    expect(await searchTavily(decision, 'Pokémon Violet', apiKey, oversizedFetcher)).toEqual([]);
    expect(oversizedFetcher).toHaveBeenCalledTimes(1);
  });
});
