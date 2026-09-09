import { MAX_ANSWER_LENGTH, type AssistantRequest, type AssistantResponse } from './contract';
import { entityName, mentionedEntities, type EntityKind } from './structured_entities';
import axes from '../../../data/l10n/zh/dex_axes.json';

type Row = Record<string, unknown>;
export type ResourceReader = (path: string, limit: number) => Promise<unknown>;
type Context = {
  request: AssistantRequest; read: ResourceReader; version: number;
  versionGroup: string; gameLabel: string;
};
const small = 256 * 1024;
const catalogLimit = 8 * 1024 * 1024;
const PAGE_SIZE = 24;
const typeNames: Record<string, string> = {
  normal: '一般', fire: '火', water: '水', electric: '电', grass: '草', ice: '冰',
  fighting: '格斗', poison: '毒', ground: '地面', flying: '飞行', psychic: '超能力',
  bug: '虫', rock: '岩石', ghost: '幽灵', dragon: '龙', dark: '恶', steel: '钢', fairy: '妖精',
};
const stats: Record<string, string> = {
  hp: 'HP', attack: '攻击', defense: '防御', specialAttack: '特攻', specialDefense: '特防', speed: '速度',
  'special-attack': '特攻', 'special-defense': '特防',
};
export const object = (value: unknown): value is Row =>
  typeof value === 'object' && value !== null && !Array.isArray(value);
const rows = (value: unknown): Row[] => Array.isArray(value) ? value.filter(object) : [];
const string = (value: unknown): string => typeof value === 'string' ? value.slice(0, 500) : '';
const ids = (value: unknown): number[] | null => Array.isArray(value) &&
  value.length <= 2000 && value.every((id) => Number.isInteger(id) && id > 0 && id <= 1025)
  ? [...new Set(value as number[])] : null;

function response(c: Context, text: string, entityIds: string[] = [], scope: 'game' | 'general' = 'general', complete = true, total?: number): AssistantResponse {
  if (text.length > MAX_ANSWER_LENGTH) {
    const truncated = text.slice(0, MAX_ANSWER_LENGTH - 95);
    text = truncated.slice(0, Math.max(truncated.lastIndexOf('\n'), truncated.lastIndexOf('、'), 0)) + '\n\n以上仅展示部分通用资料，当前版本适用性仍需核对；请缩小查询范围。';
    complete = false;
    scope = 'general';
  }
  entityIds = entityIds.filter((stableId) => {
    const [kind, id] = stableId.split(':');
    const name = entityName(kind as EntityKind, Number(id));
    return name !== null && text.includes(name);
  });
  return {
    status: 'answered', answer: text, confidence: scope === 'game' && complete ? 'high' : 'medium',
    followUp: null, matchedHintIds: ['dex-bundle-structured-resources'],
    verifiedFacts: [`TitoDex 结构化资料 v${c.version}`], unknowns: [],
    evidence: { basis: 'structured', scope, complete, bundleVersion: c.version, entityIds: [...new Set(entityIds)].slice(0, 40), ...(total === undefined ? {} : { total }) },
  };
}

function unavailable(c: Context, message: string): AssistantResponse {
  return { ...response(c, message, [], 'general', false), confidence: 'low' };
}

