import speciesLabels from '../../../flutter/assets/l10n/zh/species_labels.json';
import itemLabels from '../../../flutter/assets/l10n/zh/items_labels.json';
import moveLabels from '../../../flutter/assets/l10n/zh/moves_labels.json';
import abilityLabels from '../../../flutter/assets/l10n/zh/abilities_labels.json';
import {
  effectiveContextReliability,
  MAX_ANSWER_LENGTH,
  MAX_CLARIFICATION_CANDIDATES,
  type AssistantRequest,
  type AssistantResponse,
  type ClarificationCandidate,
} from './contract';
import type { CuratedSource } from './curated_web';
import { answerStructuredResources } from './structured_resources';
import { entityName, mentionedEntities } from './structured_entities';
import { isGeneralPokemonFranchiseRequest } from './pokemon_question_scope';
import { needsExpandedAnswer } from './answer_coverage';
import { conversationRetrievalRequest } from './conversation_context';

const MAX_MANIFEST_BYTES = 64 * 1024;
const MAX_DETAIL_BYTES = 4 * 1024 * 1024;
const MAX_ITEMS_BYTES = 2 * 1024 * 1024;
const MAX_MOVES_BYTES = 256 * 1024;
const MAX_CATALOG_BYTES = 8 * 1024 * 1024;
const MAX_REFERENCE_SHARD_BYTES = 64 * 1024;
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

type ReferenceDataConfig = {
  moves: string;
  abilities: string;
  items: string;
  itemSlugIndex: string;
  sourceCommit: string;
};

type HeldItemLookup = Map<string, { id: number; name: string }>;

export type DexBundleAnswerResult = {
  response: AssistantResponse;
  localSource: CuratedSource;
  requiresOnlineVerification: boolean;
  coversQuestion: boolean;
};

const speciesTargets = buildTargets(speciesLabels as Record<string, SpeciesLabel>);
const itemTargets = buildTargets(itemLabels as Record<string, SpeciesLabel>);
const moveTargets = buildTargets(moveLabels as Record<string, SpeciesLabel>);
const abilityTargets = buildTargets(abilityLabels as Record<string, SpeciesLabel>);

const fuzzySpeciesGroups: readonly { pattern: RegExp; ids: ReadonlySet<number> }[] = [
  {
    pattern: /(?:小狗|狗|犬|狼|豺|狐狸|狐)/u,
    ids: new Set([
      37, 38, 58, 59, 133, 196, 197, 209, 210, 228, 229, 261, 262,
      309, 310, 447, 448, 506, 507, 508, 653, 654, 655, 744, 745, 827,
      828, 835, 836, 888, 889, 926, 927, 942, 943,
    ]),
  },
  {
    pattern: /(?:小猫|猫|狮|虎|豹)/u,
    ids: new Set([
      52, 53, 196, 197, 300, 301, 431, 432, 509, 510, 667, 668, 725,
      726, 727, 807, 863, 906, 907, 908,
    ]),
  },
];

const fuzzyColorPatterns: readonly [string, RegExp][] = [
  ['black', /(?:黑|黑色)/u],
  ['blue', /(?:蓝|蓝色|青蓝)/u],
  ['brown', /(?:棕|褐|棕色|褐色)/u],
  ['gray', /(?:灰|银灰|灰色)/u],
  ['green', /(?:绿|绿色)/u],
  ['pink', /(?:粉|粉色)/u],
  ['purple', /(?:紫|紫色)/u],
  ['red', /(?:红|红色)/u],
  ['white', /(?:白|白色)/u],
  ['yellow', /(?:黄|黄色)/u],
];

const fuzzyTypePatterns: readonly [string, RegExp][] = [
  ['normal', /(?:一般|普通)(?:系|属性)/u],
  ['fire', /火(?:系|属性)/u],
  ['water', /水(?:系|属性)/u],
  ['electric', /电(?:系|属性)/u],
  ['grass', /草(?:系|属性)/u],
  ['ice', /冰(?:系|属性)/u],
  ['fighting', /格斗(?:系|属性)/u],
  ['poison', /毒(?:系|属性)/u],
  ['ground', /地面(?:系|属性)/u],
  ['flying', /飞行(?:系|属性)/u],
  ['psychic', /(?:超能力|超能)(?:系|属性)/u],
  ['bug', /虫(?:系|属性)/u],
  ['rock', /岩石(?:系|属性)/u],
  ['ghost', /幽灵(?:系|属性)/u],
  ['dragon', /龙(?:系|属性)/u],
  ['dark', /恶(?:系|属性)/u],
  ['steel', /钢(?:系|属性)/u],
  ['fairy', /妖精(?:系|属性)/u],
];

const regionalDexKeys: Partial<Record<AssistantRequest['context']['game'], readonly string[]>> = {
  diamond: ['original-sinnoh', 'extended-sinnoh'],
  pearl: ['original-sinnoh', 'extended-sinnoh'],
  platinum: ['extended-sinnoh', 'original-sinnoh'],
  heartgold: ['updated-johto', 'original-johto'],
  soulsilver: ['updated-johto', 'original-johto'],
  black: ['original-unova', 'updated-unova'],
  white: ['original-unova', 'updated-unova'],
  'black-2': ['updated-unova', 'original-unova'],
  'white-2': ['updated-unova', 'original-unova'],
  x: ['kalos-central', 'kalos-coastal', 'kalos-mountain'],
  y: ['kalos-central', 'kalos-coastal', 'kalos-mountain'],
  sun: ['original-alola'],
  moon: ['original-alola'],
  'ultra-sun': ['updated-alola'],
  'ultra-moon': ['updated-alola'],
  sword: ['galar', 'isle-of-armor', 'crown-tundra'],
  shield: ['galar', 'isle-of-armor', 'crown-tundra'],
  'brilliant-diamond': ['original-sinnoh', 'extended-sinnoh'],
  'shining-pearl': ['original-sinnoh', 'extended-sinnoh'],
  'legends-arceus': ['hisui'],
  scarlet: ['paldea', 'kitakami', 'blueberry'],
  violet: ['paldea', 'kitakami', 'blueberry'],
};

