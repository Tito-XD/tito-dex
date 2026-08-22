import speciesLabels from '../../../flutter/assets/l10n/zh/species_labels.json';
import itemLabels from '../../../flutter/assets/l10n/zh/items_labels.json';
import moveLabels from '../../../flutter/assets/l10n/zh/moves_labels.json';
import abilityLabels from '../../../flutter/assets/l10n/zh/abilities_labels.json';
import {
  effectiveContextReliability,
  MAX_ANSWER_LENGTH,
  type AssistantRequest,
  type AssistantResponse,
} from './contract';
import type { CuratedSource } from './curated_web';

const MAX_MANIFEST_BYTES = 64 * 1024;
const MAX_DETAIL_BYTES = 4 * 1024 * 1024;
const MAX_ITEMS_BYTES = 2 * 1024 * 1024;
const MAX_MOVES_BYTES = 256 * 1024;
const MAX_CATALOG_BYTES = 4 * 1024 * 1024;
const MAX_GAMEPLAY_SHARD_BYTES = 1024 * 1024;
const MAX_AREAS = 6;

type SpeciesLabel = { en?: string; zh?: string };
type EntityTarget = { id: number; nameZh: string; aliases: string[] };

type EncounterEntry = {
  areaSlug: string;
  areaLabelZh: string;
  minLevel?: number;
  maxLevel?: number;
  methods: string[];
  conditions: string[];
  isAlpha: boolean;
  isTitan: boolean;
  isRaid: boolean;
  isFixedEncounter: boolean;
};

type EvolutionEdge = {
  fromId: number;
  fromName: string;
  toId: number;
  toName: string;
  triggers: Record<string, unknown>[];
};

type GameplaySpeciesShard = {
  obtain: Record<string, unknown>;
  learn: Record<string, unknown>;
  evolutions: Record<string, unknown>[];
};

const speciesTargets = buildTargets(speciesLabels as Record<string, SpeciesLabel>);
const itemTargets = buildTargets(itemLabels as Record<string, SpeciesLabel>);
const moveTargets = buildTargets(moveLabels as Record<string, SpeciesLabel>);
const abilityTargets = buildTargets(abilityLabels as Record<string, SpeciesLabel>);

const encounterIntent = /(?:哪里|哪儿|在哪|何处|怎么抓|如何抓|怎么捉|如何捉|可以抓|能抓|捕捉|捕获|抓到|捉到|遇到|出没|分布|栖息)/u;
const evolutionIntent = /(?:进化|退化|进化链)/u;
const heldItemIntent = /(?:携带|持有|带着|身上|掉落|偷到|偷取|野生.*道具|道具.*野生)/u;
const moveLearningIntent = /(?:学会|能学|可以学|几级|招式|技能|学习器|蛋招式)/u;
const speciesProfileIntent = /(?:属性|弱点|抗性|免疫|种族值|能力值|特性|隐藏特性|基础资料|详细资料|是什么宝可梦)/u;
const itemInfoIntent = /(?:作用|用途|效果|干嘛|是什么|价格|多少钱|分类|怎么用|道具)/u;
const moveInfoIntent = /(?:威力|命中|pp|属性|类型|分类|效果|招式|技能)/iu;
const abilityInfoIntent = /(?:作用|效果|是什么|特性)/u;
const bundlePrefix = /^v[1-9]\d{0,3}$/;

const gameVersionGroups: Record<AssistantRequest['context']['game'], string> = {
  diamond: 'diamond-pearl',
  pearl: 'diamond-pearl',
  platinum: 'platinum',
  heartgold: 'heartgold-soulsilver',
  soulsilver: 'heartgold-soulsilver',
  black: 'black-white',
  white: 'black-white',
  'black-2': 'black-2-white-2',
  'white-2': 'black-2-white-2',
  x: 'x-y',
  y: 'x-y',
  'omega-ruby': 'omega-ruby-alpha-sapphire',
  'alpha-sapphire': 'omega-ruby-alpha-sapphire',
  sun: 'sun-moon',
  moon: 'sun-moon',
  'ultra-sun': 'ultra-sun-ultra-moon',
  'ultra-moon': 'ultra-sun-ultra-moon',
  sword: 'sword-shield',
  shield: 'sword-shield',
  'brilliant-diamond': 'brilliant-diamond-shining-pearl',
  'shining-pearl': 'brilliant-diamond-shining-pearl',
  'legends-arceus': 'legends-arceus',
  scarlet: 'scarlet-violet',
  violet: 'scarlet-violet',
};

const gameLabels: Record<AssistantRequest['context']['game'], string> = {
  diamond: '钻石',
  pearl: '珍珠',
  platinum: '白金',
  heartgold: '心金',
  soulsilver: '魂银',
  black: '黑',
  white: '白',
  'black-2': '黑2',
  'white-2': '白2',
  x: 'X',
  y: 'Y',
  'omega-ruby': '欧米伽红宝石',
  'alpha-sapphire': '阿尔法蓝宝石',
  sun: '太阳',
  moon: '月亮',
  'ultra-sun': '究极之日',
  'ultra-moon': '究极之月',
  sword: '剑',
  shield: '盾',
  'brilliant-diamond': '晶灿钻石',
  'shining-pearl': '明亮珍珠',
  'legends-arceus': '传说 阿尔宙斯',
  scarlet: '朱',
  violet: '紫',
};

const methodLabels: Record<string, string> = {
  walk: '草丛行走',
  wild: '野外遭遇',
  overworld: '明雷',
  'overworld-special': '特殊明雷',
  'overworld-water': '水上明雷',
  'overworld-flying': '空中明雷',
  surf: '冲浪',
  'old-rod': '破旧钓竿',
  'good-rod': '好钓竿',
  'super-rod': '厉害钓竿',
  'rock-smash': '碎岩',
  headbutt: '撞树',
  'honey-tree': '甜甜蜜树',
  horde: '群聚对战',
  sos: '闯入对战',
  'sos-encounter': '闯入对战',
  raid: '团体战',
  'max-raid': '极巨团体战',
  'dynamax-adventure': '极巨大冒险',
  outbreak: '大量出现',
  swarm: '大量出现',
  gift: '赠送',
  'gift-egg': '赠送的蛋',
  'npc-trade': 'NPC 交换',
  static: '固定遭遇',
  fixed: '固定遭遇',
  wanderer: '游走明雷',
  'dark-grass': '深色草丛',
  'hidden-grotto': '隐藏洞穴',
};

const typeLabels: Record<string, string> = {
  normal: '一般',
  fire: '火',
  water: '水',
  electric: '电',
  grass: '草',
  ice: '冰',
  fighting: '格斗',
  poison: '毒',
  ground: '地面',
  flying: '飞行',
  psychic: '超能力',
  bug: '虫',
  rock: '岩石',
  ghost: '幽灵',
  dragon: '龙',
  dark: '恶',
  steel: '钢',
  fairy: '妖精',
};