/** Fixed resource paths, bounded pages and intersections; no model-written query/code. */
export async function answerStructuredResources(c: Context): Promise<AssistantResponse | null> {
  const q = c.request.question;
  const pokemon = mentionedEntities(q, 'pokemon');
  const moves = mentionedEntities(q, 'move');
  const abilities = mentionedEntities(q, 'ability');
  const items = mentionedEntities(q, 'item');
  const filter = /(?:哪些|哪几|都有谁|有什么(?:宝可梦|精灵|招式|特性|道具|树果)|找出|筛选|列出|谁能|谁会)/u.test(q);
  if (filter && /(?:或者|或是|或|排除|除了|不能|不会|不是|不具有|没有)/u.test(q)) return unavailable(c, '当前查询按同时满足条件执行；请将“或”与排除条件拆开查询，避免给出不符合要求的名单。');
  const referenceList = filter && /(?:招式|技能|道具|树果|特性)/u.test(q) && !/(?:宝可梦|精灵|谁|学会|能学|携带)/u.test(q) && !pokemon.length;
  if (referenceList) {
    const kind = /(?:道具|树果)/u.test(q) ? 'item' : /特性/u.test(q) && !/招式|技能/u.test(q) ? 'ability' : 'move';
    return queryReferenceList(c, kind);
  }
  if (filter && (moves.length || abilities.length || items.length || /(?:系|属性|蛋群|颜色|体型|世代|[黑蓝棕灰绿粉紫红白黄]色)/u.test(q) || Object.values(axes.shape).some((name) => q.includes(name)))) {
    return queryPokemon(c);
  }
  if (pokemon.length && /(?:进化|退化)/u.test(q) && !/(?:mega|超级进化|超进化)/iu.test(q)) {
    return queryEvolution(c, pokemon[0].id);
  }
  if (pokemon.length && /(?:身高|体重|蛋群|孵化|捕获率|捕捉率|性别|雌雄|亲密度|基础经验|努力值|成长|栖息地|分类|图鉴描述|形态|种族值|详细资料|基础资料|能学哪些|能学什么|招式表)/u.test(q)) {
    return querySpeciesFields(c, pokemon.map((p) => p.id));
  }
  if (filter && /(?:招式|技能|道具|树果|特性)/u.test(q) && !pokemon.length) {
    const kind = /(?:道具|树果)/u.test(q) ? 'item' : /特性/u.test(q) ? 'ability' : 'move';
    return queryReferenceList(c, kind);
  }
  if (/(?:哪里|哪儿|能抓|捕捉|有哪些|分布)/u.test(q) && !pokemon.length && /(?:路|道路|镇|市|洞|山|湖|森林|塔|岛|水道)/u.test(q)) {
    const location = await queryLocation(c);
    if (location) return location;
  }
  if ((pokemon.length || moves.length || abilities.length || items.length) &&
      !/(?:性格|天气|场地|异常状态)/u.test(q)) return null;
  return queryMechanics(c);
}

