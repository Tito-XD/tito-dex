/// Chinese names for games, locations, species, and related game text.
library;

const gameTitlesZh = <String, String>{
  'SoulSilver': '宝可梦 魂银',
  'HeartGold': '宝可梦 心金',
  'Platinum': '宝可梦 白金',
  'BlackWhite': '宝可梦 黑/白',
  'Black2White2': '宝可梦 黑2/白2',
  'XY': '宝可梦 X/Y',
  'ORAS': '宝可梦 ΩR/αS',
  'USUM': '宝可梦 究极日月',
};

const locationNamesZh = <String, String>{
  'Mystery Zone': '神秘区域',
  'New Bark Town': '若叶镇',
  'Cherrygrove City': '吉花市',
  'Violet City': '桔梗市',
  'Azalea Town': '桧皮镇',
  'Goldenrod City': '满金市',
  'Ecruteak City': '圆朱市',
  'Olivine City': '浅葱市',
  'Cianwood City': '湛蓝市',
  'Mahogany Town': '卡吉镇',
  'Blackthorn City': '烟墨市',
  'Pallet Town': '真新镇',
  'Viridian City': '常磐市',
  'Pewter City': '尼比市',
  'Cerulean City': '华蓝市',
  'Lavender Town': '紫苑镇',
  'Vermilion City': '枯叶市',
  'Celadon City': '彩虹市',
  'Fuchsia City': '浅红市',
  'Saffron City': '金黄市',
  'Cinnabar Island': '红莲镇',
  'Indigo Plateau': '石英联盟',
  'Mt. Silver': '白银山',
  'National Park': '自然公园',
  'Bellchime Trail': '铃铛小径',
  'Bell Tower': '铃铛塔',
  'Burned Tower': '烧焦塔',
  'Sprout Tower': '喇叭芽之塔',
  'Ruins of Alph': '阿露福遗迹',
  'Union Cave': '连接洞窟',
  'Slowpoke Well': '呆呆兽之井',
  'Ilex Forest': '栎树林',
  'Goldenrod Tunnel': '满金地下通道',
  'Radio Tower': '广播塔',
  'Mt. Mortar': '擂钵山',
  'Lake of Rage': '愤怒之湖',
  'Ice Path': '冰雪小径',
  'Whirl Islands': '涡旋岛',
  'Dragon\'s Den': '龙穴',
  'Tohjo Falls': '关都瀑布',
  'Victory Road': '冠军之路',
  'Safari Zone': '狩猎地带',
  'Safari Zone Gate': '狩猎地带入口',
  'Pokéathlon Dome': '宝可梦全能竞技场',
  'Battle Frontier': '对战开拓区',
  'Embedded Tower': '嵌入塔',
  'Cliff Edge Gate': '断崖门',
  'Route 27': '27号道路',
  'Route 26': '26号道路',
  'Route 28': '28号道路',
};

const interiorHintsZh = <String, String>{
  'Pokémon Center': '宝可梦中心',
  'Poké Mart': '友好商店',
  'Gym': '道馆',
  'Route': '道路',
  'Dungeon': '室内区域',
};

const speciesNamesZh = <String, String>{
  'Bulbasaur': '妙蛙种子',
  'Cyndaquil': '火球鼠',
  'Quilava': '火岩鼠',
  'Typhlosion': '火暴兽',
  'Pichu': '皮丘',
  'Togepi': '波克比',
  'Togetic': '波克基古',
  'Mareep': '咩利羊',
  'Flaaffy': '茸茸羊',
  'Ampharos': '电龙',
  'Abra': '凯西',
  'Drowzee': '催眠貘',
  'Riolu': '利欧路',
  'Lucario': '路卡利欧',
  'Hoothoot': '咕咕',
  'Jigglypuff': '胖丁',
  'Eevee': '伊布',
  'Pikachu': '皮卡丘',
};

