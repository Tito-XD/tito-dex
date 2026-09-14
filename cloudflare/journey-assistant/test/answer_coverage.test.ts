import { env } from 'cloudflare:test';
import { beforeEach, describe, expect, it } from 'vitest';
import { answerQuestion } from '../src/assistant';
import { answerFromDexBundle, buildDexBundleSources } from '../src/dex_bundle_retrieval';
import type { AssistantRequest } from '../src/contract';
import { enforceFinalFacts } from '../src/final_answer_facts';
import { generatedAnswerGuardFailure } from '../src/answer_quality_guards';

const request: AssistantRequest = {
  question: '利欧路在哪里抓？',
  context: { game: 'violet', generation: 9, badgeIds: [], milestoneIds: [], locale: 'zh-Hans', parserRevision: 2 },
};

beforeEach(async () => {
  const objects = await env.DEX_CONTENT.list();
  await Promise.all(objects.objects.map((object) => env.DEX_CONTENT.delete(object.key)));
  await env.DEX_CONTENT.put('bundle-manifest.json', JSON.stringify({
    bundleVersion: 20, cdnPrefix: 'v5', complete: true, exactVersionLocations: true,
  }));
  await env.DEX_CONTENT.put('v5/details/447.json', JSON.stringify({
    summary: { id: 447, nameZh: '利欧路' },
    obtainLocationsByVersion: { violet: [{
      areaSlug: 'test-area', areaLabelZh: '测试区域', methods: ['walk'],
      minLevel: 10, maxLevel: 12, conditions: ['weekday-tuesday', 'time-night'],
    }] },
    moveSets: { 'scarlet-violet': { levelUp: [], machine: [{ moveId: 14 }], egg: [], tutor: [] } },
  }));
});