async function queryPokemon(c: Context): Promise<AssistantResponse> {
  const q = c.request.question;
  const catalog = await c.read('dex_catalog.json', catalogLimit);
  if (!object(catalog) || !Array.isArray(catalog.summaries)) return unavailable(c, '当前结构化筛选目录尚不可用，暂时无法给出可靠名单。');
  const summaries = rows(catalog.summaries);
  const moves = mentionedEntities(q, 'move');
  const abilities = mentionedEntities(q, 'ability');
  const filters: number[][] = [];
  const labels: string[] = [];
  const references: string[] = [];
  for (const [kind, targets, key] of [['move', moves, 'moveLearners'], ['ability', abilities, 'abilityPokemonIds']] as const) {
    for (const target of targets) {
      const index = catalog[key];
      const members = object(index) ? ids(index[String(target.id)]) : null;
      if (!members) return unavailable(c, `${target.zh}的反向索引缺失，不能把缺失资料当成没有符合条件的宝可梦。`);
      filters.push(members); labels.push(`${kind === 'move' ? '学会' : '特性为'}${target.zh}`); references.push(`${kind}:${target.id}`);
    }
  }
  const requestedTypes = Object.entries(typeNames).filter(([, name]) => q.includes(`${name}系`) || q.includes(`${name}属性`));
  for (const [slug, name] of requestedTypes) {
    filters.push(summaries.filter((row) => Array.isArray(row.types) && row.types.includes(slug)).map((row) => Number(row.id)));
    labels.push(`${name}属性`);
  }
  const colors = axes.color;
  for (const [slug, name] of Object.entries(colors)) if (q.includes(`${name}色`)) {
    filters.push(summaries.filter((row) => row.colorSlug === slug).map((row) => Number(row.id)));
    labels.push(`${name}色`);
  }
  for (const [slug, label] of Object.entries(axes.shape)) if (q.includes(label)) {
    filters.push(summaries.filter((row) => row.shapeSlug === slug).map((row) => Number(row.id)));
    labels.push(label);
  }
  const heldItems = mentionedEntities(q, 'item');
  if (heldItems.length) {
    const itemCatalog = await c.read('items.json', 8 * 1024 * 1024);
    for (const item of heldItems) {
      const value = object(itemCatalog) ? itemCatalog[String(item.id)] : null;
      const members = object(value) ? ids(value.heldByPokemonIds) : null;
      if (!members) return unavailable(c, `${item.zh}的野生携带者索引缺失。`);
      filters.push(members); labels.push(`野生携带${item.zh}`); references.push(`item:${item.id}`);
    }
  }
  if (/蛋群/u.test(q)) {
    const groups = rows(await c.read('egg_groups.json', small)).filter((row) => q.includes(string(row.nameZh)) && string(row.nameZh));
    if (!groups.length) return unavailable(c, '请指定蛋群名称，例如怪兽、水中1或陆上。');
    for (const group of groups) {
      const members = object(catalog.eggGroups) ? ids(catalog.eggGroups[string(group.slug)]) : null;
      if (!members) return unavailable(c, '这个蛋群的成员索引尚未载入。');
      filters.push(members); labels.push(`${string(group.nameZh)}蛋群`);
    }
  }
  const generation = q.match(/第\s*([1-9一二三四五六七八九])\s*(?:世代|代)/u);
  if (generation) {
    const n = Number(generation[1]) || '一二三四五六七八九'.indexOf(generation[1]) + 1;
    filters.push(summaries.filter((row) => row.generation === n).map((row) => Number(row.id)));
    labels.push(`第${n}世代首次登场`);
  }
  if (!filters.length) return unavailable(c, '请给出可查询的条件，例如招式、特性、属性或蛋群名称。');
  // An OR must never accidentally become an intersection.
  const union = /(?:或者|或是|或|任一)/u.test(q);
  if (union && filters.length > 1) return unavailable(c, '请将“或”条件拆成两次查询；当前组合筛选按同时满足各条件执行。');
  let candidates = filters[0].filter((id) => filters.every((filterIds) => filterIds.includes(id)) && entityName('pokemon', id));
  candidates = [...new Set(candidates)].sort((a, b) => a - b);
  const page = Math.min(100, Math.max(1, Number(q.match(/第\s*(\d+)\s*页/u)?.[1] ?? 1)));
  const selected = candidates.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);
  let matched = selected;
  let unknown = 0;
  // The aggregate is global. Check only this explicit page against exact-game learnsets.
  if (moves.length) {
    matched = [];
    for (let offset = 0; offset < selected.length; offset += 4) {
      const checked = await Promise.all(selected.slice(offset, offset + 4).map(async (id) => {
        const shard = await c.read(`gameplay/species/${id}.json`, 1024 * 1024);
        const learn = object(shard) && shard.speciesId === id && object(shard.learn) && object(shard.learn.byVersionGroup)
          ? shard.learn.byVersionGroup[c.versionGroup] : null;
        if (!object(learn) || !['levelUp', 'machine', 'egg', 'tutor'].every((key) => Array.isArray(learn[key]))) return { id, status: 'unknown' };
        const methods = /升级/u.test(q) ? ['levelUp'] : /(?:学习器|机器)/u.test(q) ? ['machine'] : /(?:蛋招式|遗传)/u.test(q) ? ['egg'] : /(?:传授|教学)/u.test(q) ? ['tutor'] : ['levelUp', 'machine', 'egg', 'tutor'];
        const learned = new Set(methods.flatMap((key) => (learn[key] as unknown[]).flatMap((value) => {
          if (typeof value === 'string' && /^move:\d+$/u.test(value)) return [Number(value.slice(5))];
          if (object(value)) return [Number(value.moveId ?? string(value.moveStableId).split(':')[1])];
          return [];
        })));
        return { id, status: moves.every((move) => learned.has(move.id)) ? 'yes' : 'no' };
      }));
      matched.push(...checked.filter((row) => row.status === 'yes').map((row) => row.id));
      unknown += checked.filter((row) => row.status === 'unknown').length;
    }
  }
  if (/隐藏特性/u.test(q) && abilities.length) {
    const hiddenMatches: number[] = [];
    for (const id of matched) {
      const detail = await c.read(`details/${id}.json`, 4 * 1024 * 1024);
      if (!object(detail) || !object(detail.summary) || detail.summary.id !== id || !Array.isArray(detail.abilities)) { unknown++; continue; }
      const hidden = rows(detail.abilities).filter((row) => row.isHidden === true).flatMap((row) => mentionedEntities(`${string(row.nameZh)} ${string(row.nameEn)}`, 'ability').map((a) => a.id));
      if (abilities.every((ability) => hidden.includes(ability.id))) hiddenMatches.push(id);
    }
    matched = hiddenMatches;
  }
  const partial = candidates.length > PAGE_SIZE || unknown > 0;
  const scope = moves.length && filters.length === moves.length ? 'game' : 'general';
  const lines = matched.map((id) => `${entityName('pokemon', id)}（#${id}）`);
  const header = `同时满足“${labels.join('、')}”的结构化查询：`;
  const scopeNote = moves.length
    ? `招式已按《${c.gameLabel}》学习表检查本页候选。${abilities.length || requestedTypes.length ? '特性、属性等其他条件来自通用目录，未确认历史版本或形态差异。' : ''}`
    : '这是通用目录的成员关系，不代表它们在当前游戏都能获得；特性、属性和形态可能随版本变化。';
  return response(c, `${header}\n${lines.length ? lines.join('、') : '本页没有已确认的匹配结果。'}\n\n${scopeNote}\n通用候选共 ${candidates.length} 只；第 ${page} 页检查 ${selected.length} 只，匹配 ${matched.length} 只${unknown ? `，${unknown} 只缺少版本资料` : ''}。${page * PAGE_SIZE < candidates.length ? '可保留条件并加“第2页”等继续查询；以上不是完整名单。' : ''}`,
    [...references, ...matched.map((id) => `pokemon:${id}`)], scope, !partial, candidates.length);
}

