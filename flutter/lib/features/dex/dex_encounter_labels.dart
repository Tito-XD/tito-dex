import 'dex_game_scope.dart';

const _methodLabels = <String, String>{
  'walk': '草丛行走',
  'wild': '野外遭遇',
  'overworld': '明雷',
  'overworld-special': '特殊明雷',
  'overworld-water': '水上明雷',
  'overworld-water-special': '水上特殊明雷',
  'overworld-flying': '空中明雷',
  'overworld-flying-special': '空中特殊明雷',
  'overworld-dirt': '地面冒出',
  'surf': '冲浪',
  'surf-spots': '水面涟漪',
  'old-rod': '破旧钓竿',
  'good-rod': '好钓竿',
  'super-rod': '厉害钓竿',
  'super-rod-spots': '钓鱼点',
  'rock-smash': '碎岩',
  'headbutt': '撞树',
  'headbutt-low': '撞树（低频）',
  'headbutt-normal': '撞树',
  'headbutt-high': '撞树（高频）',
  'honey-tree': '甜甜蜜树',
  'horde': '群聚对战',
  'sos': '闯入对战',
  'sos-encounter': '闯入对战',
  'sos-from-bubbling-spot': '涟漪闯入对战',
  'max-raid': '极巨团体战',
  'raid': '团体战',
  'dynamax-adventure': '极巨大冒险',
  'outbreak': '大量出现',
  'swarm': '大量出现',
  'gift': '赠送',
  'gift-egg': '赠送的蛋',
  'npc-trade': 'NPC 交换',
  'static': '固定遭遇',
  'fixed': '固定遭遇',
  'only-one': '仅一次',
  'wanderer': '游走明雷',
  'wanderer-water': '水上游走',
  'roaming-grass': '草丛游走',
  'roaming-water': '水上游走',
  'dark-grass': '深色草丛',
  'grass-spots': '摇动草丛',
  'rustling-bush-ambush': '灌木伏击',
  'ceiling-ambush': '天花板伏击',
  'trash-can-ambush': '垃圾桶伏击',
  'berry-trees': '树果树',
  'bridge-spots': '桥面影子',
  'bubbling-spots': '水面气泡',
  'cave-spots': '洞穴扬尘',
  'rough-terrain': '崎岖地面',
  'seaweed': '海草',
  'chase-water': '水上追逐',
  'feebas-tile-fishing': '特殊钓鱼格',
  'hidden-grotto': '隐藏洞穴',
  'island-scan': '岛屿扫描',
  'devon-scope': '得文侦测镜',
  'pokeflute': '宝可梦之笛',
  'squirt-bottle': '杰尼龟喷壶',
  'wailmer-pail': '吼吼鲸喷壶',
  'pokespot': '宝可梦现身点',
  'snag': '夺取',
  'snag-rematch': '重战夺取',
  'pokemon-ranger': '宝可梦巡护员联动',
  'pokemon-channel-pal': '宝可梦频道联动',
  'colosseum-bonus-disc-jpn': '日版特典光盘',
  'colosseum-bonus-disc-us': '美版特典光盘',
  'red-flowers': '红花丛',
  'yellow-flowers': '黄花丛',
  'purple-flowers': '紫花丛',
};

String encounterMethodLabelZh(String slug) => _methodLabels[slug] ?? '特殊遭遇方式';

