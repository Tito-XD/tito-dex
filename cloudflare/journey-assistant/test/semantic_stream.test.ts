import { describe, expect, it } from 'vitest';

import {
  attachSemanticAnswer,
  composeAnswerBlocks,
  semanticBlockDeltas,
} from '../src/semantic_stream';

describe('semantic answer composer', () => {
  it('turns a compact 1-to-3 paragraph into a summary and bullet block', () => {
    const blocks = composeAnswerBlocks(
      '刚开始玩《宝可梦 紫》可以先留意这些重点： 1. 自由选择三条主线。 2. 先解锁附近传送点。 3. 捕捉不同属性的队员。',
    );

    expect(blocks).toHaveLength(2);
    expect(blocks[0]).toMatchObject({
      kind: 'summary',
      text: '刚开始玩《宝可梦 紫》可以先留意这些重点：',
    });
    expect(blocks[1]).toMatchObject({
      kind: 'bullets',
      items: [
        '自由选择三条主线。',
        '先解锁附近传送点。',
        '捕捉不同属性的队员。',
      ],
    });
    expect(blocks[1].text).toContain('1. 自由选择三条主线。\n');
    expect(semanticBlockDeltas(blocks[1]).join('')).toBe(blocks[1].text);
  });

  it('does not let semantic separators grow the canonical answer contract', () => {
    const suffix = ' 1. 第一项。 2. 第二项。';
    const answer = `${'前'.repeat(1200 - suffix.length)}${suffix}`;
    const attached = attachSemanticAnswer({
      status: 'answered',
      answer,
      confidence: 'high',
      followUp: null,
    });

    expect(attached.answer).toBe(answer);
    expect(attached.answer).toHaveLength(1200);
    expect(attached.answerBlocks?.map((block) => block.text).join('\n\n'))
      .toBe(answer);
  });

  it('does not confuse versions, decimals, or levels with an enumeration', () => {
    const answer = 'TitoDex 0.8.20 记录：Lv.40 学会剑舞，命中倍率为 1.5。';
    const blocks = composeAnswerBlocks(answer);

    expect(blocks).toHaveLength(1);
    expect(blocks[0]).toMatchObject({ kind: 'summary', text: answer });
  });

  it('keeps a Markdown heading out of the body projection', () => {
    const answer = '## 结论\n利欧路可以在南第4区遇到。';
    const blocks = composeAnswerBlocks(answer);

    expect(blocks).toHaveLength(1);
    expect(blocks[0]).toMatchObject({
      kind: 'summary',
      title: '结论',
      text: answer,
    });
    expect(blocks[0]).not.toHaveProperty('items');
  });

  it('classifies a multiline warning before generic multiline content', () => {
    const answer = '提醒：出现率会随天气变化。\n请以当前游戏内天气为准。';
    const blocks = composeAnswerBlocks(answer);

    expect(blocks).toHaveLength(1);
    expect(blocks[0]).toMatchObject({ kind: 'warning', text: answer });
    expect(blocks[0]).not.toHaveProperty('items');
  });

  it('omits a lossy item projection and preserves every canonical item', () => {
    const answer = Array.from(
      { length: 13 },
      (_, index) => `- 第${index + 1}项`,
    ).join('\n');
    const [block] = composeAnswerBlocks(answer);

    expect(block).toMatchObject({ kind: 'bullets', text: answer });
    expect(block).not.toHaveProperty('items');
    expect(semanticBlockDeltas(block).join('')).toBe(answer);
  });

  it('omits a lossy table projection and preserves every canonical cell', () => {
    const answer = [
      '| 地点 | 等级 |',
      '| --- | --- |',
      ...Array.from(
        { length: 12 },
        (_, index) => `| 地点${index + 1} | ${index + 10} |`,
      ),
    ].join('\n');
    const [block] = composeAnswerBlocks(answer);

    expect(block).toMatchObject({ kind: 'table', text: answer });
    expect(block).not.toHaveProperty('rows');
    expect(semanticBlockDeltas(block).join('')).toBe(answer);
  });

  it('bounds every delta and the complete semantic NDJSON envelope', () => {
    const answer = Array.from(
      { length: 16 },
      (_, group) => Array.from(
        { length: 9 },
        (_, line) => `${group + 1}-${line + 1}-资料`,
      ).join('\n'),
    ).join('\n\n');
    const blocks = composeAnswerBlocks(answer);
    const turnId = '00000000-0000-4000-8000-000000000000';
    const events: unknown[] = [
      ...['retrieving', 'resolving', 'verifying', 'writing'].map((stage) => ({
        type: 'progress',
        stage,
        turnId,
      })),
      {
        type: 'answer_plan',
        turnId,
        blocks: blocks.map((block) => ({
          blockId: block.id,
          kind: block.kind,
          ...(block.title ? { title: block.title } : {}),
        })),
      },
    ];

    for (const block of blocks) {
      events.push({
        type: 'block_start',
        turnId,
        blockId: block.id,
        kind: block.kind,
      });
      const deltas = semanticBlockDeltas(block);
      expect(deltas.join('')).toBe(block.text);
      expect(deltas.every((delta) => delta.length <= 256)).toBe(true);
      for (const delta of deltas) {
        events.push({ type: 'block_delta', turnId, blockId: block.id, delta });
      }
      events.push({ type: 'block_end', turnId, blockId: block.id });
    }
    events.push({
      type: 'result',
      turnId,
      result: {
        status: 'answered',
        answer,
        answerBlocks: blocks,
        confidence: 'high',
        followUp: null,
        sources: Array.from({ length: 8 }, (_, index) => ({
          title: '来源'.repeat(80),
          url: `https://example.com/${'a'.repeat(2_020)}${index}`,
          accessedAt: '2026-08-24',
        })),
      },
    });

    const ndjson = `${events.map((event) => JSON.stringify(event)).join('\n')}\n`;
    expect(events.length).toBeLessThan(192);
    expect(new TextEncoder().encode(ndjson).byteLength).toBeLessThan(64 * 1024);
  });

  it('never splits a surrogate pair into an empty or corrupt delta', () => {
    const [block] = composeAnswerBlocks('😀。😀。😀。😀。😀。😀。😀。😀。😀。');
    const deltas = semanticBlockDeltas(block);

    expect(deltas).toHaveLength(8);
    expect(deltas.every((delta) => delta.length > 0 && delta.length <= 256))
      .toBe(true);
    expect(deltas.join('')).toBe(block.text);
  });
});