async function queryEvolution(c: Context, id: number): Promise<AssistantResponse> {
  const detail = await c.read(`details/${id}.json`, 4 * 1024 * 1024);
  if (!object(detail) || !object(detail.summary) || detail.summary.id !== id) return unavailable(c, '这只宝可梦的结构化进化资料尚不可用。');
  let root = detail.evolutionChain;
  if (/(?:洗翠|阿罗拉|伽勒尔|帕底亚|形态)/u.test(c.request.question)) {
    const forms = rows(detail.forms).filter((form) => {
      const label = string(form.nameZh ?? form.formNameZh);
      return label && c.request.question.includes(label);
    });
    if (forms.length !== 1 || !object(forms[0].evolutionChain)) return unavailable(c, '需要确认具体地区形态才能给出进化关系；当前资料不足以把普通形态的进化链用于该形态。');
    root = forms[0].evolutionChain;
  }
  if (!object(root)) return unavailable(c, '进化链字段缺失，暂时不能确认；这不等于该宝可梦不能进化。');
  const lines: string[] = [];
  const refs = new Set<string>();
  const visited = new Set<number>();
  let valid = true;
  const walk = (node: Row, path: string[]): void => {
    const nodeId = Number(node.id);
    const name = entityName('pokemon', nodeId);
    if (!name || visited.has(nodeId) || visited.size >= 40 || !Array.isArray(node.children)) { valid = false; return; }
    visited.add(nodeId); refs.add(`pokemon:${nodeId}`);
    const next = [...path, name];
    if (!node.children.length) lines.push(next.join(' → '));
    for (const child of node.children) object(child) ? walk(child, next) : valid = false;
  };
  walk(root, []);
  if (!valid || !visited.has(id)) return unavailable(c, '进化链结构未通过校验，暂时不能可靠展示。');
  const wantsConditions = /(?:几级|条件|怎么|如何|道具|亲密|白天|夜晚)/u.test(c.request.question);
  return response(c, `${entityName('pokemon', id)}的通用进化链：\n${lines.map((line) => `- ${line}`).join('\n')}\n\n${wantsConditions ? '进化条件尚未按当前游戏确认；通用条件可能合并不同版本，不能直接作为本版本的等级或操作要求。' : '以上是通用进化关系；地区形态及具体进化条件需按游戏版本核对。'}`, [...refs], 'general', !wantsConditions);
}

