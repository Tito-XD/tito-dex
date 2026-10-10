import { describe, expect, it, vi } from 'vitest';
import { createWebSearch } from '../src/web_search';
import { publicHttpsUrl } from '../src/web_search_common';
import { researchCuratedWeb, type ScopeDecision } from '../src/curated_web';
import type { AssistantRequest } from '../src/contract';

const decision: ScopeDecision = {
  allowed: true, queryZh: '紫版 利欧路 捕捉地点', queryEn: 'Riolu encounter location',
  pokeApiKind: 'pokemon-species', pokeApiSlug: '447',
};
const key = 'exa-test-key-only-123456789';
function json(value: unknown, status = 200) { return new Response(JSON.stringify(value), { status }); }
function row(url: string, text = 'Riolu appears in the South Province in Pokémon Violet.') {
  return { title: 'Riolu encounter location', url, highlights: [text] };
}
const request: AssistantRequest = {
  question: '动画里小智与小霞是什么关系？',
  context: { game: 'general', generation: 0, badgeIds: [], milestoneIds: [], locale: 'zh-Hans', parserRevision: 2 },
};
const translated = { allowed: true, queryZh: '宝可梦动画 小智 小霞 关系',
  queryEn: 'Pokemon anime Ash Misty relationship', pokeApiKind: '', pokeApiSlug: '' };

describe('simple bilingual Exa research', () => {
  it('runs exactly two distinct language searches without domain filters and keeps exact game scope', async () => {
    const fetcher = vi.fn<typeof fetch>(async (_input, init) => {
      const body = JSON.parse(init?.body as string);
      expect(body).not.toHaveProperty('includeDomains');
      expect(body).toMatchObject({ type: 'auto', numResults: 6 });
      return json({ results: Array.from({ length: 6 }, (_, i) => row(`https://guide${i}.org/riolu`)) });
    });
    const sources = await createWebSearch({ exaApiKey: key }, fetcher)
      .searchBilingual(decision, 'Pokémon Violet', '宝可梦 紫');
    const queries = fetcher.mock.calls.map(([, init]) => JSON.parse(init?.body as string).query);
    expect(queries).toEqual(['Pokémon Violet Riolu encounter location', '宝可梦 紫 紫版 利欧路 捕捉地点']);
    expect(fetcher).toHaveBeenCalledTimes(2);
    expect(sources).toHaveLength(6);
  });

  it.each([false, true])('retains the good pool when the other pool is empty or fails (%s)', async (throws) => {
    const fetcher = vi.fn<typeof fetch>(async (_input, init) => {
      const body = JSON.parse(init?.body as string);
      if (body.query.includes('Riolu')) {
        if (throws) throw new DOMException('timeout', 'TimeoutError');
        return json({ results: [] });
      }
      return json({ results: [row('https://new-pokemon-guide.org/riolu')] });
    });
    const sources = await createWebSearch({ exaApiKey: key }, fetcher)
      .searchBilingual(decision, 'Pokémon Violet', '宝可梦 紫');
    expect(fetcher).toHaveBeenCalledTimes(2);
    expect(sources).toHaveLength(1);
    expect(sources[0].id).toBe('exa-zh-1');
  });

  it('deduplicates bare/www site URLs across languages while retaining complementary text', async () => {
    const fetcher = vi.fn<typeof fetch>(async (_input, init) => {
      const english = JSON.parse(init?.body as string).query.includes('Riolu');
      return json({ results: [row(english ? 'https://www.new-guide.org/riolu#en' : 'https://new-guide.org/riolu#zh',
        english ? 'English encounter evidence for Pokémon Violet.' : '中文捕捉证据补充，包括宝可梦紫的具体地点。')] });
    });
    const sources = await createWebSearch({ exaApiKey: key }, fetcher)
      .searchBilingual(decision, 'Pokémon Violet', '宝可梦 紫');
    expect(sources).toHaveLength(1);
    expect(sources[0].text).toContain('English encounter');
    expect(sources[0].text).toContain('中文捕捉');
  });

  it('prepares untranslated terms once and makes no fixed-source or 52Poké requests', async () => {
    const phases: string[] = [];
    const fetcher = vi.fn<typeof fetch>(async (input, init) => {
      expect(input.toString()).toBe('https://api.exa.ai/search');
      expect(JSON.parse(init?.body as string)).not.toHaveProperty('includeDomains');
      return json({ results: [{ title: 'Ash and Misty anime', url: 'https://pokemon-anime-guide.org/ash-misty',
        highlights: ['Ash and Misty travel together in the Pokémon anime.'] }] });
    });
    await researchCuratedWeb(request, async (phase) => {
      phases.push(phase);
      return phase === 'curated-web-queries' ? translated : { supported: false, answer: '', usedSourceIds: [] };
    }, fetcher, () => new Date(), { ...translated, queryEn: '宝可梦动画 小智 小霞' }, { exaApiKey: key });
    expect(phases.filter((phase) => phase === 'curated-web-queries')).toHaveLength(1);
    expect(fetcher).toHaveBeenCalledTimes(2);
    expect(phases).toContain('curated-web-compose');
  });

  it('reuses a valid bilingual classification instead of preparing queries twice', async () => {
    const runner = vi.fn(async () => ({ supported: false, answer: '', usedSourceIds: [] }));
    const fetcher = vi.fn<typeof fetch>(async () => json({ results: [] }));
    await researchCuratedWeb(request, runner, fetcher, () => new Date(), translated, { exaApiKey: key });
    expect(runner).not.toHaveBeenCalled();
    expect(fetcher).toHaveBeenCalledTimes(2);
  });

  it('preserves an explicit prior scope rejection without allowing a second model to override it', async () => {
    const runner = vi.fn(async () => translated);
    const fetcher = vi.fn<typeof fetch>();
    expect(await researchCuratedWeb(request, runner, fetcher, () => new Date(), { allowed: false }, { exaApiKey: key })).toBeNull();
    expect(runner).not.toHaveBeenCalled();
    expect(fetcher).not.toHaveBeenCalled();
  });

  it('does not search when one preparation fails to produce real English terms', async () => {
    const runner = vi.fn(async () => ({ ...translated, queryEn: '小智与小霞的关系' }));
    const fetcher = vi.fn<typeof fetch>();
    const response = await researchCuratedWeb(request, runner, fetcher, () => new Date(), undefined, { exaApiKey: key });
    expect(response).toBeNull();
    expect(runner).toHaveBeenCalledTimes(1);
    expect(fetcher).not.toHaveBeenCalled();
  });
});

