import { describe, expect, it } from 'vitest';
import { answerStructuredResources } from '../src/structured_resources';
import { enforceFinalFacts } from '../src/final_answer_facts';
import { entityNameMismatch, evolutionClaimMismatch, mentionedEntities } from '../src/structured_entities';
import type { AssistantRequest, AssistantResponse } from '../src/contract';

const context: AssistantRequest['context'] = {
  game: 'soulsilver', generation: 4, badgeIds: [], milestoneIds: [], locale: 'zh-Hans', parserRevision: 2,
};
function run(question: string, resources: Record<string, unknown>, game = context) {
  return answerStructuredResources({
    request: { question, context: game }, version: 20, versionGroup: 'heartgold-soulsilver', gameLabel: '魂银',
    read: async (path) => resources[path] ?? null,
  });
}
const cyndaquil = {
  summary: { id: 155 },
  evolutionChain: { id: 155, nameZh: 'wrong', children: [{ id: 156, children: [
    { id: 157, nameZh: '暴鲤龙', children: [], triggers: [{ minLevel: 36 }] },
  ], triggers: [{ minLevel: 14 }, { minLevel: 17 }] }] },
};
describe('structured resources and final fact ownership', () => {
  it('renders the complete chain using canonical IDs, even if source display labels are wrong', async () => {
    const result = await run('火球鼠的进化链是什么', { 'details/155.json': cyndaquil });
    expect(result?.answer).toContain('火球鼠 → 火岩鼠 → 火暴兽');
    expect(result?.answer).not.toContain('暴鲤龙');
    expect(result?.evidence?.entityIds).toEqual(['pokemon:155', 'pokemon:156', 'pokemon:157']);
    expect(result?.answer).not.toContain('Lv.14');
    expect(result?.evidence?.scope).toBe('general');
  });
  it('does not treat combined version conditions as an exact-game answer', async () => {
    const result = await run('火球鼠几级进化？', { 'details/155.json': cyndaquil });
    expect(result?.answer).toContain('条件尚未按当前游戏确认');
    expect(result?.evidence?.complete).toBe(false);
  });
  it('does not substitute the default evolution chain for an unknown regional form', async () => {
    expect((await run('洗翠火暴兽进化链', { 'details/157.json': { ...cyndaquil, summary: { id: 157 } } }))?.confidence).toBe('low');
  });
  it('rejects broken chain IDs and preserves missing versus unevolvable', async () => {
    const bad = { summary: { id: 155 }, evolutionChain: { id: 155, children: [{ id: 999999, children: [] }] } };
    expect((await run('火球鼠进化链', { 'details/155.json': bad }))?.confidence).toBe('low');
    expect((await run('火球鼠进化链', { 'details/155.json': { summary: { id: 155 } } }))?.answer).toContain('不等于');
  });
  it('intersects move and ability indexes and verifies each candidate learnset in the selected game', async () => {
    const catalog = { summaries: [], moveLearners: { 53: [4, 155, 157] }, abilityPokemonIds: { 66: [155, 156, 157] } };
    const group = { levelUp: [{ moveStableId: 'move:53', level: 37 }], machine: [], egg: [], tutor: [] };
    const result = await run('哪些宝可梦会喷射火焰而且特性是猛火？', {
      'dex_catalog.json': catalog,
      'gameplay/species/155.json': { speciesId: 155, learn: { byVersionGroup: { 'heartgold-soulsilver': group } } },
      'gameplay/species/157.json': { speciesId: 157, learn: { byVersionGroup: { 'scarlet-violet': group } } },
    });
    expect(result?.answer).toContain('火球鼠（#155）');
    expect(result?.answer).not.toContain('小火龙（#4）');
    expect(result?.answer).not.toContain('火暴兽（#157）');
    expect(result?.answer).toContain('1 只缺少版本资料');
    expect(result?.evidence?.scope).toBe('general');
    expect(result?.evidence?.complete).toBe(false);
  });
  it('never reports a missing reverse index as an empty result', async () => {
    const result = await run('哪些宝可梦有猛火特性？', { 'dex_catalog.json': { summaries: [] } });
    expect(result?.answer).toContain('索引缺失');
    expect(result?.confidence).toBe('low');
  });
  it('labels pagination and does not silently turn OR into AND', async () => {
    const catalog = { summaries: [], abilityPokemonIds: { 66: Array.from({ length: 30 }, (_, i) => i + 1) } };
    const result = await run('哪些宝可梦有猛火特性？', { 'dex_catalog.json': catalog });
    expect(result?.evidence).toMatchObject({ total: 30, complete: false });
    expect(result?.answer).toContain('不是完整名单');
    expect((await run('哪些宝可梦有猛火特性或火属性？', { 'dex_catalog.json': catalog }))?.answer).toContain('拆开查询');
  });
  it('reads other existing resources: nature, status rules, items, types, locations and detail fields', async () => {
    expect((await run('内敛性格加什么？', { 'natures.json': [{ nameZh: '内敛', increasedStat: 'specialAttack', decreasedStat: 'attack' }] }))?.answer).toContain('提升特攻，降低攻击');
    expect((await run('灼伤扣多少血？', { 'status_conditions.json': [{ nameZh: '灼伤', generationRules: [{ fromGeneration: 2, toGeneration: 6, residualDamageDenominator: 8 }, { fromGeneration: 7, residualDamageDenominator: 16 }] }] }))?.answer).toContain('1/8');
    expect((await run('有哪些树果道具？', { 'items.json': { 126: { id: 126, slug: 'cheri-berry', categoryZh: '树果' } } }))?.evidence?.entityIds).toContain('item:126');
    expect((await run('火系克制什么属性？', { 'types.json': { fire: { nameZh: '火', doubleDamageTo: ['grass'] } } }))?.answer).toContain('攻击效果绝佳：草');
    expect((await run('29号道路能抓什么？', { 'location_index.json': { byVersion: { soulsilver: { route29: { labelZh: '29号道路', entries: [{ speciesId: 16 }] } } } } }))?.answer).toContain('波波');
    expect((await run('火球鼠身高体重多少？', { 'details/155.json': { summary: { id: 155 }, heightDm: 5, weightHg: 79 } }))?.answer).toContain('体重：79百克');
  });
  it('keeps reference-list and reference-detail questions distinct from Pokemon filtering', async () => {
    expect(await run('恶臭特性有什么效果？', {})).toBeNull();
    const result = await run('火系有哪些威力至少90的招式？', {
      'moves.json': { 53: { id: 53, type: 'fire', power: 90 }, 52: { id: 52, type: 'fire', power: 40 }, 57: { id: 57, type: 'water', power: 90 } },
    });
    expect(result?.answer).toContain('喷射火焰');
    expect(result?.evidence?.entityIds).toEqual(['move:53']);
    expect((await run('哪些树果能治疗中毒？', {}))?.answer).toContain('效果条件');
  });
  it('guards all entity kinds and does not flag correct translated names', () => {
    expect(entityNameMismatch('火岩鼠再进化成暴鲤龙（Typhlosion）')).toBe(true);
    expect(entityNameMismatch('火暴兽（Typhlosion）')).toBe(false);
    expect(entityNameMismatch('威吓（Blaze）')).toBe(true);
    expect(mentionedEntities('wildfire with flames', 'move')).not.toContainEqual(expect.objectContaining({ en: 'Fly' }));
  });
  it('discards false final rewrites even after a model verifier has accepted them', async () => {
    const structured = await run('火球鼠进化链', { 'details/155.json': cyndaquil });
    const falseCandidate: AssistantResponse = {
      status: 'answered', answer: '火岩鼠进化为暴鲤龙（Typhlosion）', confidence: 'high', followUp: null,
      sources: [{ title: 'Model accepted source', url: 'https://example.com', accessedAt: '2026-09-09' }],
      answerBlocks: [{ id: 'bad', kind: 'paragraph', text: '暴鲤龙' }],
    };
    const result = enforceFinalFacts(falseCandidate, structured);
    expect(result.answer).toBe(structured?.answer);
    expect(result.sources).toBeUndefined();
    expect(result.answerBlocks).toBeUndefined();
    expect(enforceFinalFacts(falseCandidate, null)).toMatchObject({ status: 'no_match', answer: null });
  });
  it('also checks evolution facts inside free-form advice after the final model pass', () => {
    const sources = [{ id: 'dex-bundle-v20', text: JSON.stringify({ species: { evolutionChain: {
      truncated: false, edges: [
        { fromStableId: 'pokemon:155', toStableId: 'pokemon:156' },
        { fromStableId: 'pokemon:156', toStableId: 'pokemon:157' },
      ],
    } } }) }];
    expect(evolutionClaimMismatch('推荐培养火球鼠，因为火岩鼠会进化成暴鲤龙。', sources)).toBe(true);
    expect(evolutionClaimMismatch('火球鼠最终进化成火暴兽。', sources)).toBe(false);
    expect(evolutionClaimMismatch('火球鼠不会进化成暴鲤龙。', sources)).toBe(false);
    const result = enforceFinalFacts({ status: 'answered', answer: '火岩鼠进化为暴鲤龙。', confidence: 'high', followUp: null }, null, sources);
    expect(result.status).toBe('no_match');
  });
});