async function querySpeciesFields(c: Context, speciesIds: number[]): Promise<AssistantResponse> {
  const q = c.request.question;
  const lines: string[] = [];
  const refs: string[] = [];
  const fields: [RegExp, string, string, string][] = [
    [/身高/u, 'heightDm', '身高', '分米'], [/体重/u, 'weightHg', '体重', '百克'],
    [/(捕获率|捕捉率)/u, 'captureRate', '捕获率参数', ''], [/亲密度/u, 'baseHappiness', '初始亲密度', ''],
    [/(基础经验|经验值)/u, 'baseExperience', '基础经验', ''], [/(性别|雌雄)/u, 'genderFemalePercent', '雌性比例', '%'],
    [/孵化/u, 'hatchCounter', '孵化周期参数', ''], [/成长/u, 'growthRateSlug', '成长曲线', ''],
    [/栖息地/u, 'habitatSlug', '栖息地分类', ''], [/分类/u, 'genusZh', '图鉴分类', ''],
  ];
  for (const id of speciesIds.slice(0, 3)) {
    const d = await c.read(`details/${id}.json`, 4 * 1024 * 1024);
    if (!object(d) || !object(d.summary) || d.summary.id !== id) continue;
    refs.push(`pokemon:${id}`); lines.push(`${entityName('pokemon', id)}：`);
    const all = /(?:基础资料|详细资料)/u.test(q);
    if ((all || /属性/u.test(q)) && Array.isArray(d.summary.types)) lines.push(`- 属性：${d.summary.types.map((type) => typeNames[String(type)]).filter(Boolean).join('／')}`);
    if (all || /特性/u.test(q)) {
      const names = rows(d.abilities).map((ability) => {
        const match = mentionedEntities(string(ability.nameEn).replaceAll('-', ' '), 'ability')[0] ?? mentionedEntities(string(ability.nameZh), 'ability')[0];
        if (!match) return '';
        refs.push(`ability:${match.id}`);
        return `${match.zh}${ability.isHidden === true ? '（隐藏）' : ''}`;
      }).filter(Boolean);
      if (names.length) lines.push(`- 特性：${names.join('、')}`);
    }
    for (const [pattern, key, label, unit] of fields) if ((all || pattern.test(q)) && ['string', 'number'].includes(typeof d[key])) lines.push(`- ${label}：${d[key]}${unit}`);
    if (/(?:蛋群|基础资料|详细资料)/u.test(q) && Array.isArray(d.eggGroups)) lines.push(`- 蛋群：${d.eggGroups.map((v) => typeof v === 'string' ? v : object(v) ? string(v.nameZh ?? v.slug) : '').filter(Boolean).join('、')}`);
    if (/(?:种族值|努力值|基础资料|详细资料)/u.test(q)) {
      for (const [key, label] of [['baseStats', '种族值'], ['evYield', '击败后获得努力值']] as const) {
        if (key === 'evYield' && !/努力值/u.test(q)) continue;
        if (object(d[key])) lines.push(`- ${label}：${Object.entries(d[key]).filter(([, v]) => typeof v === 'number').map(([k, v]) => `${stats[k] ?? k} ${v}`).join('／')}`);
      }
    }
    if (/(?:形态|基础资料|详细资料)/u.test(q)) lines.push(`- 已收录形态：${rows(d.forms).map((form) => string(form.nameZh ?? form.formNameZh ?? form.formKey)).filter(Boolean).join('、') || '没有额外形态记录'}`);
    if (/图鉴描述/u.test(q)) {
      const entries = rows(d.flavorEntries);
      const selected = entries.filter((row) => row.version === c.request.context.game || row.versionGroup === c.versionGroup);
      for (const row of selected.slice(0, 2)) lines.push(`- ${string(row.text ?? row.textZh ?? row.flavorText)}`);
      if (!selected.length) lines.push('- 未找到当前版本的图鉴描述。');
    }
    if (/(?:能学哪些|能学什么|招式表)/u.test(q)) {
      const group = object(d.moveSets) ? d.moveSets[c.versionGroup] : null;
      if (!object(group)) lines.push('- 当前版本的招式表缺失。');
      else for (const [key, label] of [['levelUp', '升级'], ['machine', '学习器'], ['egg', '蛋招式'], ['tutor', '传授']]) {
        const entries = rows(group[key]);
        const names = entries.map((row) => { const moveId = Number(row.moveId); const name = entityName('move', moveId); if (name) refs.push(`move:${moveId}`); return name ? `${name}${key === 'levelUp' ? ` Lv.${row.level}` : ''}` : ''; }).filter(Boolean);
        if (names.length) lines.push(`- ${label}：${names.slice(0, 12).join('、')}${names.length > 12 ? `（仅列前12项，共${names.length}项）` : ''}`);
      }
    }
  }
  if (!lines.length) return unavailable(c, '所需结构化字段尚不可用。');
  return response(c, `${lines.join('\n')}\n\n图鉴字段为通用资料；招式表仅在存在所选版本字段时列出。`, refs, 'general', lines.join('\n').length < 950 && !/仅列|缺失|未找到/u.test(lines.join('\n')));
}

