import { describe, expect, it, vi } from 'vitest';

import { answerQuestion } from '../src/assistant';
import { parseAssistantRequest, type AssistantRequest } from '../src/contract';
import { buildLogRecord } from '../src/logging';

const request: AssistantRequest = {
  question: '36号道路这棵树怎么过？',
  context: {
    game: 'heartgold',
    generation: 4,
    locationId: 'johto-route-36-area',
    badgeIds: ['zephyr_badge', 'hive_badge', 'plain_badge'],
    milestoneIds: [],
    locale: 'zh-Hans',
    parserRevision: 2,
  },
};

describe('deterministic and model-guarded answers', () => {
  it('answers the Sudowoodo golden case from audited facts', async () => {
    const result = await answerQuestion(request);
    expect(result.status).toBe('answered');
    expect(result.answer).toContain('杰尼龟喷壶');
    expect(result.answer).toContain('标准徽章');
    expect(result.unknowns).toContain('当前解析器无法确认是否已完成／取得杰尼龟喷壶');
    expect(result.matchedHintIds).toEqual(['hgss-route36-sudowoodo']);
  });

  it('uses zero AI calls when a local rule is already unique', async () => {
    const compose = vi.fn(async () => ({ sectionOrder: ['section-0'] }));
    const resolve = vi.fn(async () => ({ hintId: 'hgss-radio-tower-shutter' }));
    const result = await answerQuestion(request, compose, resolve);
    expect(result.matchedHintIds).toEqual(['hgss-route36-sudowoodo']);
    expect(result.onlineComposed).toBe(false);
    expect(compose).not.toHaveBeenCalled();
    expect(resolve).not.toHaveBeenCalled();
  });

  it('does not invoke answer composition when neither rules nor AI select an allowed hint', async () => {
    const compose = vi.fn(async () => ({ sectionOrder: ['section-0'] }));
    const unknownRequest = {
      ...request,
      question: '我现在应该做什么完全不知道',
      context: { ...request.context, locationId: undefined },
    };
    const result = await answerQuestion(
      unknownRequest,
      compose,
      async () => ({ hintId: 'invented-hint' }),
    );
    expect(result.status).toBe('no_match');
    expect(compose).not.toHaveBeenCalled();
  });

  it('lets AI classify only to an allowed hint before composing audited facts', async () => {
    const result = await answerQuestion(
      {
        ...request,
        question: '北边那个看起来像植物的东西让我过不去',
        context: { ...request.context, locationId: undefined },
      },
      async (_hint, _request, fallback) => ({
        sectionOrder: (fallback.answer ?? '')
          .split('\n\n')
          .map((_, index) => `section-${index}`),
      }),
      async () => ({ hintId: 'hgss-route36-sudowoodo' }),
    );
    expect(result.status).toBe('answered');
    expect(result.onlineComposed).toBe(true);
    expect(result.matchedHintIds).toEqual(['hgss-route36-sudowoodo']);
  });

  it('rejects model ordering that drops the audited unknown section', async () => {
    const result = await answerQuestion(
      {
        ...request,
        question: '北边那个看起来像植物的东西让我过不去',
        context: { ...request.context, locationId: undefined },
      },
      async () => ({ sectionOrder: ['section-0'] }),
      async () => ({ hintId: 'hgss-route36-sudowoodo' }),
    );
    expect(result.status).toBe('answered');
    expect(result.onlineComposed).toBe(false);
    expect(result.errorCode).toBe('invalid_model_json');
    expect(result.answer).toContain('杰尼龟喷壶');
    expect(result.answer).toContain('当前解析器无法确认');
  });

  it('falls back safely when the model times out', async () => {
    const result = await answerQuestion(
      {
        ...request,
        question: '北边那个看起来像植物的东西让我过不去',
        context: { ...request.context, locationId: undefined },
      },
      async () => {
        throw new DOMException('timeout', 'AbortError');
      },
      async () => ({ hintId: 'hgss-route36-sudowoodo' }),
    );
    expect(result.status).toBe('answered');
    expect(result.errorCode).toBe('upstream_timeout');
    expect(result.onlineComposed).toBe(false);
  });

  it('falls back to a deterministic no-match when retrieval or models fail', async () => {
    const compose = vi.fn(async () => ({ sectionOrder: ['section-0'] }));
    const result = await answerQuestion(
      {
        ...request,
        question: '这里完全没有可识别的信息',
        context: { ...request.context, locationId: undefined },
      },
      compose,
      async () => {
        throw new Error('search_or_model_unavailable');
      },
    );
    expect(result).toMatchObject({ status: 'no_match', answer: null });
    expect(compose).not.toHaveBeenCalled();
  });

  it('never turns a badge count into a specific badge claim', async () => {
    const result = await answerQuestion({
      ...request,
      context: {
        ...request.context,
        badgeIds: [],
        badgeCount: 3,
        contextReliability: {
          game: 'save_verified',
          location: 'save_verified',
          badges: 'count_only',
          milestones: 'unsupported',
        },
      },
    });
    expect(result.status).toBe('answered');
    expect(result.answer).not.toContain('存档可以确认已取得标准徽章');
    expect(result.answer).not.toContain('存档尚未显示标准徽章');
    expect(result.verifiedFacts).not.toContain('存档已确认标准徽章');
    expect(result.contextUsed).toMatchObject({ badgeCount: 3 });
    expect(result.contextUsed).not.toHaveProperty('badgeIds');
  });

  it('keeps schema-v1 callers compatible and rejects contradictory reliability', () => {
    expect(parseAssistantRequest(JSON.parse(JSON.stringify(request)))).not.toBeNull();
    expect(parseAssistantRequest({
      ...request,
      context: {
        ...request.context,
        contextReliability: {
          game: 'save_verified',
          location: 'unknown',
          badges: 'save_verified',
          milestones: 'unsupported',
        },
      },
    })).toBeNull();
  });

  it('logs only coarse structured metadata', async () => {
    const result = await answerQuestion({ ...request, question: 'private-question-marker' });
    const serialized = JSON.stringify(buildLogRecord(result, request));
    expect(serialized).not.toContain('private-question-marker');
    expect(serialized).not.toContain('johto-route-36-area');
    expect(serialized).not.toContain('badgeIds');
    expect(serialized).toContain('badgeCount');
  });

  it('logs the coarse parsed badge count when exact badge IDs are unavailable', async () => {
    const countOnlyRequest: AssistantRequest = {
      ...request,
      context: {
        ...request.context,
        badgeIds: [],
        badgeCount: 7,
        contextReliability: {
          game: 'save_verified',
          location: 'save_verified',
          badges: 'count_only',
          milestones: 'unsupported',
        },
      },
    };
    const result = await answerQuestion(countOnlyRequest);
    expect(buildLogRecord(result, countOnlyRequest)).toMatchObject({
      badgeCount: 7,
    });
  });
});
