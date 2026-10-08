// TitoDex 数据工具：属性映射、筛选、格式化
const POKEMON_INDEX = require('../data/index.js');
const POKEMON_DETAILS = require('../data/details.js');

// 18 种属性：英文 slug -> 中文
const TYPE_ZH = {
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
  fairy: '妖精'
};

// 属性配色（按属性惯用色）
const TYPE_COLOR = {
  normal: '#A8A77A',
  fire: '#EE8130',
  water: '#6390F0',
  electric: '#D9A800',
  grass: '#7AC74C',
  ice: '#5FBFB4',
  fighting: '#C22E28',
  poison: '#A33EA1',
  ground: '#C99B4A',
  flying: '#A98FF3',
  psychic: '#F95587',
  bug: '#A6B91A',
  rock: '#B6A136',
  ghost: '#735797',
  dragon: '#6F35FC',
  dark: '#705746',
  steel: '#8E9BA8',
  fairy: '#D685AD'
};

const TYPE_ORDER = Object.keys(TYPE_ZH);

const GENERATIONS = [
  { gen: 1, label: '第一世代', region: '关都' },
  { gen: 2, label: '第二世代', region: '城都' },
  { gen: 3, label: '第三世代', region: '丰缘' },
  { gen: 4, label: '第四世代', region: '神奥' },
  { gen: 5, label: '第五世代', region: '合众' },
  { gen: 6, label: '第六世代', region: '卡洛斯' },
  { gen: 7, label: '第七世代', region: '阿罗拉' },
  { gen: 8, label: '第八世代', region: '伽勒尔' },
  { gen: 9, label: '第九世代', region: '帕底亚' }
];

const STAT_ZH = {
  hp: 'HP',
  attack: '攻击',
  defense: '防御',
  specialAttack: '特攻',
  specialDefense: '特防',
  speed: '速度'
};

const STAT_COLOR = {
  hp: '#FF5955',
  attack: '#F5AC78',
  defense: '#FAE078',
  specialAttack: '#9DB7F5',
  specialDefense: '#A7DB8D',
  speed: '#FA92B2'
};

const GROWTH_ZH = {
  "slow": "慢",
  "medium": "中等",
  "fast": "快",
  "medium-slow": "偏慢",
  "slow-then-very-fast": "先慢后快",
  "fast-then-very-slow": "先快后慢"
};

const ITEM_ZH = {
  "fire-stone": "火之石",
  "thunder-stone": "雷之石",
  "water-stone": "水之石",
  "leaf-stone": "叶之石",
  "ice-stone": "冰之石"
};

// 仅收录有把握的进化地点中文；未收录时显示原值，不猜测
const LOCATION_ZH = {
  "eterna-forest": "百代森林",
  "frost-cavern": "冰结洞窟",
  "kalos-route-20": "卡洛斯20号道路",
  "lush-jungle": "树荫丛林",
  "mount-lanakila": "拉纳基拉山",
  "petalburg-woods": "橙华森林",
  "pinwheel-forest": "矢车森林",
  "shoal-cave": "浅滩洞穴",
  "sinnoh-route-217": "神奥217号道路",
  "twist-mountain": "螺旋山"
};

const TIME_ZH = { day: '白天', night: '夜晚' };

const TYPE_MOVE_ZH = TYPE_ZH;

function padNo(id) {
  let s = String(id);
  while (s.length < 4) s = '0' + s;
  return s;
}

// 将 index 条目转为列表卡片展示结构
function decorate(item) {
  return {
    id: item.id,
    no: padNo(item.id),
    nameZh: item.nameZh,
    nameEn: item.nameEn,
    genusZh: item.genusZh,
    generation: item.generation,
    heightDm: item.heightDm,
    imageUrl: item.imageUrl,
    hasDetail: !!POKEMON_DETAILS[String(item.id)],
    types: (item.types || []).map(function (t) {
      return { slug: t, zh: TYPE_ZH[t] || t, color: TYPE_COLOR[t] || '#7b91a6' };
    })
  };
}