describe('public HTTPS citation boundary', () => {
  it.each([
    'https://new-guide.org/pokemon', 'https://www.new-guide.org/pokemon#section',
    'https://8.8.8.8/pokemon', 'https://[2606:4700:4700::1111]/pokemon',
  ])('accepts public URL %s without requiring a site allowlist', (url) => {
    expect(publicHttpsUrl(url)).not.toBeNull();
  });
  it.each([
    'http://new-guide.org/pokemon', 'https://name:secret@new-guide.org/pokemon',
    'https://new-guide.org:8443/pokemon', 'https://localhost/pokemon',
    'https://guide.local/pokemon', 'https://127.0.0.1/pokemon',
    'https://2130706433/pokemon', 'https://0x7f000001/pokemon',
    'https://10.1.2.3/pokemon', 'https://172.16.0.1/pokemon',
    'https://192.168.1.2/pokemon', 'https://169.254.169.254/latest/meta-data',
    'https://100.64.0.1/pokemon', 'https://[::1]/pokemon',
    'https://[::ffff:127.0.0.1]/pokemon', 'https://[fc00::1]/pokemon',
    'https://[fe80::1]/pokemon', 'https://[2002:7f00:1::]/pokemon',
    'https://[2001:db8::1]/pokemon', 'file:///tmp/pokemon',
  ])('rejects non-public or unsafe URL %s', (url) => {
    expect(publicHttpsUrl(url)).toBeNull();
  });
});
