import type { CuratedSource, ScopeDecision } from './curated_web';
import { POKEMON_WEB_ALLOWED_DOMAINS } from './pokemon_web_sources';

export type SearchProvider = 'exa' | 'tavily';
export type SearchQueryMode = 'mixed' | 'english' | 'chinese';
export type SearchDomainMode = 'all' | '52poke' | 'fallback';
export type SearchOutcome = {
  status: 'ok' | 'empty' | 'quota_exhausted' | 'rate_limited' | 'invalid_key' | 'unavailable';
  sources: CuratedSource[];
};

export const MAX_SEARCH_RESULTS = 6;
export const MAX_SEARCH_RESPONSE_BYTES = 64 * 1024;
export const SEARCH_TIMEOUT_MS = 5_000;

export function validSearchKey(key: string): boolean {
  return /^[A-Za-z0-9._-]{16,256}$/.test(key.trim());
}

export function searchDomains(mode: SearchDomainMode): readonly string[] {
  return mode === '52poke'
    ? ['wiki.52poke.com']
    : mode === 'fallback'
      ? POKEMON_WEB_ALLOWED_DOMAINS.filter((host) => host !== 'wiki.52poke.com')
      : POKEMON_WEB_ALLOWED_DOMAINS;
}

export function searchQuery(
  decision: ScopeDecision,
  exactGameName: string,
  mode: SearchQueryMode,
  domainMode: SearchDomainMode = 'all',
): string {
  const broadOverview = decision.pokeApiKind === '' &&
    /(?:beginner guide|Paradox Pok[eé]mon|game mechanics version guide)/iu.test(decision.queryEn);
  const terms = mode === 'chinese'
    ? decision.queryZh
    : broadOverview || mode === 'english'
      ? decision.queryEn
      : `${decision.queryEn} ${decision.queryZh}`;
  const officialRules = physicalCardRules(decision) && domainMode !== '52poke'
    ? ' official rulebook' : '';
  return `${exactGameName} ${terms}${officialRules}`.replace(/\s+/gu, ' ').trim().slice(0, 180);
}

export function isStrategySearch(decision: ScopeDecision): boolean {
  return physicalCardRules(decision) || /(?:training guide|moveset|viability|配招|培养|攻略|队伍|搭配|打法|推荐|值不值得)/iu
    .test(`${decision.queryEn} ${decision.queryZh}`);
}

function physicalCardRules(decision: ScopeDecision): boolean {
  const terms = `${decision.queryEn} ${decision.queryZh}`;
  return /(?:\bptcg\b|\btcg\b|trading card game|卡牌|集换式)/iu.test(terms) &&
    /(?:rules?|rulebook|energy|deck|attach|能量|回合|牌组|卡组|规则)/iu.test(terms) &&
    !/(?:\bpocket\b|口袋版|袖珍版)/iu.test(terms);
}

export function searchFailure(status: number): SearchOutcome {
  return {
    status: [402, 432, 433].includes(status) ? 'quota_exhausted'
      : status === 429 ? 'rate_limited'
      : status === 401 ? 'invalid_key'
      : 'unavailable',
    sources: [],
  };
}

/** Error bodies may contain credentials or reflected queries; never read/log them. */
export async function readSearchResponse(response: Response): Promise<unknown> {
  if (!response.body) throw new Error('search_response_missing');
  if (Number(response.headers.get('content-length') ?? '0') > MAX_SEARCH_RESPONSE_BYTES) {
    await response.body.cancel();
    throw new Error('search_response_too_large');
  }
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > MAX_SEARCH_RESPONSE_BYTES) {
        await reader.cancel();
        throw new Error('search_response_too_large');
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return JSON.parse(new TextDecoder().decode(bytes));
}

export function collectSearchSources(
  results: unknown[],
  domains: readonly string[],
  contentFor: (value: Record<string, unknown>) => string | null,
  strategy: boolean,
  idPrefix: string,
): CuratedSource[] {
  const sources: CuratedSource[] = [];
  const seen = new Set<string>();
  let remaining = strategy ? 8_000 : 5_000;
  for (const value of results.slice(0, MAX_SEARCH_RESULTS)) {
    if (!isPlainObject(value) || typeof value.title !== 'string' ||
        typeof value.url !== 'string' || value.url.length > 2_048) continue;
    const rawText = contentFor(value);
    if (rawText === null) continue;
    const title = value.title.replace(/[\u0000-\u001f\u007f]/gu, ' ').trim().slice(0, 160);
    const text = rawText.replace(/[\u0000\u000b\u000c\u007f]/gu, ' ').trim()
      .slice(0, Math.min(strategy ? 3_000 : 1_500, remaining));
    if (!title || text.length < 20) continue;
    let url: URL;
    try { url = new URL(value.url); } catch { continue; }
    if (url.protocol !== 'https:' || url.username || url.password ||
        (url.port && url.port !== '443') || !domains.includes(url.hostname)) continue;
    url.hash = '';
    if (seen.has(url.href)) continue;
    seen.add(url.href);
    sources.push({ id: `${idPrefix}-${sources.length + 1}`, title, url: url.href, text });
    remaining -= text.length;
    if (remaining < 20) break;
  }
  return sources;
}

/** URL/host diversity counts as evidence; search engines themselves do not. */
export function mergeSearchSources(pools: CuratedSource[][]): CuratedSource[] {
  const byUrl = new Map<string, CuratedSource>();
  for (const source of pools.flat()) {
    const key = source.url ?? source.id;
    const existing = byUrl.get(key);
    if (!existing) byUrl.set(key, { ...source });
    else if (!existing.text.includes(source.text)) {
      const combined = `${existing.text}\n${source.text}`.slice(0, 3_000);
      if (combined !== existing.text) {
        const providers = new Set([...providersFor(existing), ...providersFor(source)]);
        if (providers.size > 1) existing.searchProviders = [...providers];
        existing.text = combined;
      }
    }
  }
  const selected: CuratedSource[] = [];
  const deferred: CuratedSource[] = [];
  const hosts = new Set<string>();
  for (const source of byUrl.values()) {
    const host = source.url ? new URL(source.url).hostname : '';
    if (host && !hosts.has(host)) { hosts.add(host); selected.push(source); }
    else deferred.push(source);
  }
  return [...selected, ...deferred].slice(0, MAX_SEARCH_RESULTS);
}

function providersFor(source: CuratedSource): SearchProvider[] {
  return source.searchProviders ?? (source.id.startsWith('exa-') ? ['exa']
    : source.id.startsWith('tavily-') ? ['tavily'] : []);
}

export function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
