import type { CuratedSource, ScopeDecision } from './curated_web';
import { POKEMON_WEB_ALLOWED_DOMAINS } from './pokemon_web_sources';
import {
  collectSearchSources,
  isPlainObject,
  isStrategySearch,
  MAX_SEARCH_RESULTS,
  mergeSearchSources,
  readSearchResponse,
  searchDomains,
  searchFailure,
  searchQuery,
  SEARCH_TIMEOUT_MS,
  validSearchKey,
  type SearchDomainMode,
  type SearchOutcome,
  type SearchQueryMode,
} from './web_search_common';

const TAVILY_SEARCH_ENDPOINT = 'https://api.tavily.com/search';
export const TAVILY_ALLOWED_DOMAINS = POKEMON_WEB_ALLOWED_DOMAINS;
export const TAVILY_52POKE_DOMAINS = ['wiki.52poke.com'] as const;
export const TAVILY_FALLBACK_DOMAINS = TAVILY_ALLOWED_DOMAINS.filter(
  (domain) => domain !== 'wiki.52poke.com',
);

/** Compatibility wrapper for callers that only need bounded evidence. */
export async function searchTavily(
  decision: ScopeDecision,
  exactGameName: string,
  apiKey: string,
  fetcher: typeof fetch = fetch,
  queryMode: SearchQueryMode = 'mixed',
  idPrefix = 'tavily',
  domainMode: SearchDomainMode = 'all',
): Promise<CuratedSource[]> {
  return (await searchTavilyWithStatus(
    decision, exactGameName, apiKey, fetcher, queryMode, idPrefix, domainMode,
  )).sources;
}

/** Status distinguishes account/quota failures from an ordinary empty search. */
export async function searchTavilyWithStatus(
  decision: ScopeDecision,
  exactGameName: string,
  apiKey: string,
  fetcher: typeof fetch = fetch,
  queryMode: SearchQueryMode = 'mixed',
  idPrefix = 'tavily',
  domainMode: SearchDomainMode = 'all',
  timeoutMs = SEARCH_TIMEOUT_MS,
): Promise<SearchOutcome> {
  const key = apiKey.trim();
  if (!validSearchKey(key)) return { status: 'invalid_key', sources: [] };
  const query = searchQuery(decision, exactGameName, queryMode, domainMode);
  if (query.length < 2) return { status: 'empty', sources: [] };
  const strategy = isStrategySearch(decision);
  const domains = searchDomains(domainMode);
  try {
    const response = await fetcher(TAVILY_SEARCH_ENDPOINT, {
      method: 'POST',
      redirect: 'manual',
      headers: {
        accept: 'application/json',
        authorization: `Bearer ${key}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        query,
        search_depth: strategy ? 'advanced' : 'basic',
        ...(strategy ? { chunks_per_source: 3 } : {}),
        max_results: MAX_SEARCH_RESULTS,
        topic: 'general',
        include_answer: false,
        include_raw_content: false,
        include_images: false,
        include_favicon: false,
        include_domains: domains,
        auto_parameters: false,
        exact_match: false,
        include_usage: false,
      }),
      signal: AbortSignal.timeout(timeoutMs),
    });
    if (!response.ok) {
      await response.body?.cancel();
      return searchFailure(response.status);
    }
    const value = await readSearchResponse(response);
    if (!isPlainObject(value) || !Array.isArray(value.results)) {
      return { status: 'unavailable', sources: [] };
    }
    const sources = collectSearchSources(value.results, domains, (result) => {
      if (typeof result.content !== 'string' || typeof result.score !== 'number' ||
          !Number.isFinite(result.score) || result.score < 0 || result.score > 1) return null;
      return result.content;
    }, strategy, idPrefix);
    return { status: sources.length ? 'ok' : 'empty', sources };
  } catch {
    return { status: 'unavailable', sources: [] };
  }
}

/** First-pass Chinese retrieval. Its result boundary is 52Poké only. */
export function searchTavily52Poke(
  decision: ScopeDecision,
  exactGameName: string,
  apiKey: string,
  fetcher: typeof fetch = fetch,
): Promise<CuratedSource[]> {
  return searchTavily(
    decision,
    exactGameName,
    apiKey,
    fetcher,
    'chinese',
    'tavily-52poke',
    '52poke',
  );
}

/** Second-pass mixed-language retrieval after 52Poké has no supported answer. */
export function searchTavilyFallback(
  decision: ScopeDecision,
  exactGameName: string,
  apiKey: string,
  fetcher: typeof fetch = fetch,
): Promise<CuratedSource[]> {
  return searchTavily(
    decision,
    exactGameName,
    apiKey,
    fetcher,
    'mixed',
    'tavily',
    'fallback',
  );
}

/**
 * Broad advice benefits from independent English and Chinese result pools.
 * Both bounded searches run concurrently, then results are deduplicated and
 * selected by hostname diversity before entering the model context.
 */
export async function searchTavilyCorroborating(
  decision: ScopeDecision,
  exactGameName: string,
  apiKey: string,
  fetcher: typeof fetch = fetch,
): Promise<CuratedSource[]> {
  const [english, chinese] = await Promise.all([
    searchTavily(decision, exactGameName, apiKey, fetcher, 'english', 'tavily-en'),
    searchTavily(decision, exactGameName, apiKey, fetcher, 'chinese', 'tavily-zh'),
  ]);
  return mergeCorroboratingSources(english, chinese);
}

/** Two independent fallback pools, both excluding the already-tried 52Poké. */
export async function searchTavilyFallbackCorroborating(
  decision: ScopeDecision,
  exactGameName: string,
  apiKey: string,
  fetcher: typeof fetch = fetch,
): Promise<CuratedSource[]> {
  const moveAdvice = /(?:moveset|best moves|配招|推荐.{0,12}招式)/iu.test(
    `${decision.queryEn} ${decision.queryZh}`,
  );
  const englishDecision = moveAdvice
    ? {
        ...decision,
        queryEn: `${decision.queryEn} competitive ranked battle exact move list`
          .slice(0, 100),
      }
    : decision;
  const chineseDecision = moveAdvice
    ? {
        ...decision,
        queryZh: `${decision.queryZh} 通关 配招 推荐 招式表`.slice(0, 100),
      }
    : decision;
  const [english, chinese] = await Promise.all([
    searchTavily(
      englishDecision,
      exactGameName,
      apiKey,
      fetcher,
      'english',
      'tavily-en',
      'fallback',
    ),
    searchTavily(
      chineseDecision,
      exactGameName,
      apiKey,
      fetcher,
      'chinese',
      'tavily-zh',
      'fallback',
    ),
  ]);
  return mergeCorroboratingSources(english, chinese);
}

function mergeCorroboratingSources(
  english: CuratedSource[],
  chinese: CuratedSource[],
): CuratedSource[] {
  return mergeSearchSources([english, chinese]);
}