/**
 * Resolve bounded structured facts from TitoDex's versioned Dex bundle.
 * The App still talks only to this Worker; no R2 URL or credential is exposed.
 */
export async function answerFromDexBundle(
  request: AssistantRequest,
  bucket: R2Bucket | undefined,
): Promise<AssistantResponse | null> {
  if (!bucket) return null;
  const species = findTarget(request.question, speciesTargets);
  const item = findTarget(request.question, itemTargets);
  const move = findTarget(request.question, moveTargets);
  const ability = findTarget(request.question, abilityTargets);
  if (!species && !item && !move && !ability) return null;

  const manifest = await readJsonObject(bucket, 'bundle-manifest.json', MAX_MANIFEST_BYTES);
  if (!validBundleManifest(manifest)) return null;

  const bundleVersion = manifest.bundleVersion as number;
  if (species) {
    const detail = await readJsonObject(
      bucket,
      `${manifest.cdnPrefix}/details/${species.id}.json`,
      MAX_DETAIL_BYTES,
    );
    if (!detail || !isPlainObject(detail.summary) || detail.summary.id !== species.id) {
      return null;
    }
    const gameplayShard = bundleVersion >= 20
      ? await readGameplaySpeciesShard(bucket, manifest.cdnPrefix as string, species.id)
      : null;
    if (encounterIntent.test(request.question)) {
      return answerEncounter(request, detail, species, bundleVersion, gameplayShard);
    }
    if (move && moveLearningIntent.test(request.question)) {
      return answerMoveLearning(request, detail, species, move, bundleVersion, gameplayShard);
    }
    if (heldItemIntent.test(request.question)) {
      const items = await readJsonObject(
        bucket,
        `${manifest.cdnPrefix}/items.json`,
        MAX_ITEMS_BYTES,
      );
      return answerHeldItems(request, detail, species, item, items, bundleVersion);
    }
    if (speciesProfileIntent.test(request.question)) {
      return answerSpeciesProfile(request, detail, species, bundleVersion);
    }
  }

  if (item && itemInfoIntent.test(request.question)) {
    const items = await readJsonObject(
      bucket,
      `${manifest.cdnPrefix}/items.json`,
      MAX_ITEMS_BYTES,
    );
    return answerItemInfo(request, item, items, bundleVersion);
  }
  if (ability && abilityInfoIntent.test(request.question)) {
    const catalog = await readJsonObject(
      bucket,
      `${manifest.cdnPrefix}/dex_catalog.json`,
      MAX_CATALOG_BYTES,
    );
    return answerAbilityInfo(request, ability, catalog, bundleVersion);
  }
  return null;
}

/**
 * Build a small, internally generated evidence object for open-ended Qwen
 * composition. It deliberately excludes flavor prose and held-item rows (the
 * latter include a separately licensed 52Poké batch); those remain available
 * only through deterministic, attributed answers above.
 */
export async function buildDexBundleSources(
  request: AssistantRequest,
  bucket: R2Bucket | undefined,
): Promise<CuratedSource[]> {
  if (!bucket) return [];
  const species = findTarget(request.question, speciesTargets);
  const item = findTarget(request.question, itemTargets);
  const move = findTarget(request.question, moveTargets);
  const ability = findTarget(request.question, abilityTargets);
  if (!species && !item && !move && !ability) return [];
  // Evolution conditions and standalone move values can differ by generation.
  // Preserve the existing exact-version PokéAPI path for those questions.
  if (move && moveInfoIntent.test(request.question)) {
    return [];
  }
  const manifest = await readJsonObject(bucket, 'bundle-manifest.json', MAX_MANIFEST_BYTES);
  if (!validBundleManifest(manifest)) return [];
  const bundleVersion = manifest.bundleVersion as number;
  const prefix = manifest.cdnPrefix as string;
  const facts: Record<string, unknown> = {
    sourceBundleVersion: bundleVersion,
    exactGame: request.context.game,
  };

  if (species) {
    const [detail, gameplayShard] = await Promise.all([
      readJsonObject(bucket, `${prefix}/details/${species.id}.json`, MAX_DETAIL_BYTES),
      bundleVersion >= 20
        ? readGameplaySpeciesShard(bucket, prefix, species.id)
        : Promise.resolve(null),
    ]);
    if (detail && isPlainObject(detail.summary) && detail.summary.id === species.id) {
      facts.species = compactSpeciesEvidence(
        detail,
        species,
        request.context.game,
        gameplayShard,
      );
    }
  }
  if (item) {
    const items = await readJsonObject(bucket, `${prefix}/items.json`, MAX_ITEMS_BYTES);
    if (items && isPlainObject(items[String(item.id)])) {
      const value = items[String(item.id)] as Record<string, unknown>;
      facts.item = {
        id: item.id,
        nameZh: item.nameZh,
        ...(typeof value.categoryZh === 'string'
          ? { categoryZh: cleanText(value.categoryZh, 80) }
          : {}),
        ...(typeof value.cost === 'number' && Number.isInteger(value.cost)
          ? { catalogCost: value.cost }
          : {}),
      };
    }
  }
  if (move) {
    const moves = await readJsonObject(bucket, `${prefix}/moves.json`, MAX_MOVES_BYTES);
    if (moves && isPlainObject(moves[String(move.id)])) {
      facts.move = compactMoveEvidence(moves[String(move.id)] as Record<string, unknown>, move);
    }
  }
  if (ability) {
    facts.ability = { id: ability.id, nameZh: ability.nameZh };
  }
  if (Object.keys(facts).length <= 2) return [];
  return [{
    id: `dex-bundle-v${bundleVersion}`,
    title: `TitoDex Dex bundle v${bundleVersion} · 结构化事实`,
    text: JSON.stringify(facts).slice(0, 6_000),
  }];
}