const companionNamesZh = <String, String>{
  'Cyndaquil': '火球鼠',
  'Quilava': '火岩鼠',
  'Typhlosion': '火暴兽',
  'Chikorita': '菊草叶',
  'Totodile': '小锯鳄',
  'Riolu': '利欧路',
};

String localizeGame(String game) => gameTitlesZh[game] ?? game;

String localizeSpecies(String species) => speciesNamesZh[species] ?? species;

String localizeCompanion(String companion) =>
    companionNamesZh[companion] ?? companion;

String localizeLocation(String label) {
  if (label.startsWith('Map #')) {
    final id = label.replaceFirst('Map #', '');
    return '地图 #$id';
  }

  final parts = label.split(' · ');
  final place = _localizePlace(parts.first);
  if (parts.length == 1) {
    return place;
  }

  final hint = interiorHintsZh[parts[1]] ?? parts[1];
  return '$place · $hint';
}

String _localizePlace(String name) {
  if (locationNamesZh.containsKey(name)) {
    return locationNamesZh[name]!;
  }

  final routeMatch = RegExp(r'^Route (\d+)$').firstMatch(name);
  if (routeMatch != null) {
    return '${routeMatch.group(1)}号道路';
  }

  return name;
}

String localizeTimelineEntry(String text) {
  const map = <String, String>{
    'Loaded from local SoulSilver save': '已从本地魂银存档同步',
    'Reached Goldenrod City': '抵达满金市',
    'Won Hive Badge': '获得蜂巢徽章',
    'Added Riolu as companion': '利欧路加入同行',
    'Visit the Radio Tower when ready': '准备好就去广播塔看看',
    'Continue your Johto journey': '继续城都地区的旅程',
  };
  return map[text] ?? text;
}

String localizeReminder(String? reminder) {
  if (reminder == null) {
    return '';
  }
  return localizeTimelineEntry(reminder);
}

/// PokeAPI berry/flavor slug → Chinese taste label.
const flavorLabelsZh = <String, String>{
  'spicy': '辣',
  'dry': '涩',
  'sweet': '甜',
  'bitter': '苦',
  'sour': '酸',
};

/// Move damage class slug → Chinese.
const moveCategoryLabelsZh = <String, String>{
  'physical': '物理',
  'special': '特殊',
  'status': '变化',
};

/// CDN egg-group slug → Chinese label (matches detail `eggGroups` values).
const eggGroupLabelsZh = <String, String>{
  'monster': '怪兽',
  'water1': '水中1',
  'bug': '虫',
  'flying': '飞行',
  'ground': '陆上',
  'fairy': '妖精',
  'plant': '植物',
  'humanshape': '人形',
  'water3': '水中3',
  'mineral': '矿物',
  'indeterminate': '不定形',
  'water2': '水中2',
  'ditto': '百变怪',
  'dragon': '龙',
  'no-eggs': '未发现',
};

String? eggGroupSlugForLabelZh(String label) {
  for (final entry in eggGroupLabelsZh.entries) {
    if (entry.value == label) {
      return entry.key;
    }
  }
  return null;
}

/// CDN / PokeAPI item category slug → Chinese display label.
const itemCategoryLabelsZh = <String, String>{
  'standard-balls': '精灵球',
  'special-balls': '特殊球',
  'apricorn-balls': '球果球',
  'healing': '药品',
  'medicine': '药品',
  'picky-healing': '精选药品',
  'revival': '复活',
  'status-cures': '状态恢复',
  'pp-recovery': 'PP恢复',
  'vitamins': '营养饮料',
  'stat-boosts': '能力提升',
  'effort-training': '努力值',
  'training': '训练',
  'held-items': '携带道具',
  'bad-held-items': '负面携带',
  'choice': '讲究系列',
  'type-enhancement': '属性强化',
  'type-protection': '属性防守',
  'evolution': '进化',
  'spelunking': '探险',
  'collectibles': '收集品',
  'event-items': '活动道具',
  'gameplay': '对战道具',
  'other': '其他',
  'picnic': '野餐',
  'in-a-pinch': '危急时刻',
};