// 结构化进化条件 -> 中文（未知时显示原值，绝不猜测）
function triggerToZh(t) {
  if (!t || !t.trigger) return '';
  if (t.trigger === 'level-up') {
    const parts = [];
    if (t.minLevel) parts.push('等级达到 ' + t.minLevel);
    if (t.minHappiness) parts.push('亲密度达到 ' + t.minHappiness);
    if (t.minAffection) parts.push('友好度达到 ' + t.minAffection);
    if (t.timeOfDay && TIME_ZH[t.timeOfDay]) parts.push(TIME_ZH[t.timeOfDay]);
    if (t.location) {
      parts.push('在 ' + (LOCATION_ZH[t.location] || t.location));
    }
    if (t.knownMoveType) {
      parts.push('已学会 ' + (TYPE_MOVE_ZH[t.knownMoveType] || t.knownMoveType) + '属性招式');
    }
    if (parts.length === 0) return '升级';
    return parts.join('、') + ' 时升级';
  }
  if (t.trigger === 'use-item') {
    const item = t.item ? (ITEM_ZH[t.item] || t.item) : '';
    return item ? '使用 ' + item : '使用道具';
  }
  if (t.trigger === 'trade') return '通信交换';
  return '未知条件（' + t.trigger + '）';
}

// 进化链树 -> 扁平渲染数组：根节点 + 「条件 + 子节点」
function flattenChain(root) {
  const out = [];
  function walk(node, depth, conditionZh, parentName) {
    const idxItem = POKEMON_INDEX[node.id - 1];
    out.push({
      depth: depth,
      id: node.id,
      no: padNo(node.id),
      nameZh: node.nameZh,
      nameEn: node.nameEn,
      imageUrl: idxItem ? idxItem.imageUrl : '',
      conditionZh: conditionZh || '',
      parentName: parentName || ''
    });
    (node.children || []).forEach(function (c) {
      const conds = Array.from(new Set((c.triggers || []).map(triggerToZh).filter(Boolean)));
      const zh = conds.length ? conds.join(' 或 ') : (c.triggerZh || '条件未知');
      walk(c, depth + 1, zh, node.nameZh);
    });
  }
  walk(root, 0, '');
  return out;
}

// 编号解析：25 / 025 / #025 -> "25"；无法解析返回 null
function parseNo(text) {
  const m = String(text).trim().replace(/^#/, '');
  if (!/^\d+$/.test(m)) return null;
  return String(parseInt(m, 10));
}

// 搜索 + 世代 + 属性 交集筛选
function filterList(query, gen, typeSlug) {
  const q = String(query || '').trim().toLowerCase();
  const noQ = q ? parseNo(q) : null;
  return POKEMON_INDEX.filter(function (p) {
    if (gen && p.generation !== gen) return false;
    if (typeSlug && (p.types || []).indexOf(typeSlug) === -1) return false;
    if (!q) return true;
    if (p.nameZh.toLowerCase().indexOf(q) !== -1) return true;
    if (p.nameEn.toLowerCase().indexOf(q) !== -1) return true;
    if (noQ !== null && String(p.id) === noQ) return true;
    return false;
  });
}

function getIndex() {
  return POKEMON_INDEX;
}

function getDetail(id) {
  return POKEMON_DETAILS[String(id)] || null;
}

module.exports = {
  TYPE_ZH: TYPE_ZH,
  TYPE_COLOR: TYPE_COLOR,
  TYPE_ORDER: TYPE_ORDER,
  GENERATIONS: GENERATIONS,
  STAT_ZH: STAT_ZH,
  STAT_COLOR: STAT_COLOR,
  GROWTH_ZH: GROWTH_ZH,
  padNo: padNo,
  decorate: decorate,
  triggerToZh: triggerToZh,
  flattenChain: flattenChain,
  parseNo: parseNo,
  filterList: filterList,
  getIndex: getIndex,
  getDetail: getDetail
};
