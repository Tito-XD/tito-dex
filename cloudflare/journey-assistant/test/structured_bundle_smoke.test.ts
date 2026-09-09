import { readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { answerStructuredResources } from '../src/structured_resources';

// Optional artifact audit: use files extracted from a verified release APK.
// The ordinary suite uses small fixtures; this detects real schema/size drift.
const directory = process.env.TITODEX_BUNDLE_TEST_DIR ?? join(import.meta.dirname, '../.wrangler/structured-audit');
describe.skipIf(!existsSync(join(directory, 'dex_catalog.json')))('published bundle structured query audit', () => {
  const query = (question: string) => answerStructuredResources({
    request: { question, context: { game: 'soulsilver', generation: 4, badgeIds: [], milestoneIds: [], locale: 'zh-Hans', parserRevision: 2 } },
    version: 20, versionGroup: 'heartgold-soulsilver', gameLabel: '魂银',
    read: async (path, limit) => {
      try { const bytes = await readFile(join(directory!, path)); return bytes.length <= limit ? JSON.parse(bytes.toString()) : null; }
      catch { return null; }
    },
  });
  it.each([
    ['火球鼠的进化链是什么', '火球鼠 → 火岩鼠 → 火暴兽'],
    ['哪些宝可梦会喷射火焰而且特性是猛火？', '火球鼠（#155）'],
    ['有哪些陆上蛋群的火属性宝可梦？', '火球鼠'],
    ['火系有哪些威力至少90的招式？', '喷射火焰'],
    ['有哪些树果道具？', '樱子果'],
    ['内敛性格加什么？', '提升特攻，降低攻击'],
    ['灼伤每回合扣多少血？', '1/8'],
    ['火系克制什么属性？', '草'],
    ['29号道路能抓哪些宝可梦？', '波波'],
    ['火球鼠身高体重多少？', '体重：79百克'],
  ])('%s', async (question, expected) => {
    const result = await query(question);
    expect(result?.answer).toContain(expected);
    expect(result?.evidence?.basis).toBe('structured');
    expect(result?.answer?.length).toBeLessThanOrEqual(1200);
  });
});
