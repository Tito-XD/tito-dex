import type { CuratedSource, ScopeDecision } from './curated_web';
import { POKEMON_WEB_ALLOWED_DOMAINS } from './pokemon_web_sources';

const TAVILY_SEARCH_ENDPOINT = 'https://api.tavily.com/search';
const TAVILY_TIMEOUT_MS = 3_500;
const MAX_TAVILY_RESPONSE_BYTES = 64 * 1024;
const MAX_QUERY_CHARS = 180;
const MAX_RESULT_TEXT_CHARS = 1_500;
const MAX_TOTAL_TEXT_CHARS = 5_000;
const MAX_RESULTS = 6;

/**
 * Fixed server-side allowlist. Neither the App nor model output can add a
 * hostname. 52Poké may appear only as a transient Tavily snippet; TitoDex does
 * not directly fetch, index, persist, or package its page text here.
 */
export const TAVILY_ALLOWED_DOMAINS = POKEMON_WEB_ALLOWED_DOMAINS;
export const TAVILY_52POKE_DOMAINS = ['wiki.52poke.com'] as const;
export const TAVILY_FALLBACK_DOMAINS = TAVILY_ALLOWED_DOMAINS.filter(
  (domain) => domain !== 'wiki.52poke.com',
);

type TavilyDomainMode = 'all' | '52poke' | 'fallback';

type TavilyResult = {
  title: string;
  url: string;
  content: string;
  score: number;
};

/**
 * One bounded Tavily basic search. All failures are optional and fail closed
 * to an empty source list so the caller retains deterministic/no-match output.
 */
export async function searchTavily(
  decision: ScopeDecision,
  exactGameName: string,
  apiKey: string,
  fetcher: typeof fetch = fetch,
  queryMode: 'mixed' | 'english' | 'chinese' = 'mixed',
  idPrefix = 'tavily',
  domainMode: TavilyDomainMode = 'all',
): Promise<CuratedSource[]> {
  const key = apiKey.trim();
  if (!/^[A-Za-z0-9._-]{16,256}$/.test(key)) return [];
  // Broad overview decisions already carry a complete English query. Avoid
  // mixed-language wiki navigation results, whose paired-version shorthand
  // (for example S/V suffix markers) is easy to mistake for factual prose.
  // Entity/location questions keep the Chinese phrase to preserve aliases.
  const broadOverview = decision.pokeApiKind === '' &&
    /(?:beginner guide|Paradox Pok[eé]mon|game mechanics version guide)/iu.test(
      decision.queryEn,
    );
  const queryTerms = broadOverview || queryMode === 'english'
    ? decision.queryEn
    : queryMode === 'chinese'
      ? decision.queryZh
      : `${decision.queryEn} ${decision.queryZh}`;
  const query = `${exactGameName} ${queryTerms}`
    .replace(/\s+/gu, ' ')
    .trim()
    .slice(0, MAX_QUERY_CHARS);
  if (query.length < 2) return [];
  const allowedDomains = domainMode === '52poke'
    ? TAVILY_52POKE_DOMAINS
    : domainMode === 'fallback'
      ? TAVILY_FALLBACK_DOMAINS
      : TAVILY_ALLOWED_DOMAINS;

  let response: Response;
  try {
    response = await fetcher(TAVILY_SEARCH_ENDPOINT, {
      method: 'POST',
      headers: {
        accept: 'application/json',
        authorization: `Bearer ${key}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        query,
        search_depth: 'basic',
        chunks_per_source: 2,
        max_results: MAX_RESULTS,
        topic: 'general',
        include_answer: false,
        include_raw_content: false,
        include_images: false,
        include_favicon: false,
        include_domains: allowedDomains,
        auto_parameters: false,
        exact_match: false,
        include_usage: false,
      }),
      signal: AbortSignal.timeout(TAVILY_TIMEOUT_MS),
    });
  } catch {
    return [];
  }
  if (!response.ok || !response.body) return [];
  const declared = Number(response.headers.get('content-length') ?? '0');
  if (declared > MAX_TAVILY_RESPONSE_BYTES) return [];

  let value: unknown;
  try {
    const bytes = await readBounded(response.body, MAX_TAVILY_RESPONSE_BYTES);
    value = JSON.parse(new TextDecoder().decode(bytes));
  } catch {
    return [];
  }
  if (!isPlainObject(value) || !Array.isArray(value.results)) return [];

  const sources: CuratedSource[] = [];
  let totalTextChars = 0;
  for (const candidate of value.results.slice(0, MAX_RESULTS)) {
    const result = validateResult(candidate, allowedDomains);
    if (!result) continue;
    const remaining = MAX_TOTAL_TEXT_CHARS - totalTextChars;
    if (remaining <= 0) break;
    const text = result.content.slice(0, Math.min(MAX_RESULT_TEXT_CHARS, remaining));
    if (text.length < 20) continue;
    totalTextChars += text.length;
    sources.push({
      id: `${idPrefix}-${sources.length + 1}`,
      title: result.title,
      url: result.url,
      text,
    });
  }
  return sources;
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
  const [english, chinese] = await Promise.all([
    searchTavily(
      decision,
      exactGameName,
      apiKey,
      fetcher,
      'english',
      'tavily-en',
      'fallback',
    ),
    searchTavily(
      decision,
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
  const seenUrls = new Set<string | undefined>();
  const deduplicated = [...english, ...chinese].filter((source) => {
    if (seenUrls.has(source.url)) return false;
    seenUrls.add(source.url);
    return true;
  });
  const selected: CuratedSource[] = [];
  const deferred: CuratedSource[] = [];
  const hosts = new Set<string>();
  for (const source of deduplicated) {
    const host = source.url ? new URL(source.url).hostname : '';
    if (host && !hosts.has(host)) {
      hosts.add(host);
      selected.push(source);
    } else {
      deferred.push(source);
    }
  }
  return [...selected, ...deferred].slice(0, MAX_RESULTS);
}

function validateResult(
  value: unknown,
  allowedDomains: readonly string[],
): TavilyResult | null {
  if (!isPlainObject(value) || typeof value.title !== 'string' ||
      typeof value.url !== 'string' || typeof value.content !== 'string' ||
      typeof value.score !== 'number' || !Number.isFinite(value.score) ||
      value.score < 0 || value.score > 1) {
    return null;
  }
  const title = value.title.replace(/[\u0000-\u001f\u007f]/gu, ' ').trim().slice(0, 160);
  const content = value.content.replace(/[\u0000\u000b\u000c\u007f]/gu, ' ').trim();
  if (!title || content.length < 20 || value.url.length > 2_048) return null;
  let url: URL;
  try {
    url = new URL(value.url);
  } catch {
    return null;
  }
  if (url.protocol !== 'https:' || url.username || url.password ||
      (url.port && url.port !== '443') ||
      !allowedDomains.includes(url.hostname)) {
    return null;
  }
  url.hash = '';
  return { title, url: url.toString(), content, score: value.score };
}

async function readBounded(
  stream: ReadableStream<Uint8Array>,
  maxBytes: number,
): Promise<Uint8Array> {
  const reader = stream.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > maxBytes) {
      await reader.cancel('tavily_response_too_large');
      throw new Error('tavily_response_too_large');
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return bytes;
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