function answerEncounter(
  request: AssistantRequest,
  detail: Record<string, unknown>,
  target: EntityTarget,
  bundleVersion: number,
  gameplayShard: GameplaySpeciesShard | null,
): AssistantResponse | null {
  const verifiedByExactVersion = gameplayShard && isPlainObject(gameplayShard.obtain.byExactVersion)
    ? gameplayShard.obtain.byExactVersion
    : null;
  const shardEntries = verifiedByExactVersion?.[request.context.game];
  const rawEntries = Array.isArray(shardEntries)
    ? shardEntries
    : isPlainObject(detail.obtainLocationsByVersion)
      ? detail.obtainLocationsByVersion[request.context.game]
      : null;
  if (!Array.isArray(rawEntries)) return null;
  const entries = rawEntries.flatMap((value) => {
    const parsed = Array.isArray(shardEntries)
      ? parseGameplayEncounter(value)
      : parseEncounter(value);
    return parsed ? [parsed] : [];
  });
  if (entries.length === 0) return null;

  const grouped = groupEncounters(entries).slice(0, MAX_AREAS);
  if (grouped.length === 0) return null;
  const remainingAreas = Math.max(0, new Set(entries.map((entry) => entry.areaSlug)).size - grouped.length);
  const lines = grouped.map((group) =>
    `- ${group.label}：${group.details.join('；')}`,
  );
  const extra = remainingAreas > 0
    ? `\n此外还有 ${remainingAreas} 个地点记录；可以补充“前期／固定点／团体战”等条件继续缩小。`
    : '';
  const answer = [
    `《宝可梦 ${gameLabels[request.context.game]}》的 TitoDex v${bundleVersion} 图鉴包记录到${target.nameZh}可在以下地点获得：`,
    lines.join('\n'),
    extra.trim(),
  ].filter(Boolean).join('\n\n').slice(0, MAX_ANSWER_LENGTH);

  return bundleResponse(
    request,
    answer,
    bundleVersion,
    `encounter-${request.context.game}-${target.id}`,
    [`species:${target.id}`, `game:${request.context.game}`],
  );
}

function findTarget(question: string, targets: EntityTarget[]): EntityTarget | null {
  const normalizedZh = normalize(question);
  const normalizedEn = question.toLowerCase();
  for (const target of targets) {
    if (target.aliases.some((alias) =>
      /[\u3400-\u9fff]/u.test(alias)
        ? normalizedZh.includes(normalize(alias))
        : normalizedEn.includes(alias.toLowerCase()),
    )) return target;
  }
  return null;
}

function answerHeldItems(
  request: AssistantRequest,
  detail: Record<string, unknown>,
  species: EntityTarget,
  requestedItem: EntityTarget | null,
  items: Record<string, unknown> | null,
  bundleVersion: number,
): AssistantResponse | null {
  if (!Array.isArray(detail.heldItems) || !items) return null;
  const itemBySlug = new Map<string, { id: number; name: string }>();
  for (const [id, value] of Object.entries(items)) {
    if (!isPlainObject(value) || typeof value.slug !== 'string' ||
        typeof value.nameZh !== 'string' || !/^\d{1,5}$/.test(id)) continue;
    itemBySlug.set(value.slug, { id: Number(id), name: cleanText(value.nameZh, 80) });
  }
  const rows = detail.heldItems.flatMap((value) => {
    if (!isPlainObject(value) || typeof value.slug !== 'string' ||
        !isPlainObject(value.rarityByVersion)) return [];
    const rarity = value.rarityByVersion[request.context.game];
    if (typeof rarity !== 'number' || !Number.isFinite(rarity) || rarity <= 0 || rarity > 100) {
      return [];
    }
    const item = itemBySlug.get(value.slug);
    if (!item || (requestedItem && item.id !== requestedItem.id)) return [];
    return [{ ...item, rarity }];
  }).sort((left, right) => right.rarity - left.rarity || left.id - right.id);
  if (rows.length === 0) return null;
  const lines = rows.slice(0, 8).map((row) =>
    `- ${row.name}：${formatPercent(row.rarity)}`,
  );
  return bundleResponse(
    request,
    `《宝可梦 ${gameLabels[request.context.game]}》中，TitoDex v${bundleVersion} 记录的野生${species.nameZh}携带物：\n${lines.join('\n')}\n\n这是野生携带概率，不等于剧情必需品；只有审核流程资料明确关联时，才会说它能推进剧情。`,
    bundleVersion,
    `held-items-${request.context.game}-${species.id}`,
    [`species:${species.id}`, `game:${request.context.game}`, 'field:heldItems'],
    'high',
    ['携带物批次包含 PokeAPI 与 52Poké 数据；52Poké 部分按 CC BY-NC-SA 4.0 署名使用。'],
  );
}

function answerMoveLearning(
  request: AssistantRequest,
  detail: Record<string, unknown>,
  species: EntityTarget,
  move: EntityTarget,
  bundleVersion: number,
  gameplayShard: GameplaySpeciesShard | null,
): AssistantResponse | null {
  const versionGroup = gameVersionGroups[request.context.game];
  const shardGroups = gameplayShard && isPlainObject(gameplayShard.learn.byVersionGroup)
    ? gameplayShard.learn.byVersionGroup
    : null;
  const shardGroup = shardGroups?.[versionGroup];
  const group = isPlainObject(shardGroup)
    ? shardGroup
    : isPlainObject(detail.moveSets)
      ? detail.moveSets[versionGroup]
      : null;
  if (!isPlainObject(group)) return null;
  const methods: string[] = [];
  const levelRows = Array.isArray(group.levelUp) ? group.levelUp : [];
  const levels = levelRows.flatMap((value) =>
    isPlainObject(value) && (
      value.moveId === move.id || value.moveStableId === `move:${move.id}`
    ) && validLevel(value.level)
      ? [value.level]
      : [],
  );
  if (levels.length > 0) {
    methods.push(`升级：${Array.from(new Set(levels)).sort((a, b) => a - b).map((level) => `Lv.${level}`).join('、')}`);
  }
  const methodGroups: [string, string][] = [
    ['machine', '招式学习器'],
    ['egg', '蛋招式'],
    ['tutor', '招式传授'],
  ];
  for (const [key, label] of methodGroups) {
    const values = group[key];
    if (Array.isArray(values) && values.some((value) =>
      value === `move:${move.id}` || (isPlainObject(value) && (
        value.moveId === move.id || value.moveStableId === `move:${move.id}`
      )),
    )) methods.push(label);
  }
  if (methods.length === 0) return null;
  return bundleResponse(
    request,
    `《宝可梦 ${gameLabels[request.context.game]}》的 TitoDex v${bundleVersion} 招式表记录：${species.nameZh}可通过${methods.join('；')}学会${move.nameZh}。`,
    bundleVersion,
    `move-learning-${request.context.game}-${species.id}-${move.id}`,
    [`species:${species.id}`, `move:${move.id}`, `game:${request.context.game}`],
  );
}