async function queryReferenceList(c: Context, kind: Exclude<EntityKind, 'pokemon'>): Promise<AssistantResponse> {
  if (/(?:治疗|治愈|解除|恢复|回复|免疫|提升|提高|降低|中毒|灼伤|麻痹|睡眠|冰冻|必中|必定|先制)/u.test(c.request.question)) {
    return unavailable(c, '这次查询包含效果条件，目前不能把它可靠转换为目录筛选。请指定条目查看效果资料，或按属性、分类和数值筛选。');
  }
  const value = await c.read(kind === 'item' ? 'items.json' : `${kind === 'ability' ? 'abilities' : 'moves'}.json`, 8 * 1024 * 1024);
  const entries = Array.isArray(value) ? rows(value) : object(value) ? Object.entries(value).flatMap(([id, row]) => object(row) ? [{ ...row, id: row.id ?? Number(id) }] : []) : [];
  if (!entries.length) return unavailable(c, '资料目录尚不可用，无法可靠列出结果。');
  const q = c.request.question;
  let filtered = entries;
  for (const [slug, name] of Object.entries(typeNames)) if (q.includes(`${name}系`) || q.includes(`${name}属性`)) filtered = filtered.filter((row) => row.type === slug);
  if (/树果/u.test(q)) filtered = filtered.filter((row) => /berry|berries/iu.test(string(row.category ?? row.slug)) || /树果/u.test(string(row.categoryZh)));
  if (/(?:物理|特殊|变化)/u.test(q) && kind === 'move') {
    const category = /物理/u.test(q) ? 'physical' : /特殊/u.test(q) ? 'special' : 'status';
    filtered = filtered.filter((row) => row.category === category);
  }
  const numeric = q.match(/(威力|命中|速度|价格|PP)\s*(至少|不低于|大于等于|>=|大于|超过|>|至多|不高于|小于等于|<=|小于|低于|<|等于|为|=)\s*(\d+)/iu);
  if (numeric) {
    const field = ({ 威力: 'power', 命中: 'accuracy', 价格: 'cost', PP: 'pp', pp: 'pp' } as Record<string, string>)[numeric[1]];
    if (!field) return unavailable(c, '这个目录没有所指定的数值字段。');
    const threshold = Number(numeric[3]);
    filtered = filtered.filter((row) => {
      if (typeof row[field] !== 'number') return false;
      if (/^(?:至少|不低于|大于等于|>=)$/u.test(numeric[2])) return row[field] >= threshold;
      if (/^(?:至多|不高于|小于等于|<=)$/u.test(numeric[2])) return row[field] <= threshold;
      if (/^(?:大于|超过|>)$/u.test(numeric[2])) return row[field] > threshold;
      if (/^(?:小于|低于|<)$/u.test(numeric[2])) return row[field] < threshold;
      return row[field] === threshold;
    });
  }
  const page = Math.max(1, Number(q.match(/第\s*(\d+)\s*页/u)?.[1] ?? 1));
  const selected = filtered.sort((a, b) => Number(a.id) - Number(b.id)).slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);
  return response(c, `通用${kind === 'move' ? '招式' : kind === 'ability' ? '特性' : '道具'}目录匹配 ${filtered.length} 项，第 ${page} 页：\n${selected.map((row) => entityName(kind, Number(row.id))).filter(Boolean).join('、') || '本页没有记录。'}\n\n这是通用目录筛选，数值、效果和可获得性需按游戏版本核对。${filtered.length > PAGE_SIZE ? '当前只展示部分结果，可保留条件并加页码继续。' : ''}`, selected.map((row) => `${kind}:${row.id}`), 'general', filtered.length <= PAGE_SIZE, filtered.length);
}

