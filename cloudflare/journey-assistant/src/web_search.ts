import type { CuratedSource, ScopeDecision } from './curated_web';
import { searchExaWithStatus } from './exa_search';
import { searchTavilyWithStatus } from './tavily_search';
import {
  mergeSearchSources,
  SEARCH_TIMEOUT_MS,
  validSearchKey,
  type SearchDomainMode,
  type SearchProvider,
  type SearchQueryMode,
} from './web_search_common';

export type WebSearchOptions = {
  exaApiKey?: string;
  tavilyApiKey?: string;
  primarySearchProvider?: SearchProvider;
};

/** One instance per user question: failures never leak into other requests. */
export function createWebSearch(options: WebSearchOptions, fetcher: typeof fetch = fetch) {
  const primary = options.primarySearchProvider ?? 'exa';
  const order: SearchProvider[] = primary === 'exa' ? ['exa', 'tavily'] : ['tavily', 'exa'];
  const keys = { exa: options.exaApiKey ?? '', tavily: options.tavilyApiKey ?? '' };
  const configured = order.filter((provider) => validSearchKey(keys[provider]));
  const unavailable = new Set<SearchProvider>();
  // Shared wall-clock budget also includes a rejected preferred-source pass.
  // Keep provider failover inside the App's existing 35-second request window.
  const deadline = Date.now() + 10_000;

  async function search(
    decision: ScopeDecision,
    scopeName: string,
    queryMode: SearchQueryMode,
    domainMode: SearchDomainMode,
    suffix: string,
  ): Promise<CuratedSource[]> {
    for (const provider of configured) {
      if (unavailable.has(provider)) continue;
      const remaining = deadline - Date.now();
      if (remaining <= 0) return [];
      const run = provider === 'exa' ? searchExaWithStatus : searchTavilyWithStatus;
      const result = await run(
        decision, scopeName, keys[provider], fetcher,
        queryMode, `${provider}${suffix}`, domainMode,
        Math.min(SEARCH_TIMEOUT_MS, remaining),
      );
      console.log(JSON.stringify({
        event: 'assistant_web_search', provider, stage: domainMode, queryMode,
        status: result.status, sourceCount: result.sources.length,
      }));
      if (result.status === 'ok') return result.sources;
      // Empty evidence can be query-specific. Account, rate, shape and network
      // failures skip further calls to this provider during this question.
      if (result.status !== 'empty') unavailable.add(provider);
    }
    return [];
  }

  return {
    enabled: configured.length > 0,
    /** One English and one Chinese pool; no staged 52Poké or repeated searches. */
    async searchBilingual(decision: ScopeDecision, englishName: string, chineseName: string) {
      const pools = await Promise.all([
        search(decision, englishName, 'english', 'all', '-en'),
        search(decision, chineseName, 'chinese', 'all', '-zh'),
      ]);
      return mergeSearchSources(pools);
    },
    search52Poke: (decision: ScopeDecision, name: string) =>
      search(decision, name, 'chinese', '52poke', '-52poke'),
    searchFallback: (decision: ScopeDecision, name: string) =>
      search(decision, name, 'mixed', 'fallback', ''),
    async searchFallbackCorroborating(decision: ScopeDecision, name: string) {
      const moveAdvice = /(?:moveset|best moves|配招|推荐.{0,12}招式)/iu.test(
        `${decision.queryEn} ${decision.queryZh}`,
      );
      const englishDecision = moveAdvice ? {
        ...decision,
        queryEn: `${decision.queryEn} competitive ranked battle exact move list`.slice(0, 100),
      } : decision;
      const chineseDecision = moveAdvice ? {
        ...decision,
        queryZh: `${decision.queryZh} 通关 配招 推荐 招式表`.slice(0, 100),
      } : decision;
      const pools = await Promise.all([
        search(englishDecision, name, 'english', 'fallback', '-en'),
        search(chineseDecision, name, 'chinese', 'fallback', '-zh'),
      ]);
      return mergeSearchSources(pools);
    },
  };
}
