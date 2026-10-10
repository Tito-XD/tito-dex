import { describe, expect, it, vi } from 'vitest';
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

  it('splits basic multi-edition examples into independently supported clauses', async () => {
    const draft = '《钻石》：钢铁岛赠送蛋；《朱／紫》：南第4区。';
    const source = [{ id: 'locations', title: 'Location examples', text: '《钻石》：钢铁岛赠送利欧路的蛋，必须按该游戏的流程领取。' }];
    const result = await verifyGroundedClaims(request, draft, source, async (_phase, messages) => {
      const input = JSON.parse(messages[1].content);
      expect(input.claims).toHaveLength(2);
      return { claims: [ { index: 0, verdict: 'supported', sourceId: 'locations', quote: source[0].text },
        { index: 1, verdict: 'unsupported', sourceId: '', quote: '' } ] };
    }, { separateClauses: true });
    expect(result?.answer).toBe('《钻石》：钢铁岛赠送蛋；');
    expect(result?.sourceIds).toEqual(['locations']);
  });

  it('makes strict quote requirements explicit and logs rejection counts without user text', async () => {
    const log = vi.spyOn(console, 'log').mockImplementation(() => {});
    try {
      const secretQuestion = { ...request, question: 'private-question-secret' };
      const result = await verifyGroundedClaims(secretQuestion, 'private-draft-secret。', sources, async (_phase, messages, schema) => {
        expect(messages[0].content).toContain('逐字复制12到240字的连续原文');
        expect(JSON.stringify(schema)).toContain('rules');
        return { claims: [{ ...supported, quote: 'Category A' }] };
      });
      expect(result).toBeNull();
      expect(log).toHaveBeenCalledWith(expect.stringContaining('"shortQuote":1'));
      const output = log.mock.calls.map(([value]) => String(value)).join('');
      expect(output).not.toContain('private-question-secret');
      expect(output).not.toContain('private-draft-secret');
      expect(output).not.toContain(sources[0].text);
    } finally { log.mockRestore(); }
  });

  it('uses fixed claim keys so the model cannot repeat or misnumber indices', async () => {
    const row = { verdict: 'supported', sourceIndex: 0, quote: sources[0].text };
    const result = await verifyGroundedClaims(request, 'A类无同名限制。B类尚未确认。', sources, async (_phase, messages, schema) => {
      expect(messages[0].content).toContain('固定字符串序号键的对象');
      const definition = (schema.properties as Record<string, any>).claims;
      expect(definition).toMatchObject({ type: 'object', required: ['0', '1'], additionalProperties: false });
      expect(definition.properties['0'].required).toEqual(['verdict', 'sourceIndex', 'quote']);
      expect(definition.properties['0'].properties.sourceIndex).toMatchObject({ type: 'integer', minimum: 0, maximum: 0 });
      return { claims: { '0': row, '1': { verdict: 'unsupported', sourceIndex: 0, quote: '' } } };
    }, { keyedClaims: true });
    expect(result?.answer).toBe('A类无同名限制。');
    expect(result?.partial).toBe(true);
  });
  it.each([
    { claims: { '0': { verdict: 'supported', sourceId: 'rules', quote: sources[0].text } } },
    { claims: { '0': supported, '1': supported } },
    { claims: { '0': {}, '2': {} } },
    { claims: [supported, { ...supported, index: 0 }] },
  ])('retains strict rejection of missing, extra, embedded or duplicate claim indices: %j', async (value) => {
    expect(await verifyGroundedClaims(request, 'A类无同名限制。B类也无上限。', sources,
      async () => value, { keyedClaims: true })).toBeNull();
  });

  it('maps a numeric source index to its real ID and still requires its exact quote', async () => {
    const extra = [...sources, { id: 'second-retrieved-id', title: 'Second', text: 'The second actual reference has direct evidence for category A.' }];
    const result = await verifyGroundedClaims(request, 'A类无同名限制。', extra, async (_phase, messages) => {
      const input = JSON.parse(messages[1].content);
      expect(input.sources[1]).toMatchObject({ sourceIndex: 1, id: 'second-retrieved-id' });
      return { claims: { '0': { verdict: 'supported', sourceIndex: 1, quote: extra[1].text } } };
    }, { keyedClaims: true });
    expect(result?.sourceIds).toEqual(['second-retrieved-id']);
    expect(await verifyGroundedClaims(request, 'A类无同名限制。', extra, async () => ({ claims: {
      '0': { verdict: 'supported', sourceIndex: 0, quote: extra[1].text },
    } }), { keyedClaims: true })).toBeNull();
  });

  it('never turns an entirely unsupported draft into a relaxed answer', async () => {
    expect(await verifyGroundedClaims(request, 'A类无同名限制。', sources, async () => ({ claims: [
      { index: 0, verdict: 'unsupported', sourceId: '', quote: '' },
    ] }))).toEqual({ answer: null, partial: true, sourceIds: [] });
  });
});
