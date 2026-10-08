import type { CuratedSource, ScopeDecision } from './curated_web';
import {
  collectSearchSources,
  isPlainObject,
  isStrategySearch,
  MAX_SEARCH_RESULTS,
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

const EXA_SEARCH_ENDPOINT = 'https://api.exa.ai/search';

export async function searchExa(
  decision: ScopeDecision,
  exactGameName: string,
  apiKey: string,
  fetcher: typeof fetch = fetch,
  queryMode: SearchQueryMode = 'mixed',
  idPrefix = 'exa',
  domainMode: SearchDomainMode = 'all',
): Promise<CuratedSource[]> {
  return (await searchExaWithStatus(
    decision, exactGameName, apiKey, fetcher, queryMode, idPrefix, domainMode,
  )).sources;
}

/** One bounded retrieval request. No answer endpoint, page archive, or retry. */
export async function searchExaWithStatus(
  decision: ScopeDecision,
  exactGameName: string,
  apiKey: string,
  fetcher: typeof fetch = fetch,
  queryMode: SearchQueryMode = 'mixed',
  idPrefix = 'exa',
  domainMode: SearchDomainMode = 'all',
  timeoutMs = SEARCH_TIMEOUT_MS,
): Promise<SearchOutcome> {
  const key = apiKey.trim();
  if (!validSearchKey(key)) return { status: 'invalid_key', sources: [] };
  const query = searchQuery(decision, exactGameName, queryMode, domainMode);
  if (query.length < 2) return { status: 'empty', sources: [] };
  const domains = searchDomains(domainMode);
  const strategy = isStrategySearch(decision);
  try {
    const response = await fetcher(EXA_SEARCH_ENDPOINT, {
      method: 'POST',
      redirect: 'manual',
      headers: {
        accept: 'application/json',
        'x-api-key': key,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        query,
        type: 'auto',
        numResults: MAX_SEARCH_RESULTS,
        includeDomains: domains,
        contents: {
          highlights: { query, maxCharacters: strategy ? 3_000 : 1_500 },
          livecrawlTimeout: 2_000,
        },
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
      // Use retrieved highlights only; generated summaries are not evidence.
      if (!Array.isArray(result.highlights) ||
          !result.highlights.every((highlight) => typeof highlight === 'string')) return null;
      return result.highlights.join('\n');
    }, strategy, idPrefix);
    return { status: sources.length ? 'ok' : 'empty', sources };
  } catch {
    return { status: 'unavailable', sources: [] };
  }
}