const encounterIntent = /(?:哪里|哪儿|在哪|何处|怎么抓|如何抓|怎么捉|如何捉|可以抓|能抓|捕捉|捕获|抓到|捉到|遇到|出没|分布|栖息|\b(?:catch|caught|capture|encounter|habitat|spawn(?:s|ing)?)\b|\bwhere\b.{0,60}\b(?:find|found|appear|appears)\b)/iu;
const heldItemIntent = /(?:携带|持有|带着|身上|掉落|偷到|偷取|野生.*道具|道具.*野生)/u;
const moveLearningIntent = /(?:学会|能学|可以学|能用|能使用|可以用|会不会|几级|招式|技能|学习器|蛋招式|\b(?:learn(?:s|ed|ing)?|learnset|moves?|tm\d*|hm\d*|egg moves?)\b|\b(?:what|which) level\b|\b(?:can|could)\b.{0,60}\buse\b)/iu;
const speciesProfileIntent = /(?:属性|弱点|抗性|免疫|种族值|能力值|特性|隐藏特性|基础资料|详细资料|是什么宝可梦)/u;
const itemInfoIntent = /(?:作用|用途|效果|干嘛|干什么|什么用|啥用|有用吗|介绍|资料|是什么|价格|多少钱|分类|怎么用|道具)/u;
const moveInfoIntent = /(?:威力|命中|pp|属性|类型|分类|作用|用途|效果|干嘛|干什么|什么用|啥用|有用吗|介绍|资料|招式|技能)/iu;
const abilityInfoIntent = /(?:作用|用途|效果|干嘛|干什么|什么用|啥用|有用吗|介绍|资料|是什么|特性)/u;
const bundlePrefix = /^v[1-9]\d{0,3}$/;

const gameVersionGroups: Record<AssistantRequest['context']['game'], string> = {
  general: '',
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
  general: '通用',
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
): Promise<DexBundleAnswerResult | null> {
  if (!bucket || isGeneralPokemonFranchiseRequest(request)) return null;
  const retrievalRequest = conversationRetrievalRequest(request);
  // A relationship or profile is evidence for an explanation, not the
  // explanation itself. Keep these questions on the existing research path.
  if (/(?:为什么|为何|原因|原理|\bwhy\b)/iu.test(request.question)) return null;
  // A missing game still permits general reference facts, but never a guessed
  // encounter, learnset, wild held item or edition-specific description.
  if (request.context.game === 'general' && (
    encounterIntent.test(request.question) || moveLearningIntent.test(request.question) ||
    heldItemIntent.test(request.question) ||
    /(?:招式表|能学哪些|能学什么|会哪些招式|图鉴描述)/u.test(request.question)
  )) return null;
  const species = findTarget(retrievalRequest.question, speciesTargets);
  const item = findTarget(retrievalRequest.question, itemTargets);
  const move = findTarget(retrievalRequest.question, moveTargets);
  const ability = findTarget(retrievalRequest.question, abilityTargets);
  const manifest = await readJsonObject(bucket, 'bundle-manifest.json', MAX_MANIFEST_BYTES);
  if (!validBundleManifest(manifest)) return null;

  const bundleVersion = manifest.bundleVersion as number;
  const structured = await answerStructuredResources({
    request: retrievalRequest, version: bundleVersion, versionGroup: gameVersionGroups[request.context.game],
    gameLabel: gameLabels[request.context.game],
    read: async (path, limit) => {
      // Resource names originate exclusively in the fixed query adapters.
      if (!/^[a-z_]+(?:\/[a-z_]+)*\/\d+\.json$|^[a-z_]+\.json$/u.test(path)) return null;
      try {
        const value = await bucket.get(`${manifest.cdnPrefix}/${path}`);
        if (!value) return null;
        if (value.size > limit) { await value.body.cancel(); return null; }
        return JSON.parse(new TextDecoder().decode(await readBounded(value.body, limit)));
      }
      catch { return null; }
    },
  });
  if (structured) {
    const result = bundleAnswerResult(request, structured, bundleVersion);
    // This response explicitly states its data scope, including missing fields.
    // A language model cannot upgrade that scope or replace the query result.
    return result ? { ...result, requiresOnlineVerification: !result.coversQuestion } : null;
  }
  if (!species && !item && !move && !ability) return null;
  const referenceConfig = bundleVersion >= 20
    ? validReferenceDataConfig(manifest.referenceData, manifest.referenceDataSourceCommit)
    : null;
  if (species) {
    const detail = await readJsonObject(
      bucket,
      `${manifest.cdnPrefix}/details/${species.id}.json`,
      MAX_DETAIL_BYTES,
    );
    if (!detail || !isPlainObject(detail.summary) || detail.summary.id !== species.id) {
      return null;
    }
    const gameplayShard = bundleVersion >= 20 && request.context.game !== 'general'
      ? await readGameplaySpeciesShard(bucket, manifest.cdnPrefix as string, species.id)
      : null;
    if (encounterIntent.test(retrievalRequest.question) && !(move && moveLearningIntent.test(retrievalRequest.question))) {
      return bundleAnswerResult(
        request,
        answerEncounter(request, detail, species, bundleVersion, gameplayShard),
        bundleVersion,
      );
    }
    if (move && moveLearningIntent.test(retrievalRequest.question)) {
      return bundleAnswerResult(
        request,
        answerMoveLearning(request, detail, species, move, bundleVersion, gameplayShard),
        bundleVersion,
      );
    }
    if (heldItemIntent.test(request.question)) {
      const itemLookup = bundleVersion >= 20
        ? referenceConfig
          ? await readHeldItemLookup(bucket, manifest.cdnPrefix as string, detail, referenceConfig)
          : null
        : itemLookupFromAggregate(await readJsonObject(
          bucket,
          `${manifest.cdnPrefix}/items.json`,
          MAX_ITEMS_BYTES,
        ));
      return bundleAnswerResult(
        request,
        answerHeldItems(request, detail, species, item, itemLookup, bundleVersion),
        bundleVersion,
      );
    }
    if (speciesProfileIntent.test(request.question)) {
      return bundleAnswerResult(
        request,
        answerSpeciesProfile(request, detail, species, bundleVersion),
        bundleVersion,
      );
    }
  }

  if (item && itemInfoIntent.test(request.question)) {
    const value = bundleVersion >= 20
      ? referenceConfig
        ? await readReferenceEntityShard(bucket, manifest.cdnPrefix as string, 'item', item, referenceConfig)
        : null
      : recordFromAggregate(await readJsonObject(
        bucket,
        `${manifest.cdnPrefix}/items.json`,
        MAX_ITEMS_BYTES,
      ), item.id);
    return bundleAnswerResult(
      request,
      answerItemInfo(request, item, value, bundleVersion),
      bundleVersion,
    );
  }
  if (ability && abilityInfoIntent.test(request.question)) {
    const value = bundleVersion >= 20
      ? referenceConfig
        ? await readReferenceEntityShard(bucket, manifest.cdnPrefix as string, 'ability', ability, referenceConfig)
        : null
      : recordFromCatalog(await readJsonObject(
        bucket,
        `${manifest.cdnPrefix}/dex_catalog.json`,
        MAX_CATALOG_BYTES,
      ), 'abilities', ability.id);
    return bundleAnswerResult(
      request,
      answerAbilityInfo(request, ability, value, bundleVersion),
      bundleVersion,
    );
  }
  if (move && moveInfoIntent.test(request.question) && bundleVersion >= 20 && referenceConfig) {
    const value = await readReferenceEntityShard(
      bucket, manifest.cdnPrefix as string, 'move', move, referenceConfig,
    );
    return bundleAnswerResult(
      request,
      answerMoveInfo(request, move, value, bundleVersion),
      bundleVersion,
    );
  }
  return null;
}