function answerSpeciesProfile(
  request: AssistantRequest,
  detail: Record<string, unknown>,
  species: EntityTarget,
  bundleVersion: number,
): AssistantResponse | null {
  const lines: string[] = [];
  const summary = isPlainObject(detail.summary) ? detail.summary : null;
  if (/(?:属性|是什么宝可梦|基础资料|详细资料)/u.test(request.question) &&
      summary && Array.isArray(summary.types)) {
    const types = summary.types.filter((value): value is string =>
      typeof value === 'string' && Object.hasOwn(typeLabels, value),
    );
    if (types.length > 0) lines.push(`属性：${types.map((value) => typeLabels[value]).join('／')}`);
  }
  if (/(?:弱点|抗性|免疫|基础资料|详细资料)/u.test(request.question)) {
    const weaknesses = cleanStringArray(detail.weaknesses, 8);
    const resistances = cleanStringArray(detail.resistances, 8);
    const immunities = cleanStringArray(detail.immunities, 8);
    if (weaknesses.length > 0) lines.push(`弱点：${weaknesses.join('、')}`);
    if (resistances.length > 0) lines.push(`抗性：${resistances.join('、')}`);
    if (immunities.length > 0) lines.push(`免疫：${immunities.join('、')}`);
  }
  if (/(?:种族值|能力值|基础资料|详细资料)/u.test(request.question) &&
      isPlainObject(detail.baseStats)) {
    const stats = [
      ['HP', detail.baseStats.hp],
      ['攻击', detail.baseStats.attack],
      ['防御', detail.baseStats.defense],
      ['特攻', detail.baseStats.specialAttack],
      ['特防', detail.baseStats.specialDefense],
      ['速度', detail.baseStats.speed],
    ].filter((entry): entry is [string, number] =>
      typeof entry[1] === 'number' && Number.isInteger(entry[1]),
    );
    if (stats.length > 0) {
      lines.push(`种族值：${stats.map(([name, value]) => `${name} ${value}`).join('／')}`);
    }
  }
  if (/(?:特性|基础资料|详细资料)/u.test(request.question) && Array.isArray(detail.abilities)) {
    const abilities = detail.abilities.flatMap((value) =>
      isPlainObject(value) && typeof value.nameZh === 'string'
        ? [`${cleanText(value.nameZh, 60)}${value.isHidden === true ? '（隐藏）' : ''}`]
        : [],
    ).slice(0, 6);
    if (abilities.length > 0) lines.push(`特性：${abilities.join('、')}`);
  }
  if (lines.length === 0) return null;
  return bundleResponse(
    request,
    `TitoDex v${bundleVersion} 的${species.nameZh}图鉴资料：\n${lines.map((line) => `- ${line}`).join('\n')}`,
    bundleVersion,
    `profile-${species.id}`,
    [`species:${species.id}`, 'field:profile'],
    'medium',
    ['这是当前通用图鉴字段；涉及旧世代数值变化时需再按版本核对。'],
  );
}

function answerItemInfo(
  request: AssistantRequest,
  item: EntityTarget,
  items: Record<string, unknown> | null,
  bundleVersion: number,
): AssistantResponse | null {
  if (!items || !isPlainObject(items[String(item.id)])) return null;
  const value = items[String(item.id)] as Record<string, unknown>;
  if (value.id !== item.id || typeof value.nameZh !== 'string') return null;
  const details: string[] = [];
  if (typeof value.categoryZh === 'string') details.push(`分类：${cleanText(value.categoryZh, 80)}`);
  if (typeof value.cost === 'number' && Number.isInteger(value.cost) && value.cost >= 0) {
    details.push(`图鉴包价格字段：${value.cost}`);
  }
  const description = typeof value.effectZh === 'string'
    ? cleanText(value.effectZh, 220)
    : typeof value.descriptionZh === 'string'
      ? cleanText(value.descriptionZh, 220)
      : '';
  if (description) details.push(`说明：${description}`);
  if (details.length === 0) return null;
  return bundleResponse(
    request,
    `TitoDex v${bundleVersion} 的${item.nameZh}资料：\n${details.map((line) => `- ${line}`).join('\n')}`,
    bundleVersion,
    `item-${item.id}`,
    [`item:${item.id}`],
    'medium',
    ['道具价格与效果可能随版本变化；未标为当前版本专属值。'],
  );
}

function answerAbilityInfo(
  request: AssistantRequest,
  ability: EntityTarget,
  catalog: Record<string, unknown> | null,
  bundleVersion: number,
): AssistantResponse | null {
  if (!catalog || !isPlainObject(catalog.abilities) ||
      !isPlainObject(catalog.abilities[String(ability.id)])) return null;
  const value = catalog.abilities[String(ability.id)] as Record<string, unknown>;
  const description = typeof value.descriptionZh === 'string'
    ? cleanText(value.descriptionZh, 240)
    : '';
  if (!description) return null;
  return bundleResponse(
    request,
    `TitoDex v${bundleVersion} 的${ability.nameZh}特性说明：${description}`,
    bundleVersion,
    `ability-${ability.id}`,
    [`ability:${ability.id}`],
    'medium',
    ['这是 bundle 的通用特性说明；旧世代效果变化需再按版本核对。'],
  );
}

function bundleResponse(
  request: AssistantRequest,
  answer: string,
  bundleVersion: number,
  matchId: string,
  facts: string[],
  confidence: AssistantResponse['confidence'] = 'high',
  unknowns: string[] = [],
): AssistantResponse {
  const reliability = effectiveContextReliability(request.context);
  return {
    status: 'answered',
    answer: answer.slice(0, MAX_ANSWER_LENGTH),
    contextUsed: {
      game: request.context.game,
      gameReliability: reliability.game,
      contextReliability: reliability,
    },
    matchedHintIds: [`dex-bundle-${matchId}`],
    verifiedFacts: [`TitoDex Dex bundle v${bundleVersion}`, ...facts],
    unknowns,
    confidence,
    followUp: null,
    onlineComposed: false,
  };
}

function validBundleManifest(value: Record<string, unknown> | null): value is Record<string, unknown> & {
  bundleVersion: number;
  cdnPrefix: string;
} {
  return value !== null && value.complete === true && value.exactVersionLocations === true &&
    typeof value.cdnPrefix === 'string' && bundlePrefix.test(value.cdnPrefix) &&
    Number.isInteger(value.bundleVersion) && (value.bundleVersion as number) >= 1;
}