const mechanics = [
  { file: 'natures.json', pattern: /(?:性格|胆小|内敛|固执|爽朗|勇敢|冷静|悠闲|慎重|温和|大胆|淘气|勤奋|浮躁|认真|害羞|坦率|急躁|天真|孤独|怕寂寞|调皮|乐天|慢吞吞|马虎|温顺)/u },
  { file: 'egg_groups.json', pattern: /蛋群/u },
  { file: 'weather.json', pattern: /(?:天气|晴天|日照|下雨|雨天|沙暴|冰雹|雪天|大雪|乱流)/u },
  { file: 'terrains.json', pattern: /场地/u },
  { file: 'status_conditions.json', pattern: /(?:异常状态|中毒|剧毒|灼伤|麻痹|睡眠|冰冻|混乱|畏缩)/u },
  { file: 'types.json', pattern: /(?:属性|系).{0,8}(?:克制|弱点|抗性|免疫)|(?:克制|弱点|抗性|免疫).{0,8}(?:属性|系)/u },
];
async function queryMechanics(c: Context): Promise<AssistantResponse | null> {
  const resource = mechanics.find((entry) => entry.pattern.test(c.request.question));
  if (!resource) return null;
  const raw = await c.read(resource.file, small);
  const entries: Row[] = Array.isArray(raw) ? rows(raw) : object(raw) ? Object.entries(raw).flatMap(([slug, row]) => object(row) ? [{ ...row, slug }] : []) : [];
  if (!entries.length) return unavailable(c, '这部分资料尚未载入。');
  const q = c.request.question;
  const selected = entries.filter((row) => [row.nameZh, row.nameEn].some((name) => typeof name === 'string' && name.length > 1 && q.toLowerCase().includes(name.toLowerCase())) || (resource.file === 'types.json' && q.includes(`${typeNames[string(row.slug)]}系`)));
  if (!selected.length) return response(c, `已收录：${entries.map((row) => string(row.nameZh)).filter(Boolean).join('、')}。请指定要查询的名称。`, [], 'general', false);
  const lines: string[] = [];
  for (const row of selected.slice(0, 3)) {
    const name = string(row.nameZh);
    if (typeof row.introducedGeneration === 'number' && row.introducedGeneration > c.request.context.generation) { lines.push(`${name}晚于所选游戏的世代引入。`); continue; }
    lines.push(`${name}：`);
    for (const key of ['descriptionZh', 'effectZh']) if (typeof row[key] === 'string') lines.push(string(row[key]));
    if (resource.file === 'natures.json') {
      const up = string(row.increasedStat ?? row.increasedStatSlug), down = string(row.decreasedStat ?? row.decreasedStatSlug);
      lines.push(up && down ? `提升${stats[up] ?? up}，降低${stats[down] ?? down}。` : '能力值不受性格修正。');
    }
    if (resource.file === 'types.json') {
      const relations = object(row.damageRelations) ? row.damageRelations : row;
      for (const [key, label] of [['doubleDamageTo', '攻击效果绝佳'], ['halfDamageTo', '攻击效果不好'], ['noDamageTo', '攻击无效'], ['doubleDamageFrom', '防守弱点'], ['halfDamageFrom', '防守抗性'], ['noDamageFrom', '防守免疫']]) {
        if (Array.isArray(relations[key])) lines.push(`${label}：${(relations[key] as unknown[]).filter((v): v is string => typeof v === 'string').map((v) => typeNames[v] ?? v).join('、') || '无'}`);
      }
    }
    if (Array.isArray(row.generationRules)) for (const rule of rows(row.generationRules).filter((r) => Number(r.fromGeneration) <= c.request.context.generation && (r.toGeneration === undefined || Number(r.toGeneration) >= c.request.context.generation))) {
      if (typeof rule.moveMultiplier === 'number') lines.push(`对应招式威力倍率：${rule.moveMultiplier}。`);
      if (typeof rule.residualDamageDenominator === 'number') lines.push(`每回合损失最大HP的 1/${rule.residualDamageDenominator}。`);
      if (typeof rule.physicalAttackMultiplier === 'number') lines.push(`物理攻击倍率：${rule.physicalAttackMultiplier}。`);
    }
  }
  return response(c, `${lines.join('\n')}\n\n以上引用已收录机制资料；未声明精确版本或仍待审核的字段不能视为本版本已核验。`, [], 'general');
}

