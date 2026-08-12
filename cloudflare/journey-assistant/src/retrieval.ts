import { effectiveContextReliability, type AssistantRequest } from './contract';
import type { ProgressionHint } from './progression_hints';

const MAX_SEARCH_RESULTS = 6;
// BGE-M3's reviewed HGSS paraphrase smoke cases cluster just above 0.51.
// Keep the threshold conservative and always enforce the local hint allowlist
// plus game/generation/audited metadata before accepting a result.
const MIN_SEARCH_SCORE = 0.51;

export type SearchBinding = Pick<AiSearchInstance, 'search'>;
export type SearchNamespaceBinding = {
  get(name: string): SearchBinding;
};

const JOURNEY_SEARCH_INSTANCE = 'titodex-journey-search';

/** Resolve the non-default namespace instance only after retrieval is enabled. */
export function getJourneySearch(
  enabled: string,
  namespace: SearchNamespaceBinding,
): SearchBinding | undefined {
  if (enabled !== 'true') return undefined;
  return namespace.get(JOURNEY_SEARCH_INSTANCE);
}

/**
 * AI Search is only a candidate retriever. Chunk text is intentionally ignored:
 * every returned hint ID must map back to an audited, in-bundle hint before an
 * answer can be produced.
 */
export async function retrieveAuditedHintIds(
  search: SearchBinding,
  hints: ProgressionHint[],
  request: AssistantRequest,
): Promise<string[]> {
  const reliability = effectiveContextReliability(request.context);
  const filters: VectorizeVectorMetadataFilter = {
    audited: true,
    game: request.context.game,
    generation: request.context.generation,
    ...(reliability.location === 'save_verified' && request.context.locationId
      ? { location_id: request.context.locationId }
      : {}),
  };
  const result = await search.search({
    query: request.question,
    ai_search_options: {
      retrieval: {
        retrieval_type: 'hybrid',
        fusion_method: 'rrf',
        keyword_match_mode: 'or',
        match_threshold: MIN_SEARCH_SCORE,
        max_num_results: MAX_SEARCH_RESULTS,
        context_expansion: 0,
        return_on_failure: true,
        filters,
      },
      query_rewrite: { enabled: false },
      cache: { enabled: false },
    },
  });

  const allowed = new Map(hints.map((hint) => [hint.id, hint]));
  const ids: string[] = [];
  for (const chunk of result.chunks.slice(0, MAX_SEARCH_RESULTS)) {
    const metadata = chunk.item.metadata;
    if (!metadata || chunk.score < MIN_SEARCH_SCORE) continue;
    if (metadata.audited !== true) continue;
    if (metadata.game !== request.context.game) continue;
    if (metadata.generation !== request.context.generation) continue;
    if (typeof metadata.hint_id !== 'string') continue;
    if (
      reliability.location === 'save_verified' &&
      request.context.locationId &&
      metadata.location_id !== request.context.locationId
    ) continue;
    const hint = allowed.get(metadata.hint_id);
    if (!hint || !hint.games.includes(request.context.game)) continue;
    if (!ids.includes(hint.id)) ids.push(hint.id);
  }
  return ids;
}