/**
 * Resolve fuzzy visual/type descriptions to bounded, stable species choices.
 * This never selects an entity for the user: catalog metadata only narrows the
 * list rendered as explicit confirmation chips in the App.
 */
export async function resolveDexBundleClarificationCandidates(
  request: AssistantRequest,
  bucket: R2Bucket | undefined,
): Promise<ClarificationCandidate[]> {
  if (!bucket || isGeneralPokemonFranchiseRequest(request)) return [];
  const question = request.question.trim();
  const groupMatches = fuzzySpeciesGroups.filter(({ pattern }) => pattern.test(question));
  const allowedGroupIds = groupMatches.length === 0
    ? null
    : new Set(groupMatches.flatMap(({ ids }) => [...ids]));
  const colors = fuzzyColorPatterns.flatMap(([color, pattern]) =>
    pattern.test(question) ? [color] : []
  );
  const types = fuzzyTypePatterns.flatMap(([type, pattern]) =>
    pattern.test(question) ? [type] : []
  );
  const shapeSlugs = fuzzyShapeSlugs(question);
  const asksSmall = /(?:小只|小个|很小|小小|小狗|小猫)/u.test(question);
  const asksLarge = /(?:巨大|很大|大只|大个)/u.test(question);
  if (
    allowedGroupIds === null &&
    colors.length === 0 &&
    types.length === 0 &&
    shapeSlugs.length === 0 &&
    !asksSmall &&
    !asksLarge
  ) {
    return [];
  }

  const manifest = await readJsonObject(bucket, 'bundle-manifest.json', MAX_MANIFEST_BYTES);
  if (!validBundleManifest(manifest)) return [];
  const catalog = await readJsonObject(
    bucket,
    `${manifest.cdnPrefix}/dex_catalog.json`,
    MAX_CATALOG_BYTES,
  );
  if (!catalog || !Array.isArray(catalog.summaries) || catalog.summaries.length > 2_000) {
    return [];
  }
  const regionalKeys = regionalDexKeys[request.context.game] ?? [];
  const ranked = catalog.summaries.flatMap((value) => {
    if (!isPlainObject(value) ||
        !Number.isInteger(value.id) ||
        (value.id as number) < 1 ||
        (value.id as number) > 10_000 ||
        typeof value.nameZh !== 'string' ||
        value.nameZh.trim().length === 0 ||
        value.nameZh.length > 80 ||
        !Array.isArray(value.types) ||
        value.types.some((type) => typeof type !== 'string')) {
      return [];
    }
    const id = value.id as number;
    const candidateTypes = value.types as string[];
    const generation = Number.isInteger(value.generation)
      ? value.generation as number
      : null;
    if (request.context.generation > 0 && generation !== null &&
        generation > request.context.generation) return [];
    if (allowedGroupIds && !allowedGroupIds.has(id)) return [];
    if (types.length > 0 && !types.every((type) => candidateTypes.includes(type))) return [];
    if (colors.length > 0 &&
        (typeof value.colorSlug !== 'string' || !colors.includes(value.colorSlug))) {
      return [];
    }
    if (shapeSlugs.length > 0 &&
        (typeof value.shapeSlug !== 'string' || !shapeSlugs.includes(value.shapeSlug))) {
      return [];
    }

    const height = typeof value.heightDm === 'number' && Number.isFinite(value.heightDm)
      ? value.heightDm
      : null;
    const pokedexNumbers = isPlainObject(value.pokedexNumbers)
      ? value.pokedexNumbers
      : null;
    const regional = pokedexNumbers !== null && regionalKeys.some((key) =>
      Number.isInteger(pokedexNumbers[key])
    );
    let score = 0;
    if (allowedGroupIds) score += 12;
    score += types.length * 8;
    if (colors.length > 0) score += 6;
    if (shapeSlugs.length > 0) score += 5;
    if (regional) score += 3;
    if (asksSmall && height !== null && height <= 10) score += 3;
    if (asksLarge && height !== null && height >= 20) score += 3;
    return [{
      id,
      nameZh: value.nameZh.trim(),
      score,
      height: height ?? Number.POSITIVE_INFINITY,
    }];
  }).sort((left, right) =>
    right.score - left.score || left.height - right.height || left.id - right.id
  );

  return ranked.slice(0, MAX_CLARIFICATION_CANDIDATES).map((candidate) => ({
    id: `pokemon-${candidate.id}`,
    label: candidate.nameZh,
    kind: 'pokemon',
  }));
}

