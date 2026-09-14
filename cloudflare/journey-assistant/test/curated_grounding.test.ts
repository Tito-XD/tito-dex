import { describe, expect, it } from 'vitest';
import { verifyGroundedClaims } from '../src/curated_grounding';
import type { AssistantRequest } from '../src/contract';

const request = { question: '规则有什么区别？', context: { game: 'general', generation: 0 } } as AssistantRequest;
const sources = [{ id: 'rules', title: 'Official rules', url: 'https://www.pokemon.com/rules.pdf',
  text: 'Category A has no same-name limit. Category B allows at most four copies of the same name.' }];
const supported = { index: 0, verdict: 'supported', sourceId: 'rules', quote: 'Category A has no same-name limit.' };

describe('claim grounding', () => {
  it('budgets complete quote-bearing verification and retains all sentences of longer drafts', async () => {
    const draft = Array.from({ length: 13 }, () => 'A类无同名限制。').join('\n');
    const result = await verifyGroundedClaims(request, draft, sources, async (_phase, messages, _schema, maxTokens) => {
      const input = JSON.parse(messages[1].content) as { claims: Array<{ index: number; text: string }> };
      expect(input.claims.length).toBeLessThanOrEqual(12);
      expect(input.claims.map((claim) => claim.text).join('\n').replaceAll('\n', '')).toBe(draft.replaceAll('\n', ''));
      expect(maxTokens).toBeGreaterThanOrEqual(400 + input.claims.length * 300);
      expect(maxTokens).toBeLessThanOrEqual(4096);
      return { claims: input.claims.map((claim) => ({ ...supported, index: claim.index })) };
    });
    expect(result?.answer).toBe(draft);
  });
  it('drops one incorrectly copied excerpt without losing independently evidenced claims', async () => {
    const result = await verifyGroundedClaims(request, 'A类无同名限制。B类会自动生效。', sources, async () => ({ claims: [
      supported, { ...supported, index: 1, quote: 'Invented support not present in retrieved evidence.' },
    ] }));
    expect(result?.answer).toBe('A类无同名限制。');
    expect(result?.partial).toBe(true);
  });
  it('keeps a qualified default rule alongside its effect exception', async () => {
    const source = [{ ...sources[0], text: 'Once during your turn, you may perform action A. However, card effects may allow additional actions.' }];
    const draft = '通常每回合只能执行一次A，但卡牌效果可允许额外操作。';
    expect((await verifyGroundedClaims(request, draft, source, async () => ({ claims: [
      { index: 0, verdict: 'supported', sourceId: 'rules', quote: source[0].text },
    ] })))?.answer).toBe(draft);
  });
  it('does not promote a default rule into an unconditional limit by omitting its adjacent exception', async () => {
    const ruleSource = [{ ...sources[0], text: 'Once during your turn, you may perform action A. However, card effects may allow additional actions. Category B allows at most four copies of the same name.' }];
    const result = await verifyGroundedClaims(request, '每回合只能执行一次A。B类同名最多四张。', ruleSource, async () => ({ claims: [
      { index: 0, verdict: 'supported', sourceId: 'rules', quote: 'Once during your turn, you may perform action A.' },
      { index: 1, verdict: 'supported', sourceId: 'rules', quote: 'Category B allows at most four copies of the same name.' },
    ] }));
    expect(result?.answer).toBe('B类同名最多四张。');
    expect(result?.partial).toBe(true);
  });
  it('preserves paragraph and list separators after unsupported claims are removed', async () => {
    const draft = 'A类无同名限制。\n\n- B类同名最多四张。\n- 无依据的说明。\n- A类无同名限制。';
    const result = await verifyGroundedClaims(request, draft, sources, async () => ({ claims: [
      supported,
      { index: 1, verdict: 'supported', sourceId: 'rules', quote: 'Category B allows at most four copies of the same name.' },
      { index: 2, verdict: 'unsupported', sourceId: '', quote: '' },
      { ...supported, index: 3 },
    ] }));
    expect(result?.answer).toBe('A类无同名限制。\n\n- B类同名最多四张。\n- A类无同名限制。');
    expect(result?.partial).toBe(true);
  });

  it('keeps exact supported draft claims and removes unsupported claims', async () => {
    expect(await verifyGroundedClaims(request, 'A类无同名限制。B类会自动生效。', sources, async (phase) => {
      expect(phase).toBe('curated-web-verify');
      return { claims: [supported, { index: 1, verdict: 'unsupported', sourceId: '', quote: '' }] };
    })).toEqual({ answer: 'A类无同名限制。', partial: true, sourceIds: ['rules'] });
  });

  it('rejects an explicit contradiction even alongside a supported claim', async () => {
    expect(await verifyGroundedClaims(request, 'A类无同名限制。B类也无上限。', sources, async () => ({ claims: [
      supported, { index: 1, verdict: 'contradicted', sourceId: 'rules', quote: 'Category B allows at most four copies of the same name.' },
    ] }))).toEqual({ answer: null, contradicted: true });
  });

  it.each([
    { claims: [{ ...supported, quote: 'Invented evidence which does not occur in the source.' }] },
    { claims: [{ ...supported, sourceId: 'unretrieved' }] },
    { claims: [{ ...supported, quote: 'Category A' }] },
    { claims: [] },
    { supported: false, answer: '' },
    { claims: [{ ...supported, index: 2 }] },
  ])('does not accept malformed, omitted or fabricated support: %j', async (value) => {
    expect(await verifyGroundedClaims(request, 'A类无同名限制。', sources, async () => value)).toBeNull();
  });

  it('never turns an entirely unsupported draft into a relaxed answer', async () => {
    expect(await verifyGroundedClaims(request, 'A类无同名限制。', sources, async () => ({ claims: [
      { index: 0, verdict: 'unsupported', sourceId: '', quote: '' },
    ] }))).toEqual({ answer: null, partial: true, sourceIds: [] });
  });
});