async function queryLocation(c: Context): Promise<AssistantResponse | null> {
  const index = await c.read('location_index.json', 16 * 1024 * 1024);
  if (!object(index) || !object(index.byVersion)) return null;
  const version = index.byVersion[c.request.context.game];
  const entries: Row[] = Array.isArray(version) ? rows(version) : object(version) ? Object.entries(version).flatMap(([slug, row]) => object(row) ? [{ ...row, slug }] : []) : [];
  const matches = entries.filter((row) => [row.labelZh, row.nameZh, row.areaLabelZh].some((v) => typeof v === 'string' && v.length > 1 && c.request.question.normalize('NFKC').includes(v.normalize('NFKC'))))
    .sort((a, b) => string(b.labelZh ?? b.nameZh ?? b.areaLabelZh).length - string(a.labelZh ?? a.nameZh ?? a.areaLabelZh).length);
  if (!matches.length) return null;
  const area = matches[0];
  if (matches.length > 1 && string(matches[1].labelZh).length === string(area.labelZh).length) return unavailable(c, '这个地点名称对应多个区域，请补充区域名称。');
  const members = ids(area.pokemonIds ?? area.speciesIds ?? rows(area.entries).map((row) => row.speciesId));
  if (!members) return null;
    return response(c, `《${c.gameLabel}》${string(area.labelZh ?? area.nameZh ?? area.areaLabelZh)}的已收录宝可梦：\n${members.slice(0, PAGE_SIZE).map((id) => entityName('pokemon', id)).filter(Boolean).join('、')}。${members.length > PAGE_SIZE ? `仅列前${PAGE_SIZE}只，共${members.length}只。` : ''}\n\n包含不同时段、遭遇方法和特殊条件的记录；不表示当前进度下都能立即遇到。`, members.slice(0, PAGE_SIZE).map((id) => `pokemon:${id}`), 'game', members.length <= PAGE_SIZE, members.length);
}