function compactSpeciesEvidence(
  detail: Record<string, unknown>,
  species: EntityTarget,
  game: AssistantRequest['context']['game'],
  gameplayShard: GameplaySpeciesShard | null,
): Record<string, unknown> {
  const summary = isPlainObject(detail.summary) ? detail.summary : {};
  const evidence: Record<string, unknown> = {
    id: species.id,
    nameZh: species.nameZh,
    versionedFor: game,
  };
  if (Array.isArray(summary.types)) {
    evidence.types = summary.types.filter((value): value is string =>
      typeof value === 'string' && Object.hasOwn(typeLabels, value),
    ).slice(0, 2);
  }
  if (isPlainObject(detail.baseStats)) {
    evidence.baseStats = Object.fromEntries(
      Object.entries(detail.baseStats).filter(([, value]) =>
        typeof value === 'number' && Number.isInteger(value),
      ).slice(0, 6),
    );
  }
  const weaknesses = cleanStringArray(detail.weaknesses, 8);
  const resistances = cleanStringArray(detail.resistances, 8);
  const immunities = cleanStringArray(detail.immunities, 8);
  if (weaknesses.length > 0) evidence.weaknessesZh = weaknesses;
  if (resistances.length > 0) evidence.resistancesZh = resistances;
  if (immunities.length > 0) evidence.immunitiesZh = immunities;
  if (Array.isArray(detail.abilities)) {
    evidence.abilities = detail.abilities.flatMap((value) =>
      isPlainObject(value) && typeof value.nameZh === 'string'
        ? [{ nameZh: cleanText(value.nameZh, 60), hidden: value.isHidden === true }]
        : [],
    ).slice(0, 6);
  }
  const verifiedByExactVersion = gameplayShard && isPlainObject(gameplayShard.obtain.byExactVersion)
    ? gameplayShard.obtain.byExactVersion
    : null;
  const shardEncounters = verifiedByExactVersion?.[game];
  const rawEncounters = Array.isArray(shardEncounters)
    ? shardEncounters
    : isPlainObject(detail.obtainLocationsByVersion) &&
        Array.isArray(detail.obtainLocationsByVersion[game])
      ? detail.obtainLocationsByVersion[game]
      : null;
  if (Array.isArray(rawEncounters)) {
    evidence.encounters = rawEncounters
      .flatMap((value) => {
        const encounter = Array.isArray(shardEncounters)
          ? parseGameplayEncounter(value)
          : parseEncounter(value);
        return encounter ? [{
          area: normalizeFullWidth(encounter.areaLabelZh),
          methods: encounter.methods.slice(0, 4),
          ...(encounter.minLevel === undefined ? {} : { minLevel: encounter.minLevel }),
          ...(encounter.maxLevel === undefined ? {} : { maxLevel: encounter.maxLevel }),
        }] : [];
      })
      .slice(0, 12);
  }
  const versionGroup = gameVersionGroups[game];
  const shardLearnGroups = gameplayShard && isPlainObject(gameplayShard.learn.byVersionGroup)
    ? gameplayShard.learn.byVersionGroup
    : null;
  const usingShardMoveSet = isPlainObject(shardLearnGroups?.[versionGroup]);
  const rawMoveSet = usingShardMoveSet
    ? shardLearnGroups?.[versionGroup]
    : isPlainObject(detail.moveSets) && isPlainObject(detail.moveSets[versionGroup])
      ? detail.moveSets[versionGroup]
      : null;
  if (isPlainObject(rawMoveSet)) {
    const set = rawMoveSet;
    const compactRows = usingShardMoveSet ? compactGameplayMoveRows : compactMoveRows;
    evidence.moveSet = {
      levelUp: compactRows(set.levelUp, 24, true),
      machine: compactRows(set.machine, 24, false),
      egg: compactRows(set.egg, 16, false),
      tutor: compactRows(set.tutor, 16, false),
      truncated: true,
    };
  }
  if (gameplayShard && gameplayShard.evolutions.length > 0) {
    evidence.adjacentEvolution = gameplayShard.evolutions.slice(0, 6).map((row) => {
      const safeTriggers = Array.isArray(row.triggers)
        ? row.triggers.filter(isPlainObject).slice(0, 6)
        : [];
      return {
        fromStableId: row.fromPokemonStableId,
        toStableId: row.toPokemonStableId,
        conditionsZh: describeEvolutionTriggers(safeTriggers),
        exactGameApplicability: isPlainObject(row.applicabilityByVersionGroup)
          ? row.applicabilityByVersionGroup[versionGroup]
          : 'unknown',
      };
    });
  } else if (isPlainObject(detail.evolutionChain)) {
    evidence.adjacentEvolution = collectEvolutionEdges(detail.evolutionChain)
      .filter((edge) => edge.fromId === species.id || edge.toId === species.id)
      .slice(0, 6)
      .map((edge) => ({
        from: edge.fromName,
        to: edge.toName,
        conditions: describeEvolutionTriggers(edge.triggers),
      }));
  }
  evidence.scopeNote = gameplayShard
    ? 'encounters and moveSet come from the bounded audited v20 species shard; evolution triggers are global and exact-game applicability remains explicit'
    : 'encounters and moveSet are selected-game facts; stats/types/abilities/evolution are general bundle fields and may differ in older games';
  return evidence;
}

function compactGameplayMoveRows(value: unknown, maximum: number, includeLevel: boolean): unknown[] {
  if (!Array.isArray(value)) return [];
  return value.flatMap((entry) => {
    const stableId = typeof entry === 'string'
      ? entry
      : isPlainObject(entry) && typeof entry.moveStableId === 'string'
        ? entry.moveStableId
        : '';
    const match = /^move:([1-9]\d{0,4})$/u.exec(stableId);
    if (!match) return [];
    const id = Number(match[1]);
    const target = moveTargets.find((candidate) => candidate.id === id);
    if (!target) return [];
    return [{
      id,
      nameZh: target.nameZh,
      ...(includeLevel && isPlainObject(entry) && validLevel(entry.level)
        ? { level: entry.level }
        : {}),
    }];
  }).slice(0, maximum);
}

function compactMoveRows(value: unknown, maximum: number, includeLevel: boolean): unknown[] {
  if (!Array.isArray(value)) return [];
  return value.flatMap((entry) => {
    if (!isPlainObject(entry) || !Number.isInteger(entry.moveId)) return [];
    const target = moveTargets.find((candidate) => candidate.id === entry.moveId);
    if (!target) return [];
    return [{
      id: target.id,
      nameZh: target.nameZh,
      ...(includeLevel && validLevel(entry.level) ? { level: entry.level } : {}),
    }];
  }).slice(0, maximum);
}

function compactMoveEvidence(
  value: Record<string, unknown>,
  move: EntityTarget,
): Record<string, unknown> {
  return {
    id: move.id,
    nameZh: move.nameZh,
    ...(typeof value.type === 'string' ? { type: value.type } : {}),
    ...(typeof value.category === 'string' ? { category: value.category } : {}),
    ...(typeof value.power === 'number' ? { power: value.power } : {}),
    ...(typeof value.accuracy === 'number' ? { accuracy: value.accuracy } : {}),
    ...(typeof value.pp === 'number' ? { pp: value.pp } : {}),
    scopeNote: 'general bundle move values; older-game changes require separate versioned confirmation',
  };
}

