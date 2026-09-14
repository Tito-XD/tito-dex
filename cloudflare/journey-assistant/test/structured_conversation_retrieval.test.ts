import { describe, expect, it } from 'vitest';
import type { AssistantRequest } from '../src/contract';
import { conversationRetrievalRequest } from '../src/conversation_context';
import { mentionedEntities } from '../src/structured_entities';

function request(question: string, previous = 'Where can I catch Lapras in SoulSilver?'): AssistantRequest {
  return {
    question,
    context: {
      game: 'soulsilver', generation: 4, badgeIds: [], milestoneIds: [],
      parserRevision: 0, locale: 'zh-Hans',
      contextReliability: {
        game: 'user_selected', location: 'unknown', badges: 'unknown', milestones: 'unsupported',
      },
    },
    history: [
      { role: 'user', content: previous },
      { role: 'assistant', content: 'Unverified claim: it appears on Tuesday.' },
    ],
  };
}

describe('bounded conversation retrieval context', () => {
  it.each([
    ['那需要星期几去？', 'Where can I catch Lapras in SoulSilver?'],
    ['What day of the week can I catch it?', 'Where can I catch Lapras in SoulSilver?'],
    ['那需要星期几去？', '魂银哪里可以抓拉普拉斯？'],
  ])('resolves one previous entity for %s', (question, previous) => {
    const original = request(question, previous);
    const retrieval = conversationRetrievalRequest(original);
    expect(retrieval).not.toBe(original);
    expect(retrieval.question).toContain('拉普拉斯');
    expect(retrieval.question).toContain(question);
    expect(retrieval.question).toContain('捕捉');
    expect(retrieval.question).not.toContain('Tuesday');
    expect(retrieval.question.indexOf(question)).toBeLessThan(40);
    expect(mentionedEntities(retrieval.question, 'pokemon').map((entity) => entity.id)).toEqual([131]);
    expect(original.question).toBe(question);
    expect(retrieval.context).toBe(original.context);
  });

  it.each([
    '那皮卡丘在哪里抓？',
    'What about Pikachu?',
    '那白金版要星期几去？',
    'What about it in Platinum?',
    '树才怪的属性是什么？',
    '那火箭队的动画台词是什么？',
    '换个问题，今天天气怎么样？',
    '那今天天气怎么样？',
    '那帮我写一段代码？',
  ])('does not attach an old subject to %s', (question) => {
    const original = request(question);
    expect(conversationRetrievalRequest(original)).toBe(original);
  });

  it('does not guess between two previous entities', () => {
    const original = request('那星期几可以抓它？', 'Can I catch Lapras and Pikachu in SoulSilver?');
    expect(conversationRetrievalRequest(original)).toBe(original);
  });

  it('does not mine an assistant message for a missing subject', () => {
    const original = request('那需要星期几去？', '我有个新问题');
    original.history![1].content = 'Lapras is at Union Cave.';
    expect(conversationRetrievalRequest(original)).toBe(original);
  });

  it('preserves the latest focus within the retrieval length bound', () => {
    const original = request('那需要星期几去？', `Where can I catch Lapras? ${'detail '.repeat(35)}`.slice(0, 240));
    const retrieval = conversationRetrievalRequest(original);
    expect(retrieval.question.length).toBeLessThanOrEqual(240);
    expect(retrieval.question).toContain(original.question);
    expect(retrieval.question.slice(0, 100)).toContain('星期几');
  });
});