describe('structured answer coverage', () => {
  it('does not let a concept card swallow examples or explanations', async () => {
    expect((await answerQuestion({ ...request, question: '悖谬宝可梦是什么？' })).status).toBe('answered');
    for (const question of ['悖谬宝可梦是什么？请举几个例子。', '悖谬宝可梦是什么，为什么被这样命名？']) {
      const result = await answerQuestion({ ...request, question });
      expect(result.status).toBe('no_match');
      expect(result.followUp).not.toMatch(/挡路|阻塞点|补充游戏版本/);
    }
  });

  it('retains generic weekday and time conditions in both answer and research evidence', async () => {
    const result = await answerFromDexBundle(request, env.DEX_CONTENT);
    expect(result?.response.answer).toContain('周二');
    expect(result?.response.answer).toContain('夜晚');
    expect(result?.response.answer).not.toMatch(/TitoDex v\d/);
    const sources = await buildDexBundleSources(request, env.DEX_CONTENT);
    expect(sources.map((source) => source.text).join('\n')).toContain('weekday-tuesday');
    expect(sources.map((source) => source.text).join('\n')).toContain('time-night');
  });

  it('locks complete narrow facts but allows verified additional subquestions', async () => {
    const narrow = await answerFromDexBundle(request, env.DEX_CONTENT);
    expect(narrow?.coversQuestion).toBe(true);
    const question = '利欧路在哪里抓？需要先获得什么徽章？';
    const partial = await answerFromDexBundle({ ...request, question }, env.DEX_CONTENT);
    expect(partial?.coversQuestion).toBe(false);
    expect(partial?.requiresOnlineVerification).toBe(true);
    const enriched = { ...partial!.response, answer: `${partial!.response.answer}\n已核验的额外条件。` };
    expect(enforceFinalFacts(enriched, narrow!.coversQuestion ? narrow!.response : null).answer).toBe(narrow!.response.answer);
    expect(enforceFinalFacts(enriched, partial!.coversQuestion ? partial!.response : null).answer).toBe(enriched.answer);
    expect(enforceFinalFacts({ ...enriched, answer: '皮卡丘（Raichu）' }, null).status).toBe('no_match');
    const sources = await buildDexBundleSources({ ...request, question }, env.DEX_CONTENT);
    expect(generatedAnswerGuardFailure({ answer: '在橘子学院可以遇到故勒顿。', question,
      game: 'violet', structuredSources: sources })).toBe('selected_game_conflict');
    expect(generatedAnswerGuardFailure({ answer: '剑舞：威力120，用于本系输出。', question: '利欧路怎么配招？',
      knownMoveNames: ['剑舞'], structuredSources: [...sources, {
        id: 'reviewed-guide', url: 'https://www.serebii.net/pokedex-sv/riolu/', text: '',
      }] })).toBe('move_fact_unverified');
  });

  it('uses a unique previous subject to answer a weekday follow-up without assuming a weekday', async () => {
    for (const question of ['那它星期几能抓？', 'What day of the week can I catch it?']) {
      const result = await answerFromDexBundle({ ...request, question, history: [
        { role: 'user', content: 'Where can I catch Riolu in Violet?' },
        { role: 'assistant', content: '错误旧回答：每天。' },
      ] }, env.DEX_CONTENT);
      expect(result?.response.answer).toContain('周二');
      expect(result?.response.answer).not.toContain('每天');
    }
  });

  it('translates Safari conditions and never exposes unknown internal condition slugs', async () => {
    await env.DEX_CONTENT.put('v5/details/447.json', JSON.stringify({
      summary: { id: 447, nameZh: '利欧路' },
      obtainLocationsByVersion: { violet: [{
        areaSlug: 'safari', areaLabelZh: '狩猎测试区', methods: ['surf'],
        conditions: ['johto-safari-blocks-inactive', 'johto-safari-blocks-water-min-14', 'future-unknown-condition'],
      }] },
    }));
    const result = await answerFromDexBundle(request, env.DEX_CONTENT);
    expect(result?.response.answer).toContain('狩猎地带摆设未生效');
    expect(result?.response.answer).toContain('水边摆设≥14');
    expect(result?.response.answer).toContain('特殊出现条件');
    expect(result?.response.answer).not.toMatch(/johto-safari|water-min|future-unknown/);
    const weekday = await answerFromDexBundle({ ...request, question: '利欧路星期几能抓？' }, env.DEX_CONTENT);
    expect(weekday?.response.answer).toContain('没有明确的星期记录');
    expect(weekday?.response.confidence).toBe('low');
    expect(weekday?.coversQuestion).toBe(false);
    expect(weekday?.response.evidence?.complete).toBe(false);
  });

  it('answers weekday-only follow-ups per location without attributing that weekday to other places', async () => {
    await env.DEX_CONTENT.put('v5/details/447.json', JSON.stringify({
      summary: { id: 447, nameZh: '利欧路' },
      obtainLocationsByVersion: { violet: [
        { areaSlug: 'safari', areaLabelZh: '狩猎测试区', methods: ['surf'], conditions: ['johto-safari-blocks-water-min-10'] },
        { areaSlug: 'cave', areaLabelZh: '测试洞窟', methods: ['walk'], conditions: ['weekday-friday'] },
        { areaSlug: 'lake', areaLabelZh: '测试湖泊', methods: ['surf'], conditions: ['weekday-tuesday', 'time-night'] },
      ] },
    }));
    for (const question of ['那需要星期几去？', 'What day of the week can I catch it?']) {
      const result = await answerFromDexBundle({ ...request, question, history: [
        { role: 'user', content: request.question },
      ] }, env.DEX_CONTENT);
      expect(result?.response.answer).toContain('测试洞窟：周五');
      expect(result?.response.answer).toContain('测试湖泊：周二，夜晚');
      expect(result?.response.answer).not.toContain('狩猎测试区');
      expect(result?.response.answer).not.toContain('Lv.');
    }
    const general = await answerFromDexBundle(request, env.DEX_CONTENT);
    expect(general?.response.answer).toContain('狩猎测试区');
  });

  it('does not invent missing machine numbers or treat a learning method as the complete how-to', async () => {
    const result = await answerFromDexBundle({ ...request, question: '利欧路怎么学习剑舞？招式学习器几号，在哪里拿？' }, env.DEX_CONTENT);
    expect(result?.response.answer).toContain('招式学习器');
    expect(result?.response.answer).not.toMatch(/TitoDex v\d|TM\d|HM\d/);
    expect(result?.response.unknowns?.join('')).toContain('编号');
    expect(result?.coversQuestion).toBe(false);
    expect((await answerFromDexBundle({ ...request, question: '利欧路能学剑舞吗？' }, env.DEX_CONTENT))?.coversQuestion).toBe(true);
    const how = await answerFromDexBundle({ ...request, question: '利欧路怎样学会剑舞？' }, env.DEX_CONTENT);
    expect(how?.coversQuestion).toBe(false);
    expect(how?.response.evidence?.complete).toBe(false);
  });
});