function fuzzyShapeSlugs(question: string): string[] {
  if (/(?:鱼|鲨)/u.test(question)) return ['fish'];
  if (/(?:蛇|鳗|细长|长条)/u.test(question)) return ['squiggle'];
  if (/(?:鸟|鹰|雕|鸽|有翅膀)/u.test(question)) return ['wings'];
  if (/(?:虫|昆虫)/u.test(question)) return ['bug-wings', 'armor', 'legs'];
  return [];
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
  if (!bucket || isGeneralPokemonFranchiseRequest(request)) return [];
  request = conversationRetrievalRequest(request);
  const species = findTarget(request.question, speciesTargets);
  const item = findTarget(request.question, itemTargets);
  const move = findTarget(request.question, moveTargets);
  const ability = findTarget(request.question, abilityTargets);
  if (!species && !item && !move && !ability) return [];
  const manifest = await readJsonObject(bucket, 'bundle-manifest.json', MAX_MANIFEST_BYTES);
  if (!validBundleManifest(manifest)) return [];
  const bundleVersion = manifest.bundleVersion as number;
  const prefix = manifest.cdnPrefix as string;
  // V19 has only a general aggregate move table. Preserve the exact-version
  // PokéAPI path there; V20's bounded reference shard may be used as explicit
  // general evidence with the existing version warning.
  if (move && moveInfoIntent.test(request.question) && bundleVersion < 20) return [];
  const referenceConfig = bundleVersion >= 20
    ? validReferenceDataConfig(manifest.referenceData, manifest.referenceDataSourceCommit)
    : null;
  const facts: Record<string, unknown> = {
    sourceBundleVersion: bundleVersion,
    exactGame: request.context.game === 'general' ? false : request.context.game,
  };

  if (species) {
    const [detail, gameplayShard] = await Promise.all([
      readJsonObject(bucket, `${prefix}/details/${species.id}.json`, MAX_DETAIL_BYTES),
      bundleVersion >= 20 && request.context.game !== 'general'
        ? readGameplaySpeciesShard(bucket, prefix, species.id)
        : Promise.resolve(null),
    ]);
    if (detail && isPlainObject(detail.summary) && detail.summary.id === species.id) {
      facts.species = compactSpeciesEvidence(
        detail,
        species,
        request.context.game,
        gameplayShard,
        /(?:配招|(?:招式|技能).{0,16}(?:适合|推荐|选择|哪些|什么|怎么|搭配|好用))/u
          .test(request.question),
      );
    }
  }
  if (item) {
    const value = bundleVersion >= 20
      ? referenceConfig
        ? await readReferenceEntityShard(bucket, prefix, 'item', item, referenceConfig)
        : null
      : recordFromAggregate(await readJsonObject(bucket, `${prefix}/items.json`, MAX_ITEMS_BYTES), item.id);
    if (value) {
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
    const value = bundleVersion >= 20
      ? referenceConfig
        ? await readReferenceEntityShard(bucket, prefix, 'move', move, referenceConfig)
        : null
      : recordFromAggregate(await readJsonObject(bucket, `${prefix}/moves.json`, MAX_MOVES_BYTES), move.id);
    if (value) {
      facts.move = compactMoveEvidence(value, move);
    }
  }
  if (ability) {
    const value = bundleVersion >= 20 && referenceConfig
      ? await readReferenceEntityShard(bucket, prefix, 'ability', ability, referenceConfig)
      : null;
    facts.ability = value
      ? {
        id: ability.id,
        nameZh: ability.nameZh,
        ...(typeof value.descriptionZh === 'string'
          ? { descriptionZh: cleanText(value.descriptionZh, 240) }
          : {}),
      }
      : { id: ability.id, nameZh: ability.nameZh };
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

  const weekdayOnly = /(?:星期几|周几|哪天|哪一天|\b(?:what|which) day(?: of the week)?\b|\bweekday\b)/iu.test(request.question) &&
    !needsExpandedAnswer(request.question);
  const relevantEntries = weekdayOnly
    ? entries.filter((entry) => entry.conditions.some((condition) => /^weekday-(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)$/u.test(condition)))
    : entries;
  if (weekdayOnly && relevantEntries.length === 0) return bundleResponse(
    request,
    `《宝可梦 ${gameLabels[request.context.game]}》已收录的${target.nameZh}地点资料没有明确的星期记录，暂时不能据此判断应该周几前往，也不能认定每天都能遇到。`,
    bundleVersion, `encounter-${request.context.game}-${target.id}`,
    [`species:${target.id}`, `game:${request.context.game}`], 'low',
    ['当前地点记录未提供星期条件，需要进一步核对。'],
  );
  const grouped = groupEncounters(relevantEntries, weekdayOnly).slice(0, MAX_AREAS);
  if (grouped.length === 0) return null;
  const remainingAreas = Math.max(0, new Set(relevantEntries.map((entry) => entry.areaSlug)).size - grouped.length);
  const lines = grouped.map((group) =>
    `- ${group.label}：${group.details.join('；')}`,
  );
  const extra = remainingAreas > 0
    ? `\n此外还有 ${remainingAreas} 个地点记录；可以补充“前期／固定点／团体战”等条件继续缩小。`
    : '';
  const answer = [
    weekdayOnly
      ? `《宝可梦 ${gameLabels[request.context.game]}》中，${target.nameZh}有明确星期限制的地点记录如下：`
      : `《宝可梦 ${gameLabels[request.context.game]}》已收录的资料记录到${target.nameZh}可在以下地点获得：`,
    lines.join('\n'),
    extra.trim(),
  ].filter(Boolean).join('\n\n').slice(0, MAX_ANSWER_LENGTH);

  return bundleResponse(
    request,
    answer,
    bundleVersion,
    `encounter-${request.context.game}-${target.id}`,
    [`species:${target.id}`, `game:${request.context.game}`],
    !weekdayOnly && relevantEntries.some((entry) => hasMergedEncounterConditions(entry.conditions)) ? 'medium' : 'high',
    !weekdayOnly && relevantEntries.some((entry) => hasMergedEncounterConditions(entry.conditions))
      ? ['部分地点把不同遭遇合并记录，具体等级与遭遇条件对应关系未收录；需继续核对。'] : [],
  );
}

export function questionMentionsKnownEntity(question: string): boolean {
  return [speciesTargets, moveTargets, itemTargets, abilityTargets]
    .some((targets) => findTarget(question, targets) !== null);
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
  itemBySlug: HeldItemLookup | null,
  bundleVersion: number,
): AssistantResponse | null {
  if (!Array.isArray(detail.heldItems) || !itemBySlug) return null;
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
    ['携带物批次包含 PokeAPI 与 52Poké 数据；52Poké 部分按 CC BY-NC-SA 3.0 署名使用。'],
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
  if (methods.length === 0) return bundleResponse(
    request,
    `《宝可梦 ${gameLabels[request.context.game]}》的已收录招式表中，没有${species.nameZh}学习${move.nameZh}的记录；这项查询只覆盖当前版本的学习表，不包含未收录的活动或特殊来源。`,
    bundleVersion, `move-learning-${request.context.game}-${species.id}-${move.id}`,
    [`species:${species.id}`, `move:${move.id}`, `game:${request.context.game}`],
  );
  return bundleResponse(
    request,
    `《宝可梦 ${gameLabels[request.context.game]}》的招式表记录：${species.nameZh}可通过${methods.join('；')}学会${move.nameZh}。`,
    bundleVersion,
    `move-learning-${request.context.game}-${species.id}-${move.id}`,
    [`species:${species.id}`, `move:${move.id}`, `game:${request.context.game}`],
    'high',
    methods.includes('招式学习器')
      ? ['当前学习表只确认学习方式，未收录该版本招式学习器的编号与获取地点；这些细节需要继续核对。']
      : [],
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
  value: Record<string, unknown> | null,
  bundleVersion: number,
): AssistantResponse | null {
  if (!value) return null;
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
  value: Record<string, unknown> | null,
  bundleVersion: number,
): AssistantResponse | null {
  if (!value || (value.id !== undefined && value.id !== ability.id)) return null;
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

function answerMoveInfo(
  request: AssistantRequest,
  move: EntityTarget,
  value: Record<string, unknown> | null,
  bundleVersion: number,
): AssistantResponse | null {
  if (!value) return null;
  const details: string[] = [];
  if (typeof value.typeZh === 'string') details.push(`属性：${cleanText(value.typeZh, 40)}`);
  if (typeof value.categoryZh === 'string') details.push(`分类：${cleanText(value.categoryZh, 40)}`);
  if (typeof value.power === 'number') details.push(`威力：${value.power}`);
  if (typeof value.accuracy === 'number') details.push(`命中：${value.accuracy}`);
  if (typeof value.pp === 'number') details.push(`PP：${value.pp}`);
  const description = typeof value.descriptionZh === 'string'
    ? cleanText(value.descriptionZh, 240)
    : '';
  if (description) details.push(`说明：${description}`);
  if (details.length === 0) return null;
  return bundleResponse(
    request,
    `TitoDex v${bundleVersion} 的${move.nameZh}招式资料：\n${details.map((line) => `- ${line}`).join('\n')}`,
    bundleVersion,
    `move-${move.id}`,
    [`move:${move.id}`],
    'medium',
    ['这是 bundle 的通用招式值；旧世代数值变化需再按版本核对。'],
  );
}

function bundleAnswerResult(
  request: AssistantRequest,
  response: AssistantResponse | null,
  bundleVersion: number,
): DexBundleAnswerResult | null {
  if (!response || !response.answer) return null;
  const missingMachineDetails = response.matchedHintIds?.some((id) => id.includes('move-learning-')) &&
    response.answer.includes('招式学习器') &&
    /(?:怎么|怎样|如何|方法|几号|编号|哪里|哪儿|获取|获得|\bhow\b|\bwhere\b|\bwhich\b)/iu.test(request.question);
  const missingEncounterAssociations = response.unknowns?.some((note) => note.includes('遭遇条件对应关系')) ?? false;
  const missingEncounterWeekday = response.unknowns?.some((note) => note.includes('未提供星期条件')) ?? false;
  const coversQuestion = !needsExpandedAnswer(request.question) && !missingMachineDetails &&
    !missingEncounterAssociations && !missingEncounterWeekday;
  const source: CuratedSource = {
    id: `dex-bundle-v${bundleVersion}`,
    title: `TitoDex Dex bundle v${bundleVersion} · 本地结构化底稿`,
    text: JSON.stringify({
      exactGame: request.context.game === 'general' ? false : request.context.game,
      answer: response.answer,
      verifiedFacts: response.verifiedFacts ?? [],
      unknowns: response.unknowns ?? [],
    }).slice(0, 6_000),
  };
  return {
    response: {
      ...response,
      evidence: response.evidence ?? {
        basis: 'structured',
        scope: request.context.game !== 'general' && response.confidence === 'high' ? 'game' : 'general',
        complete: coversQuestion,
        bundleVersion,
        entityIds: mentionedEntities(response.answer).map((entity) => `${entity.kind}:${entity.id}`),
      },
    },
    localSource: source,
    coversQuestion,
    // V20 reference/gameplay projections declare online-verify provenance.
    // They remain the deterministic offline fallback, but an online-capable
    // request must continue through the allowlisted corroboration pipeline.
    requiresOnlineVerification: bundleVersion >= 20 || !coversQuestion,
  };
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
  moveAdvice = false,
): Record<string, unknown> {
  const summary = isPlainObject(detail.summary) ? detail.summary : {};
  const evidence: Record<string, unknown> = {
    id: species.id,
    nameZh: species.nameZh,
    ...(game === 'general' ? { scope: 'general' } : { versionedFor: game }),
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
  if (game !== 'general' && Array.isArray(rawEncounters)) {
    evidence.encounters = rawEncounters
      .flatMap((value) => {
        const encounter = Array.isArray(shardEncounters)
          ? parseGameplayEncounter(value)
          : parseEncounter(value);
        return encounter ? [{
          area: normalizeFullWidth(encounter.areaLabelZh),
          methods: encounter.methods.slice(0, 4),
          conditions: encounter.conditions,
          conditionsZh: encounter.conditions.map(encounterConditionLabel),
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
  if (game !== 'general' && isPlainObject(rawMoveSet)) {
    const set = rawMoveSet;
    const compactRows = usingShardMoveSet ? compactGameplayMoveRows : compactMoveRows;
    evidence.moveSet = moveAdvice
      ? {
          learnable: compactMoveAdviceRows(set, compactRows),
          truncated: true,
        }
      : {
          levelUp: compactRows(set.levelUp, 24, true),
          machine: compactRows(set.machine, 24, false),
          egg: compactRows(set.egg, 16, false),
          tutor: compactRows(set.tutor, 16, false),
          truncated: true,
        };
  }
  if (isPlainObject(detail.evolutionChain)) {
    const edges = collectEvolutionEdges(detail.evolutionChain);
    evidence.evolutionChain = {
      scope: 'general', exactGameApplicability: 'unknown', truncated: edges.length > 32,
      edges: edges.slice(0, 32).flatMap((edge) => {
        const from = entityName('pokemon', edge.fromId), to = entityName('pokemon', edge.toId);
        return from && to ? [{ fromStableId: `pokemon:${edge.fromId}`, fromNameZh: from,
          toStableId: `pokemon:${edge.toId}`, toNameZh: to }] : [];
      }),
    };
  }
  if (game !== 'general' && gameplayShard && gameplayShard.evolutions.length > 0) {
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
  } else if (game !== 'general' && isPlainObject(detail.evolutionChain)) {
    evidence.adjacentEvolution = collectEvolutionEdges(detail.evolutionChain)
      .filter((edge) => edge.fromId === species.id || edge.toId === species.id)
      .slice(0, 6)
      .map((edge) => ({
        from: edge.fromName,
        to: edge.toName,
        conditions: describeEvolutionTriggers(edge.triggers),
      }));
  }
  evidence.scopeNote = game === 'general'
    ? 'General reference fields only; no selected-game encounters, learnsets or evolution conditions.'
    : gameplayShard
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
    const nameEn = target.aliases.find((alias) => !/[\u3400-\u9fff]/u.test(alias));
    return [{
      id,
      nameZh: target.nameZh,
      ...(nameEn ? { nameEn } : {}),
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
    const nameEn = target.aliases.find((alias) => !/[\u3400-\u9fff]/u.test(alias));
    return [{
      id: target.id,
      nameZh: target.nameZh,
      ...(nameEn ? { nameEn } : {}),
      ...(includeLevel && validLevel(entry.level) ? { level: entry.level } : {}),
    }];
  }).slice(0, maximum);
}

function compactMoveAdviceRows(
  set: Record<string, unknown>,
  compactRows: (value: unknown, maximum: number, includeLevel: boolean) => unknown[],
): Record<string, string>[] {
  const seen = new Set<string>();
  return ['levelUp', 'egg', 'tutor', 'machine'].flatMap((method) =>
    compactRows(set[method], 256, method === 'levelUp'))
    .flatMap((row) => {
      if (!isPlainObject(row) || typeof row.nameZh !== 'string') return [];
      const normalized = normalize(row.nameZh);
      if (!normalized || seen.has(normalized)) return [];
      seen.add(normalized);
      return [{
        nameZh: row.nameZh,
        ...(typeof row.nameEn === 'string' ? { nameEn: row.nameEn } : {}),
      }];
    })
    .slice(0, 80);
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
    if (edges.length >= 40) return;
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

function groupEncounters(entries: EncounterEntry[], conditionsOnly = false): { label: string; details: string[] }[] {
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
    const detail = conditionsOnly
      ? Array.from(new Set((hasMergedEncounterConditions(entry.conditions)
        ? entry.conditions.filter((condition) => condition.startsWith('weekday-'))
        : entry.conditions).map(encounterConditionLabel))).join('，')
      : describeEncounter(entry);
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
    ...(hasMergedEncounterConditions(entry.conditions)
      ? ['包含不同条件的合并记录，不能把下列条件当作同时要求',
        `记录涉及：${Array.from(new Set(entry.conditions.map(encounterConditionLabel))).join('／')}`]
      : entry.conditions.map(encounterConditionLabel)),
  ].filter(Boolean);
  return [methods, level, ...tags].filter(Boolean).join('，');
}

function hasMergedEncounterConditions(conditions: string[]): boolean {
  const groups = new Set<string>();
  for (const condition of new Set(conditions)) {
    const group = /^(time|weather|season|weekday|swarm|radar|radio|slot2|backlot)-/u.exec(condition)?.[1]
      ?? (/^johto-safari-blocks-(?:forest|peak|plains|water)-min-/u.exec(condition)?.[0]);
    if (group && groups.has(group)) return true;
    if (group) groups.add(group);
  }
  return conditions.includes('johto-safari-blocks-inactive') &&
    conditions.some((condition) => /^johto-safari-blocks-.*-min-/u.test(condition));
}

function encounterConditionLabel(slug: string): string {
  // Same condition vocabulary as Flutter's dex_encounter_labels.dart.
  const labels: Record<string, string> = {
    'time-day': '白天', 'time-morning': '早晨', 'time-night': '夜晚',
    'weather-normal': '普通天气', 'weather-overcast': '阴天',
    'weather-raining': '下雨', 'weather-thunderstorm': '雷雨',
    'weather-intense-sun': '烈日', 'weather-sandstorm': '沙暴',
    'weather-fog': '雾天', 'weather-snowing': '下雪', 'weather-snowstorm': '暴雪',
    'season-spring': '春季', 'season-summer': '夏季', 'season-autumn': '秋季', 'season-winter': '冬季',
    'swarm-yes': '大量出现时', 'swarm-no': '非大量出现',
    'radar-on': '使用宝可追踪', 'radar-off': '不使用宝可追踪',
    roaming: '地图游走',
    'bug-catching-contest-yes': '捕虫大赛期间', 'bug-catching-contest-no': '非捕虫大赛',
    'backlot-mentioned': '豪宅主人提及时', 'backlot-not-mentioned': '豪宅主人未提及',
    'radio-hoenn': '播放丰缘之声', 'radio-sinnoh': '播放神奥之声', 'radio-off': '未播放宝可梦音乐',
    'headbutt-tree-common': '普通撞树点', 'headbutt-tree-rare': '稀有撞树点', 'headbutt-tree-secret': '隐藏撞树点',
    'honey-tree-group-a': '甜甜蜜树 A 组', 'honey-tree-group-b': '甜甜蜜树 B 组', 'honey-tree-group-c': '甜甜蜜树 C 组',
    'slot2-none': '无需插入 GBA 卡带', 'defeated-ghetsis': '击败魁奇思后',
    'first-party-pokemon-high-friendship': '队首宝可梦高亲密度',
    'special-encounter-couldnt-capture-before': '此前未能捕获时',
    'trash-can-type-daily': '每日垃圾桶', 'trash-can-type-thursday': '周四垃圾桶',
    'tv-option-blue': '电视选择蓝色', 'tv-option-red': '电视选择红色',
    'max-den-rarity-common': '普通巢穴', 'max-den-rarity-rare': '稀有巢穴', 'max-den-rarity-special': '特殊巢穴',
    'johto-safari-blocks-inactive': '狩猎地带摆设未生效',
  };
  if (labels[slug]) return labels[slug];
  const weekdays: Record<string, string> = {
    monday: '周一', tuesday: '周二', wednesday: '周三', thursday: '周四',
    friday: '周五', saturday: '周六', sunday: '周日',
  };
  if (slug.startsWith('weekday-') && weekdays[slug.slice(8)]) return weekdays[slug.slice(8)];
  const safari = /^johto-safari-blocks-(forest|peak|plains|water)-min-(\d+)$/u.exec(slug);
  if (safari) {
    const decorations: Record<string, string> = { forest: '森林', peak: '山峰', plains: '草原', water: '水边' };
    return `狩猎地带：${decorations[safari[1]]}摆设≥${safari[2]}`;
  }
  const rating = /^max-den-rating-(\d)-star$/u.exec(slug);
  if (rating) return `${rating[1]}★巢穴`;
  const friend = /^friend-safari-slot-(\d)$/u.exec(slug);
  if (friend) return `朋友狩猎第${friend[1]}栏`;
  const coins = /^coins-(\d+)$/u.exec(slug);
  if (coins) return `需要${coins[1]}枚代币`;
  const diglett = /^alolan-diglett-found-(\d+)$/u.exec(slug);
  if (diglett) return `找到${diglett[1]}只阿罗拉地鼠`;
  const prefixes: Record<string, string> = {
    'slot2-': '插入指定 GBA 卡带', 'great-marsh-daily-slot-': '大湿地每日轮换',
    'berry-tree-type-': '指定颜色树果树', 'item-': '持有指定关键道具',
    'trade-': '完成指定 NPC 交换', 'starter-': '选择指定初始宝可梦',
    'save-data-from-': '拥有对应游戏存档联动', 'story-progress-': '达到指定剧情进度',
    'other-': '满足特殊剧情条件',
  };
  for (const [prefix, label] of Object.entries(prefixes)) if (slug.startsWith(prefix)) return label;
  return '特殊出现条件';
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

function validReferenceDataConfig(
  value: unknown,
  sourceCommit: unknown,
): ReferenceDataConfig | null {
  if (!isPlainObject(value) || !hasExactKeys(value, [
    'schemaVersion', 'maximumShardBytes', 'moves', 'abilities', 'items',
    'itemSlugIndex', 'audit', 'counts',
  ]) || value.schemaVersion !== 1 || value.maximumShardBytes !== MAX_REFERENCE_SHARD_BYTES ||
      value.moves !== 'reference/moves/{id}.json' ||
      value.abilities !== 'reference/abilities/{id}.json' ||
      value.items !== 'reference/items/{id}.json' ||
      value.itemSlugIndex !== 'reference/item-slug-index/{bucket}.json' ||
      value.audit !== 'reference/reference_shards_audit.json' ||
      !isPlainObject(value.counts) || !hasExactKeys(value.counts, [
        'moves', 'abilities', 'items', 'itemSlugIndexBuckets',
      ]) || !validCount(value.counts.moves, 1, 10_000) ||
      !validCount(value.counts.abilities, 1, 10_000) ||
      !validCount(value.counts.items, 1, 20_000) ||
      value.counts.itemSlugIndexBuckets !== 256 || !validSourceCommit(sourceCommit)) {
    return null;
  }
  return {
    moves: value.moves,
    abilities: value.abilities,
    items: value.items,
    itemSlugIndex: value.itemSlugIndex,
    sourceCommit: sourceCommit as string,
  };
}

function validCount(value: unknown, minimum: number, maximum: number): value is number {
  return typeof value === 'number' && Number.isInteger(value) && value >= minimum && value <= maximum;
}

async function readReferenceEntityShard(
  bucket: R2Bucket,
  prefix: string,
  kind: 'move' | 'ability' | 'item',
  target: EntityTarget,
  config: ReferenceDataConfig,
): Promise<Record<string, unknown> | null> {
  const pattern = kind === 'move' ? config.moves : kind === 'ability' ? config.abilities : config.items;
  const value = await readJsonObject(
    bucket,
    `${prefix}/${pattern.replace('{id}', String(target.id))}`,
    MAX_REFERENCE_SHARD_BYTES,
  );
  return validReferenceEntityShard(value, kind, target, config.sourceCommit) ? value : null;
}

function validReferenceEntityShard(
  value: Record<string, unknown> | null,
  kind: 'move' | 'ability' | 'item',
  target: EntityTarget,
  sourceCommit: string,
): boolean {
  if (!value || value.schemaVersion !== 1 || value.kind !== kind || value.id !== target.id ||
      value.sourceCommit !== sourceCommit || !validSourceCommit(value.sourceCommit) ||
      typeof value.slug !== 'string' || !/^[a-z0-9][a-z0-9-]{0,159}$/u.test(value.slug) ||
      typeof value.nameZh !== 'string' || !validReferenceText(value.nameZh, 120) ||
      normalize(value.nameZh) !== normalize(target.nameZh) ||
      !validNullableText(value.nameEn, 120)) return false;
  if (kind === 'move') {
    return hasExactKeys(value, [
      'schemaVersion', 'kind', 'id', 'stableId', 'sourceCommit', 'sourceStatus', 'slug', 'nameZh', 'nameEn',
      'type', 'typeZh', 'category', 'categoryZh', 'power', 'accuracy', 'pp', 'priority',
      'target', 'targetZh', 'generation', 'descriptionZh', 'shortEffect', 'availableVersionGroups',
    ]) && validReferenceSourceStatus(value.sourceStatus) && value.stableId === `move:${target.id}` &&
      [value.type, value.typeZh, value.category, value.categoryZh].every((entry) => validNullableText(entry, 40)) &&
      [value.target, value.targetZh].every((entry) => validNullableText(entry, 80)) &&
      [value.power, value.accuracy, value.pp].every((entry) => validNullableInteger(entry, 0, 100_000)) &&
      validNullableInteger(value.priority, -20, 20) && validNullableInteger(value.generation, 1, 99) &&
      validNullableText(value.descriptionZh, 1_200) && validNullableText(value.shortEffect, 1_200) &&
      validReferenceStringArray(value.availableVersionGroups, 64, 120);
  }
  if (kind === 'ability') {
    return hasExactKeys(value, [
      'schemaVersion', 'kind', 'id', 'stableId', 'sourceCommit', 'sourceStatus', 'slug', 'nameZh', 'nameEn',
      'generation', 'descriptionZh', 'shortEffect',
    ]) && validReferenceSourceStatus(value.sourceStatus) && value.stableId === `ability:${target.id}` &&
      validNullableInteger(value.generation, 1, 99) &&
      validNullableText(value.descriptionZh, 1_200) && validNullableText(value.shortEffect, 1_200);
  }
  return hasExactKeys(value, [
    'schemaVersion', 'kind', 'id', 'stableId', 'sourceCommit', 'sourceStatus', 'slug', 'nameZh', 'nameEn',
    'categoryZh', 'cost', 'descriptionZh', 'effectZh', 'flingPower', 'availableVersionGroups',
    'availableGenerations', 'pricesByVersionGroup',
  ]) && validReferenceSourceStatus(value.sourceStatus) && value.stableId === `item:${value.slug}` &&
    validNullableText(value.categoryZh, 80) && validNullableInteger(value.cost, 0, 1_000_000_000) &&
    validNullableText(value.descriptionZh, 1_200) && validNullableText(value.effectZh, 1_200) &&
    validNullableInteger(value.flingPower, 0, 100_000) &&
    validReferenceStringArray(value.availableVersionGroups, 64, 120) &&
    Array.isArray(value.availableGenerations) && value.availableGenerations.length <= 32 &&
    value.availableGenerations.every((entry) => validCount(entry, 1, 99)) &&
    validReferencePrices(value.pricesByVersionGroup);
}

function validReferenceSourceStatus(value: unknown): boolean {
  return value === 'pinned-pokeapi' || value === 'retained-v19';
}

function validReferenceText(value: unknown, maximum: number): value is string {
  return typeof value === 'string' && value.length > 0 && value.length <= maximum;
}

function validNullableText(value: unknown, maximum: number): boolean {
  return value === null || validReferenceText(value, maximum);
}

function validNullableInteger(value: unknown, minimum: number, maximum: number): boolean {
  return value === null || validCount(value, minimum, maximum);
}

function validReferenceStringArray(value: unknown, maximum: number, maximumLength: number): boolean {
  return Array.isArray(value) && value.length <= maximum && value.every((entry) =>
    typeof entry === 'string' && entry.length > 0 && entry.length <= maximumLength,
  );
}

function validReferencePrices(value: unknown): boolean {
  if (!isPlainObject(value) || Object.keys(value).length > 64) return false;
  return Object.entries(value).every(([group, row]) =>
    /^[a-z0-9-]{1,80}$/u.test(group) && isPlainObject(row) &&
    Object.keys(row).length > 0 && Object.keys(row).every((key) => key === 'buy' || key === 'sell') &&
    Object.values(row).every((entry) => validCount(entry, 0, 1_000_000_000)),
  );
}

function recordFromAggregate(
  aggregate: Record<string, unknown> | null,
  id: number,
): Record<string, unknown> | null {
  return aggregate && isPlainObject(aggregate[String(id)])
    ? aggregate[String(id)] as Record<string, unknown>
    : null;
}

function recordFromCatalog(
  catalog: Record<string, unknown> | null,
  collection: string,
  id: number,
): Record<string, unknown> | null {
  return catalog && isPlainObject(catalog[collection]) &&
    isPlainObject((catalog[collection] as Record<string, unknown>)[String(id)])
    ? (catalog[collection] as Record<string, unknown>)[String(id)] as Record<string, unknown>
    : null;
}

function itemLookupFromAggregate(items: Record<string, unknown> | null): HeldItemLookup | null {
  if (!items) return null;
  const result: HeldItemLookup = new Map();
  for (const [id, value] of Object.entries(items)) {
    if (!isPlainObject(value) || typeof value.slug !== 'string' ||
        typeof value.nameZh !== 'string' || !/^\d{1,5}$/.test(id)) continue;
    result.set(value.slug, { id: Number(id), name: cleanText(value.nameZh, 80) });
  }
  return result;
}

async function readHeldItemLookup(
  bucket: R2Bucket,
  prefix: string,
  detail: Record<string, unknown>,
  config: ReferenceDataConfig,
): Promise<HeldItemLookup | null> {
  if (!Array.isArray(detail.heldItems)) return null;
  const slugs = Array.from(new Set(detail.heldItems.flatMap((row) =>
    isPlainObject(row) && typeof row.slug === 'string' &&
    /^[a-z0-9][a-z0-9-]{0,159}$/u.test(row.slug) ? [row.slug] : [],
  ))).slice(0, 8);
  if (slugs.length === 0) return null;
  const buckets = new Map<string, string[]>();
  for (const slug of slugs) {
    const key = await itemSlugBucket(slug);
    buckets.set(key, [...(buckets.get(key) ?? []), slug]);
  }
  const result: HeldItemLookup = new Map();
  await Promise.all([...buckets.entries()].map(async ([bucketKey, requested]) => {
    const value = await readJsonObject(
      bucket,
      `${prefix}/${config.itemSlugIndex.replace('{bucket}', bucketKey)}`,
      MAX_REFERENCE_SHARD_BYTES,
    );
    if (!validItemSlugIndex(value, bucketKey)) return;
    for (const slug of requested) {
      const row = value.entries[slug];
      if (isPlainObject(row)) {
        const target = itemTargets.find((candidate) => candidate.id === row.id);
        if (target && normalize(target.nameZh) === normalize(row.nameZh as string)) {
          result.set(slug, { id: target.id, name: target.nameZh });
        }
      }
    }
  }));
  return result.size > 0 ? result : null;
}

async function itemSlugBucket(slug: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(slug));
  return Array.from(new Uint8Array(digest).slice(0, 1), (value) =>
    value.toString(16).padStart(2, '0'),
  ).join('');
}

function validItemSlugIndex(
  value: Record<string, unknown> | null,
  bucket: string,
): value is Record<string, unknown> & { entries: Record<string, unknown> } {
  return value !== null && hasExactKeys(value, ['schemaVersion', 'kind', 'bucket', 'entries']) &&
    value.schemaVersion === 1 && value.kind === 'item-slug-index' && value.bucket === bucket &&
    isPlainObject(value.entries) && Object.keys(value.entries).length <= 64 &&
    Object.entries(value.entries).every(([slug, row]) =>
      /^[a-z0-9][a-z0-9-]{0,159}$/u.test(slug) && isPlainObject(row) &&
      hasExactKeys(row, ['id', 'nameZh']) && validCount(row.id, 1, 100_000) &&
      validReferenceText(row.nameZh, 120),
    );
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