function collectEvolutionEdges(root: Record<string, unknown>): EvolutionEdge[] {
  const edges: EvolutionEdge[] = [];
  const visit = (node: Record<string, unknown>): void => {
    if (!Number.isInteger(node.id) || typeof node.nameZh !== 'string' ||
        !Array.isArray(node.children)) return;
    for (const childValue of node.children) {
      if (!isPlainObject(childValue) || !Number.isInteger(childValue.id) ||
          typeof childValue.nameZh !== 'string') continue;
      const triggers = Array.isArray(childValue.triggers)
        ? childValue.triggers.filter(isPlainObject).slice(0, 6)
        : [];
      edges.push({
        fromId: node.id as number,
        fromName: cleanText(node.nameZh, 60),
        toId: childValue.id as number,
        toName: cleanText(childValue.nameZh, 60),
        triggers,
      });
      visit(childValue);
    }
  };
  visit(root);
  return edges;
}

function describeEvolutionTriggers(triggers: Record<string, unknown>[]): string {
  if (triggers.length === 0) return '图鉴包未记录具体条件';
  return triggers.map((trigger) => {
    const details: string[] = [];
    if (trigger.trigger === 'level-up') details.push('升级');
    else if (trigger.trigger === 'use-item') details.push('使用进化道具');
    else if (trigger.trigger === 'trade') details.push('交换');
    else if (typeof trigger.trigger === 'string') details.push('特殊条件');
    if (validLevel(trigger.minLevel)) details.push(`至少 Lv.${trigger.minLevel}`);
    if (typeof trigger.minHappiness === 'number' && Number.isInteger(trigger.minHappiness)) {
      details.push(`亲密度至少 ${trigger.minHappiness}`);
    }
    if (trigger.timeOfDay === 'day') details.push('白天');
    if (trigger.timeOfDay === 'night') details.push('夜晚');
    if (typeof trigger.item === 'string') {
      details.push(`道具 ${labelForSlug(trigger.item, itemTargets)}`);
    }
    if (typeof trigger.heldItem === 'string') {
      details.push(`携带 ${labelForSlug(trigger.heldItem, itemTargets)}`);
    }
    if (typeof trigger.knownMove === 'string') {
      details.push(`学会 ${labelForSlug(trigger.knownMove, moveTargets)}`);
    }
    if (trigger.needsOverworldRain === true) details.push('下雨时');
    if (trigger.turnUpsideDown === true) details.push('倒置设备');
    return details.length > 0 ? details.join('、') : '特殊条件';
  }).join('；或 ');
}

function labelForSlug(slug: string, targets: EntityTarget[]): string {
  const normalizedSlug = normalize(slug.replace(/-/gu, ' '));
  const target = targets.find((candidate) => candidate.aliases.some((alias) =>
    !/[\u3400-\u9fff]/u.test(alias) && normalize(alias) === normalizedSlug,
  ));
  return target?.nameZh ?? cleanText(slug, 60);
}

function buildTargets(labels: Record<string, SpeciesLabel>): EntityTarget[] {
  return Object.entries(labels).flatMap(([id, label]) => {
    if (!/^\d{1,5}$/.test(id) || !label.zh?.trim()) return [];
    const aliases = [label.zh.trim(), label.en?.trim() ?? '']
      .filter((value) => value.length >= 2)
      .sort((left, right) => right.length - left.length);
    return [{ id: Number(id), nameZh: label.zh.trim(), aliases }];
  }).sort((left, right) => {
    const leftLength = Math.max(...left.aliases.map((value) => value.length));
    const rightLength = Math.max(...right.aliases.map((value) => value.length));
    return rightLength - leftLength || left.id - right.id;
  });
}

function cleanStringArray(value: unknown, maximum: number): string[] {
  if (!Array.isArray(value)) return [];
  return value.flatMap((entry) =>
    typeof entry === 'string' && cleanText(entry, 60)
      ? [cleanText(entry, 60)]
      : [],
  ).slice(0, maximum);
}

function formatPercent(value: number): string {
  return `${Number.isInteger(value) ? value : Number(value.toFixed(2))}%`;
}

function parseEncounter(value: unknown): EncounterEntry | null {
  if (!isPlainObject(value) || typeof value.areaSlug !== 'string' ||
      !/^[a-z0-9][a-z0-9._-]{0,119}$/.test(value.areaSlug) ||
      typeof value.areaLabelZh !== 'string') return null;
  const label = cleanText(value.areaLabelZh, 80);
  if (!label || !Array.isArray(value.methods) || !Array.isArray(value.conditions)) {
    return null;
  }
  const methods = value.methods.filter((item): item is string =>
    typeof item === 'string' && /^[a-z0-9][a-z0-9-]{0,59}$/.test(item),
  ).slice(0, 8);
  const conditions = value.conditions.filter((item): item is string =>
    typeof item === 'string' && /^[a-z0-9][a-z0-9-]{0,79}$/.test(item),
  ).slice(0, 8);
  if (methods.length === 0) return null;
  const minLevel = validLevel(value.minLevel) ? value.minLevel : undefined;
  const maxLevel = validLevel(value.maxLevel) ? value.maxLevel : undefined;
  return {
    areaSlug: value.areaSlug,
    areaLabelZh: label,
    ...(minLevel === undefined ? {} : { minLevel }),
    ...(maxLevel === undefined ? {} : { maxLevel }),
    methods,
    conditions,
    isAlpha: value.isAlpha === true,
    isTitan: value.isTitan === true,
    isRaid: value.isRaid === true,
    isFixedEncounter: value.isFixedEncounter === true,
  };
}

function parseGameplayEncounter(value: unknown): EncounterEntry | null {
  if (!isPlainObject(value) || !Array.isArray(value.encounterMethods) ||
      typeof value.method !== 'string') return null;
  const methods = Array.from(new Set([
    ...value.encounterMethods,
    value.method,
  ].filter((entry): entry is string => typeof entry === 'string')));
  return parseEncounter({
    areaSlug: value.areaSlug,
    areaLabelZh: value.areaLabelZh,
    minLevel: value.minLevel,
    maxLevel: value.maxLevel,
    methods,
    conditions: value.conditions,
    isAlpha: value.isAlpha,
    isTitan: value.isTitan,
    isRaid: value.isRaid,
    isFixedEncounter: value.isFixedEncounter,
  });
}

