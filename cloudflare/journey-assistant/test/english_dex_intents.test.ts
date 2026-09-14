import { env } from 'cloudflare:test';
import { beforeEach, describe, expect, it } from 'vitest';
import { answerFromDexBundle, buildDexBundleSources } from '../src/dex_bundle_retrieval';
import type { AssistantRequest } from '../src/contract';

const request: AssistantRequest = {
  question: '',
  context: { game: 'soulsilver', generation: 4, badgeIds: [], milestoneIds: [], locale: 'zh-Hans', parserRevision: 2 },
};

beforeEach(async () => {
  const objects = await env.DEX_CONTENT.list();
  await Promise.all(objects.objects.map((object) => env.DEX_CONTENT.delete(object.key)));
  await env.DEX_CONTENT.put('bundle-manifest.json', JSON.stringify({
    bundleVersion: 20, cdnPrefix: 'v5', complete: true, exactVersionLocations: true,
  }));
  await env.DEX_CONTENT.put('v5/details/131.json', JSON.stringify({
    summary: { id: 131, nameZh: '拉普拉斯' },
    obtainLocationsByVersion: { soulsilver: [{
      areaSlug: 'union-cave-b2f', areaLabelZh: '互连洞地下二层', methods: ['gift'],
      minLevel: 20, maxLevel: 20, conditions: ['weekday-friday'],
    }] },
    moveSets: { 'heartgold-soulsilver': {
      levelUp: [{ moveId: 58, level: 32 }], machine: [{ moveId: 57 }], egg: [], tutor: [],
    } },
  }));
});

describe('English Dex encounter and learnset intents', () => {
  it('does not turn aggregated alternate conditions into simultaneous requirements', async () => {
    await env.DEX_CONTENT.put('v5/details/131.json', JSON.stringify({
      summary: { id: 131, nameZh: '拉普拉斯' }, obtainLocationsByVersion: { soulsilver: [{
        areaSlug: 'safari-zone', areaLabelZh: '狩猎地带', methods: ['surf'], minLevel: 15, maxLevel: 47,
        conditions: ['time-day', 'time-night', 'johto-safari-blocks-inactive', 'johto-safari-blocks-water-min-10', 'johto-safari-blocks-water-min-18'],
      }] },
    }));
    const result = await answerFromDexBundle({ ...request, question: 'Where can I catch Lapras?' }, env.DEX_CONTENT);
    expect(result?.response.answer).toContain('不能把下列条件当作同时要求');
    expect(result?.response.unknowns?.join()).toContain('遭遇条件对应关系');
    expect(result?.coversQuestion).toBe(false);
    expect(result?.response.evidence?.complete).toBe(false);
  });
  for (const question of [
    'Where can I catch Lapras in SoulSilver?',
    'Where is Lapras found in SoulSilver?',
    'How do I encounter Lapras in SoulSilver?',
  ]) {
    it(`locks the structured encounter facts for: ${question}`, async () => {
      const result = await answerFromDexBundle({ ...request, question }, env.DEX_CONTENT);
      expect(result?.coversQuestion).toBe(true);
      expect(result?.response.answer).toContain('周五');
      expect(result?.response.answer).toContain('互连洞地下二层');
      expect(result?.response.evidence?.basis).toBe('structured');
      expect(result?.response.answer).not.toMatch(/钢铁|才能进入/);
    });
  }

  it('resolves an English level-up query through the selected-game learnset', async () => {
    const result = await answerFromDexBundle({ ...request,
      question: 'At what level does Lapras learn Ice Beam in SoulSilver?',
    }, env.DEX_CONTENT);
    expect(result?.coversQuestion).toBe(true);
    expect(result?.response.answer).toContain('Lv.32');
    expect(result?.response.answer).toContain('冰冻光束');
  });

  it('prioritizes learning over a location phrase and keeps missing machine details incomplete', async () => {
    const result = await answerFromDexBundle({ ...request,
      question: 'How can Lapras learn Surf in SoulSilver?',
    }, env.DEX_CONTENT);
    expect(result?.response.answer).toContain('招式学习器');
    expect(result?.response.answer).not.toContain('互连洞');
    expect(result?.coversQuestion).toBe(false);
  });

  for (const question of ['Where can I catch Lapras?', 'How does Lapras learn Surf?']) {
    it(`never projects a selected-game answer into general scope: ${question}`, async () => {
      const general = { ...request, question,
        context: { ...request.context, game: 'general' as const, generation: 0 as const },
      };
      expect(await answerFromDexBundle(general, env.DEX_CONTENT)).toBeNull();
      const evidence = (await buildDexBundleSources(general, env.DEX_CONTENT))
        .map((source) => source.text).join('\n');
      expect(evidence).not.toMatch(/weekday-friday|互连洞|heartgold-soulsilver/);
    });
  }
});
