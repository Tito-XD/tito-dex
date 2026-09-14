import { describe, expect, it } from 'vitest';
import { parseDeepSeekNativeResponse } from '../src/deepseek_native_search';
import { searchTavily } from '../src/tavily_search';

const officialRuleUrls = [
  'https://assets.pokemon.com/assets/cms2/pdf/trading-card-game/rulebook/pal_rulebook_en.pdf',
  'https://asia.pokemon-card.com/sg/wp-content/uploads/sites/6/2025/10/EN_advanced_manual-2025.pdf',
];
const invalidRuleUrls = [
  'https://assets.pokemon.com.attacker.example/rules.pdf',
  'https://unreviewed.asia.pokemon-card.com/rules.pdf',
  'https://user:pass@assets.pokemon.com/rules.pdf',
];

function searchedRule(url: string): Record<string, unknown> {
  const title = 'Pokémon Trading Card Game Rulebook';
  return {
    type: 'message', stop_reason: 'end_turn',
    content: [
      { type: 'server_tool_use', id: 'rules-search', name: 'web_search', input: { query: title } },
      { type: 'web_search_tool_result', tool_use_id: 'rules-search', content: [
        { type: 'web_search_result', title, url, encrypted_content: 'opaque' },
      ] },
      { type: 'text', text: '基本能量不受同名四张上限，特殊能量按卡面规则处理。', citations: [
        { type: 'web_search_result_location', title, url, cited_text: 'Basic Energy is exempt from the four-card limit.' },
      ] },
    ],
  };
}

describe('official card-rule evidence boundary', () => {
  it.each(officialRuleUrls)('accepts the reviewed official host: %s', async (url) => {
    const native = parseDeepSeekNativeResponse(searchedRule(url));
    expect(native.status).toBe('answered');
    if (native.status === 'answered') expect(native.sources[0].url).toBe(url);
    const sources = await tavilyRule(url);
    expect(sources).toHaveLength(1);
    expect(sources[0].url).toBe(url);
  });

  it.each(invalidRuleUrls)('rejects unreviewed hosts and credentials: %s', async (url) => {
    expect(parseDeepSeekNativeResponse(searchedRule(url)).status).toBe('unavailable');
    expect(await tavilyRule(url)).toEqual([]);
  });
});

async function tavilyRule(url: string) {
  return searchTavily({
    allowed: true, queryZh: 'PTCG 基础能量规则', queryEn: 'Pokemon TCG basic Energy rules',
    pokeApiKind: '', pokeApiSlug: '',
  }, 'Pokémon', 'x'.repeat(32), async () => new Response(JSON.stringify({ results: [{
    title: 'Pokémon Trading Card Game Rulebook', url,
    content: 'Basic Energy is exempt from the four-card limit.', score: 0.99,
  }] }), { headers: { 'content-type': 'application/json' } }));
}