function groupEncounters(entries: EncounterEntry[]): { label: string; details: string[] }[] {
  const sorted = [...entries].sort((left, right) =>
    encounterPriority(left) - encounterPriority(right) ||
    (left.minLevel ?? 999) - (right.minLevel ?? 999) ||
    left.areaLabelZh.localeCompare(right.areaLabelZh, 'zh-Hans'),
  );
  const groups = new Map<string, { label: string; details: string[]; seen: Set<string> }>();
  for (const entry of sorted) {
    const group = groups.get(entry.areaSlug) ?? {
      label: normalizeFullWidth(entry.areaLabelZh),
      details: [],
      seen: new Set<string>(),
    };
    const detail = describeEncounter(entry);
    if (!group.seen.has(detail)) {
      group.seen.add(detail);
      if (group.details.length < 3) group.details.push(detail);
    }
    groups.set(entry.areaSlug, group);
  }
  return [...groups.values()].map(({ label, details }) => ({ label, details }));
}

function describeEncounter(entry: EncounterEntry): string {
  const methods = Array.from(new Set(entry.methods.map((method) =>
    methodLabels[method] ?? '特殊遭遇',
  ))).join('／');
  const level = formatLevel(entry.minLevel, entry.maxLevel);
  const tags = [
    entry.isAlpha ? '头目' : '',
    entry.isTitan ? '宝主' : '',
    entry.isRaid && !entry.methods.includes('raid') && !entry.methods.includes('max-raid')
      ? '团体战'
      : '',
    entry.isFixedEncounter && !entry.methods.includes('fixed') && !entry.methods.includes('static')
      ? '固定点'
      : '',
    entry.conditions.length > 0 ? '有出现条件' : '',
  ].filter(Boolean);
  return [methods, level, ...tags].filter(Boolean).join('，');
}

function encounterPriority(entry: EncounterEntry): number {
  if (entry.isRaid || entry.methods.some((method) => method.includes('raid'))) return 4;
  if (entry.isFixedEncounter || entry.methods.includes('fixed') || entry.methods.includes('static')) {
    return 2;
  }
  if (entry.methods.includes('gift') || entry.methods.includes('gift-egg') ||
      entry.methods.includes('npc-trade')) return 3;
  return 1;
}

function formatLevel(minimum?: number, maximum?: number): string {
  if (minimum === undefined && maximum === undefined) return '';
  if (minimum === maximum || maximum === undefined) return `Lv.${minimum}`;
  if (minimum === undefined) return `最高 Lv.${maximum}`;
  return `Lv.${minimum}–${maximum}`;
}

async function readJsonObject(
  bucket: R2Bucket,
  key: string,
  maxBytes: number,
): Promise<Record<string, unknown> | null> {
  let object: R2ObjectBody | null;
  try {
    object = await bucket.get(key);
  } catch {
    return null;
  }
  if (!object || object.size < 2 || object.size > maxBytes) return null;
  try {
    const bytes = await readBounded(object.body, maxBytes);
    const value: unknown = JSON.parse(new TextDecoder().decode(bytes));
    return isPlainObject(value) ? value : null;
  } catch {
    return null;
  }
}

async function readGameplaySpeciesShard(
  bucket: R2Bucket,
  prefix: string,
  speciesId: number,
): Promise<GameplaySpeciesShard | null> {
  const value = await readJsonObject(
    bucket,
    `${prefix}/gameplay/species/${speciesId}.json`,
    MAX_GAMEPLAY_SHARD_BYTES,
  );
  return validGameplaySpeciesShard(value, speciesId);
}

function validGameplaySpeciesShard(
  value: Record<string, unknown> | null,
  speciesId: number,
): GameplaySpeciesShard | null {
  if (!value || !hasExactKeys(value, [
    'schemaVersion', 'speciesId', 'pokemonStableId', 'provenance',
    'obtain', 'learn', 'evolutions',
  ]) || value.schemaVersion !== 1 || value.speciesId !== speciesId ||
      value.pokemonStableId !== `pokemon:${speciesId}` ||
      !isPlainObject(value.provenance) || !hasExactKeys(value.provenance, [
        'generator', 'pokeapiCommit', 'pkhexCommit',
      ]) || value.provenance.generator !== 'titodex-gameplay-shards-v1' ||
      !validSourceCommit(value.provenance.pokeapiCommit) ||
      !validSourceCommit(value.provenance.pkhexCommit) ||
      !validGameplayObtain(
        value.obtain,
        speciesId,
        value.provenance.pokeapiCommit as string,
        value.provenance.pkhexCommit as string,
      ) ||
      !validGameplayLearn(value.learn, speciesId) ||
      !validGameplayEvolutions(value.evolutions, speciesId)) {
    return null;
  }
  return {
    obtain: value.obtain,
    learn: value.learn,
    evolutions: value.evolutions,
  };
}

function validGameplayObtain(
  value: unknown,
  speciesId: number,
  pokeapiCommit: string,
  pkhexCommit: string,
): value is Record<string, unknown> {
  if (!isPlainObject(value) || !hasExactKeys(value, [
    'stableId', 'byExactVersion', 'verifiedRouteByVersionGroup',
    'derivedFamilyRouteByVersionGroup',
  ]) || value.stableId !== `pokemon:${speciesId}` ||
      !isPlainObject(value.byExactVersion) || Object.keys(value.byExactVersion).length > 51 ||
      !validRouteMap(value.verifiedRouteByVersionGroup, ['direct', 'notApplicable', 'unknown']) ||
      !validRouteMap(value.derivedFamilyRouteByVersionGroup, [
        'direct', 'evolution', 'egg', 'trade', 'notApplicable', 'unknown',
      ])) return false;
  for (const [version, rows] of Object.entries(value.byExactVersion)) {
    if (!/^[a-z0-9-]{1,60}$/u.test(version) || !Array.isArray(rows) ||
        rows.length < 1 || rows.length > 4096 ||
        !rows.every((row) => validGameplayEncounterRow(
          row,
          version,
          pokeapiCommit,
          pkhexCommit,
        ))) return false;
  }
  return true;
}

