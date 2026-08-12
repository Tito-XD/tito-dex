import { describe, expect, it, vi } from 'vitest';

import type { AssistantRequest } from '../src/contract';
import { parseProviderJsonResponse } from '../src/index';
import { progressionHints } from '../src/progression_hints';
import {
  getJourneySearch,
  retrieveAuditedHintIds,
  type SearchBinding,
  type SearchNamespaceBinding,
} from '../src/retrieval';

const request: AssistantRequest = {
  question: '北边像植物的东西挡路了',
  context: {
    game: 'soulsilver',
    generation: 4,
    locationId: 'johto-route-36-area',
    badgeIds: ['plain_badge'],
    milestoneIds: [],
    locale: 'zh-Hans',
    parserRevision: 2,
    contextReliability: {
      game: 'save_verified',
      location: 'save_verified',
      badges: 'save_verified',
      milestones: 'unsupported',
    },
  },
};

describe('audited AI Search retrieval', () => {
  it('resolves the fixed namespaced instance only when retrieval is enabled', () => {
    const instance: SearchBinding = {
      search: vi.fn(async () => ({ search_query: '', chunks: [] })),
    };
    const get = vi.fn(() => instance);
    const namespace: SearchNamespaceBinding = { get };

    expect(getJourneySearch('false', namespace)).toBeUndefined();
    expect(get).not.toHaveBeenCalled();

    expect(getJourneySearch('true', namespace)).toBe(instance);
    expect(get).toHaveBeenCalledOnce();
    expect(get).toHaveBeenCalledWith('titodex-journey-search');
  });

  it('uses save-aware metadata filters and accepts only local audited hint IDs', async () => {
    const search = vi.fn(async () => ({
      search_query: request.question,
      chunks: [
        chunk('trusted', 0.91, {
          audited: true,
          game: 'soulsilver',
          generation: 4,
          location_id: 'johto-route-36-area',
          hint_id: 'hgss-route36-sudowoodo',
        }, 'untrusted chunk text is never used as an answer'),
        chunk('invented', 0.99, {
          audited: true,
          game: 'soulsilver',
          generation: 4,
          location_id: 'johto-route-36-area',
          hint_id: 'invented-hint',
        }),
        chunk('wrong-game', 0.98, {
          audited: true,
          game: 'heartgold',
          generation: 4,
          location_id: 'johto-route-36-area',
          hint_id: 'hgss-route36-sudowoodo',
        }),
      ],
    }));
    const ids = await retrieveAuditedHintIds(
      { search } as SearchBinding,
      progressionHints,
      request,
    );
    expect(ids).toEqual(['hgss-route36-sudowoodo']);
    expect(search).toHaveBeenCalledWith(expect.objectContaining({
      ai_search_options: expect.objectContaining({
        retrieval: expect.objectContaining({
          retrieval_type: 'hybrid',
          filters: {
            audited: true,
            game: 'soulsilver',
            generation: 4,
            location_id: 'johto-route-36-area',
          },
        }),
        cache: { enabled: false },
      }),
    }));
  });

  it('does not add a location filter when location is unknown', async () => {
    let captured: AiSearchSearchRequest | undefined;
    const search: SearchBinding['search'] = vi.fn(async (params) => {
      captured = params;
      return { search_query: request.question, chunks: [] };
    });
    await retrieveAuditedHintIds(
      { search } as SearchBinding,
      progressionHints,
      {
        ...request,
        context: {
          ...request.context,
          locationId: undefined,
          contextReliability: {
            game: 'save_verified',
            location: 'unknown',
            badges: 'save_verified',
            milestones: 'unsupported',
          },
        },
      },
    );
    expect(captured?.ai_search_options?.retrieval?.filters).not.toHaveProperty('location_id');
  });
});

describe('OpenAI-compatible provider response limits', () => {
  it('parses only strict JSON content from a bounded successful response', async () => {
    const response = Response.json({
      choices: [{ message: { content: '{"hintId":"hgss-route36-sudowoodo"}' } }],
    });
    await expect(parseProviderJsonResponse(response)).resolves.toEqual({
      hintId: 'hgss-route36-sudowoodo',
    });
  });

  it('rejects markdown-wrapped and oversized provider output', async () => {
    await expect(parseProviderJsonResponse(Response.json({
      choices: [{ message: { content: '```json\n{"hintId":"x"}\n```' } }],
    }))).rejects.toThrow();
    await expect(parseProviderJsonResponse(new Response('x', {
      headers: { 'content-length': '20000' },
    }))).rejects.toThrow('provider_response_too_large');
  });
});

function chunk(
  id: string,
  score: number,
  metadata: Record<string, unknown>,
  text = 'ignored',
): AiSearchSearchResponse['chunks'][number] {
  return {
    id,
    type: 'text',
    score,
    text,
    item: { key: `hints/${id}.json`, metadata },
  };
}