String encounterConditionLabelZh(String slug) {
  const exact = <String, String>{
    'time-day': '白天',
    'time-morning': '早晨',
    'time-night': '夜晚',
    'weather-normal': '普通天气',
    'weather-overcast': '阴天',
    'weather-raining': '下雨',
    'weather-thunderstorm': '雷雨',
    'weather-intense-sun': '烈日',
    'weather-sandstorm': '沙暴',
    'weather-fog': '雾天',
    'weather-snowing': '下雪',
    'weather-snowstorm': '暴雪',
    'season-spring': '春季',
    'season-summer': '夏季',
    'season-autumn': '秋季',
    'season-winter': '冬季',
    'radar-on': '使用宝可追踪',
    'radar-off': '不使用宝可追踪',
    'swarm-yes': '大量出现时',
    'swarm-no': '非大量出现',
    'roaming': '地图游走',
    'bug-catching-contest-yes': '捕虫大赛期间',
    'bug-catching-contest-no': '非捕虫大赛',
    'backlot-mentioned': '豪宅主人提及时',
    'backlot-not-mentioned': '豪宅主人未提及',
    'radio-hoenn': '播放丰缘之声',
    'radio-sinnoh': '播放神奥之声',
    'radio-off': '未播放宝可梦音乐',
    'headbutt-tree-common': '普通撞树点',
    'headbutt-tree-rare': '稀有撞树点',
    'headbutt-tree-secret': '隐藏撞树点',
    'honey-tree-group-a': '甜甜蜜树 A 组',
    'honey-tree-group-b': '甜甜蜜树 B 组',
    'honey-tree-group-c': '甜甜蜜树 C 组',
    'slot2-none': '无需插入 GBA 卡带',
    'defeated-ghetsis': '击败魁奇思后',
    'first-party-pokemon-high-friendship': '队首宝可梦高亲密度',
    'special-encounter-couldnt-capture-before': '此前未能捕获时',
    'trash-can-type-daily': '每日垃圾桶',
    'trash-can-type-thursday': '周四垃圾桶',
    'tv-option-blue': '电视选择蓝色',
    'tv-option-red': '电视选择红色',
  };
  final known = exact[slug];
  if (known != null) return known;

  final timeRange = RegExp(r'^time-(.+)$').firstMatch(slug);
  if (timeRange != null) {
    return '时间：${timeRange.group(1)!.replaceAll('-', ':')}';
  }
  final weekday = RegExp(r'^weekday-(.+)$').firstMatch(slug);
  if (weekday != null) {
    const labels = {
      'monday': '周一',
      'tuesday': '周二',
      'wednesday': '周三',
      'thursday': '周四',
      'friday': '周五',
      'saturday': '周六',
      'sunday': '周日',
    };
    return labels[weekday.group(1)] ?? '指定星期';
  }
  final denRating = RegExp(r'^max-den-rating-(\d)-star$').firstMatch(slug);
  if (denRating != null) return '${denRating.group(1)}★巢穴';
  if (slug == 'max-den-rarity-common') return '普通巢穴';
  if (slug == 'max-den-rarity-rare') return '稀有巢穴';
  if (slug == 'max-den-rarity-special') return '特殊巢穴';

  final safari = RegExp(
    r'^johto-safari-blocks-(forest|peak|plains|water)-min-(\d+)$',
  ).firstMatch(slug);
  if (safari != null) {
    const labels = {
      'forest': '森林',
      'peak': '山峰',
      'plains': '草原',
      'water': '水边',
    };
    return '狩猎地带：${labels[safari.group(1)]}摆设≥${safari.group(2)}';
  }
  if (slug == 'johto-safari-blocks-inactive') return '狩猎地带摆设未生效';

  final slot2 = RegExp(r'^slot2-(.+)$').firstMatch(slug);
  if (slot2 != null) return '插入${flavorVersionLabelZh(slot2.group(1)!)}卡带';
  final friendSafari = RegExp(r'^friend-safari-slot-(\d)$').firstMatch(slug);
  if (friendSafari != null) return '朋友狩猎第${friendSafari.group(1)}栏';
  final greatMarsh = RegExp(r'^great-marsh-daily-slot-(.+)$').firstMatch(slug);
  if (greatMarsh != null) {
    return '大湿地每日轮换：${greatMarsh.group(1)!.replaceAll('-', ' ')}';
  }
  final coins = RegExp(r'^coins-(\d+)$').firstMatch(slug);
  if (coins != null) return '需要${coins.group(1)}枚代币';
  final diglett = RegExp(r'^alolan-diglett-found-(\d+)$').firstMatch(slug);
  if (diglett != null) return '找到${diglett.group(1)}只阿罗拉地鼠';
  if (slug.startsWith('berry-tree-type-')) return '指定颜色树果树';
  if (slug.startsWith('item-')) return '持有指定关键道具';
  if (slug.startsWith('trade-')) return '完成指定 NPC 交换';
  if (slug.startsWith('starter-')) return '选择指定初始宝可梦';
  if (slug.startsWith('save-data-from-')) {
    return '拥有对应游戏存档联动';
  }
  if (slug.startsWith('story-progress-')) return '达到指定剧情进度';
  if (slug.startsWith('other-')) return '满足特殊剧情条件';
  return '特殊出现条件';
}