function validGameplayEncounterRow(
  value: unknown,
  exactVersion: string,
  pokeapiCommit: string,
  pkhexCommit: string,
): boolean {
  if (!isPlainObject(value) || !hasExactKeys(value, [
    'method', 'exactVersion', 'versionGroup', 'areaSlug', 'areaLabelZh',
    'minLevel', 'maxLevel', 'rateKind', 'rateValue', 'encounterMethods',
    'conditions', 'formStableId', 'isAlpha', 'isTitan', 'isRaid',
    'isFixedEncounter', 'source',
  ]) || !['wild', 'fixed', 'raid'].includes(String(value.method)) ||
      value.exactVersion !== exactVersion ||
      typeof value.versionGroup !== 'string' || !/^[a-z0-9-]{1,80}$/u.test(value.versionGroup) ||
      typeof value.areaSlug !== 'string' || !/^[a-z0-9][a-z0-9._-]{0,119}$/u.test(value.areaSlug) ||
      typeof value.areaLabelZh !== 'string' || !value.areaLabelZh || value.areaLabelZh.length > 160 ||
      !validOptionalLevel(value.minLevel) || !validOptionalLevel(value.maxLevel) ||
      typeof value.rateKind !== 'string' || value.rateKind.length > 60 ||
      !(value.rateValue === null || (
        typeof value.rateValue === 'number' && Number.isFinite(value.rateValue) &&
        value.rateValue >= 0 && value.rateValue <= 1_000_000_000
      )) || !validBoundedStrings(value.encounterMethods, 32, 160) ||
      !validBoundedStrings(value.conditions, 32, 160) ||
      !(value.formStableId === null || (
        typeof value.formStableId === 'string' &&
        /^pokemon-form:[a-z0-9-]{1,100}$/u.test(value.formStableId)
      )) || !['isAlpha', 'isTitan', 'isRaid', 'isFixedEncounter'].every(
        (key) => typeof value[key] === 'boolean',
      ) || !isPlainObject(value.source) ||
      !Object.keys(value.source).every((key) => ['sourceId', 'commit', 'license', 'overlay'].includes(key)) ||
      typeof value.source.sourceId !== 'string' || !['pokeapi-api-data', 'pkhex-overlay'].includes(value.source.sourceId) ||
      !validSourceCommit(value.source.commit) || value.source.commit !== (
        value.source.sourceId === 'pokeapi-api-data' ? pokeapiCommit : pkhexCommit
      )) return false;
  return true;
}

function validGameplayLearn(value: unknown, speciesId: number): value is Record<string, unknown> {
  if (!isPlainObject(value) || !hasExactKeys(value, ['stableId', 'sourceStatus', 'byVersionGroup']) ||
      value.stableId !== `pokemon:${speciesId}` ||
      !['covered', 'unknown'].includes(String(value.sourceStatus)) ||
      !isPlainObject(value.byVersionGroup) || Object.keys(value.byVersionGroup).length > 32) return false;
  for (const [group, buckets] of Object.entries(value.byVersionGroup)) {
    if (!/^[a-z0-9-]{1,80}$/u.test(group) || !isPlainObject(buckets) ||
        !['levelUp', 'machine', 'egg', 'tutor'].every((key) => Object.hasOwn(buckets, key)) ||
        Object.keys(buckets).some((key) => !['levelUp', 'machine', 'egg', 'tutor', 'other'].includes(key))) {
      return false;
    }
    let rowCount = 0;
    for (const [bucket, rows] of Object.entries(buckets)) {
      if (!Array.isArray(rows)) return false;
      rowCount += rows.length;
      if (rowCount > 4096 || !rows.every((row) => validGameplayLearnRow(row, bucket))) return false;
    }
  }
  return true;
}

function validGameplayLearnRow(value: unknown, bucket: string): boolean {
  if (['machine', 'egg', 'tutor'].includes(bucket)) {
    return typeof value === 'string' && /^move:[1-9]\d{0,4}$/u.test(value);
  }
  return isPlainObject(value) && Object.keys(value).every((key) =>
    ['moveStableId', 'level', 'method'].includes(key),
  ) && typeof value.moveStableId === 'string' &&
    /^move:[1-9]\d{0,4}$/u.test(value.moveStableId) &&
    (value.level === undefined || validLevel(value.level)) &&
    (bucket !== 'other' || (typeof value.method === 'string' && value.method.length <= 80));
}

function validGameplayEvolutions(value: unknown, speciesId: number): value is Record<string, unknown>[] {
  if (!Array.isArray(value) || value.length > 64) return false;
  return value.every((row) => {
    if (!isPlainObject(row) || !hasExactKeys(row, [
      'stableId', 'fromPokemonStableId', 'toPokemonStableId', 'triggers',
      'applicabilityByVersionGroup', 'source',
    ]) || typeof row.fromPokemonStableId !== 'string' ||
        typeof row.toPokemonStableId !== 'string') return false;
    const from = /^pokemon:([1-9]\d{0,4})$/u.exec(row.fromPokemonStableId);
    const to = /^pokemon:([1-9]\d{0,4})$/u.exec(row.toPokemonStableId);
    if (!from || !to || ![Number(from[1]), Number(to[1])].includes(speciesId) ||
        row.stableId !== `evolution:${from[1]}:${to[1]}` ||
        !Array.isArray(row.triggers) || row.triggers.length > 16 ||
        !row.triggers.every((trigger) => isPlainObject(trigger) && Object.keys(trigger).length <= 40) ||
        !validRouteMap(row.applicabilityByVersionGroup, ['unknown', 'notApplicable']) ||
        !isPlainObject(row.source) || row.source.sourceId !== 'pokeapi-api-data') return false;
    return true;
  });
}

function validRouteMap(value: unknown, allowed: string[]): boolean {
  return isPlainObject(value) && Object.keys(value).length >= 1 &&
    Object.keys(value).length <= 32 && Object.entries(value).every(([group, route]) =>
      /^[a-z0-9-]{1,80}$/u.test(group) && typeof route === 'string' && allowed.includes(route),
    );
}

function validOptionalLevel(value: unknown): boolean {
  return value === null || validLevel(value);
}

function validBoundedStrings(value: unknown, maximum: number, maxLength: number): boolean {
  return Array.isArray(value) && value.length <= maximum && value.every((entry) =>
    typeof entry === 'string' && entry.length <= maxLength,
  );
}

function validSourceCommit(value: unknown): boolean {
  return typeof value === 'string' && /^[0-9a-f]{40}$/u.test(value);
}

function hasExactKeys(value: Record<string, unknown>, keys: string[]): boolean {
  const expected = new Set(keys);
  return Object.keys(value).length === expected.size &&
    Object.keys(value).every((key) => expected.has(key));
}

async function readBounded(
  stream: ReadableStream<Uint8Array>,
  maxBytes: number,
): Promise<Uint8Array> {
  const reader = stream.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > maxBytes) {
      await reader.cancel('dex_bundle_object_too_large');
      throw new Error('dex_bundle_object_too_large');
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return bytes;
}

function cleanText(value: string, maxLength: number): string {
  return value.replace(/[\u0000-\u001f\u007f]/gu, ' ').trim().slice(0, maxLength);
}

function normalize(value: string): string {
  return value.toLowerCase().replace(/[\s·・,，.。!?！？()（）\-_/]/gu, '');
}

function normalizeFullWidth(value: string): string {
  return value.replace(/[０-９]/gu, (digit) =>
    String.fromCharCode(digit.charCodeAt(0) - 0xfee0),
  );
}

function validLevel(value: unknown): value is number {
  return Number.isInteger(value) && (value as number) >= 1 && (value as number) <= 100;
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
