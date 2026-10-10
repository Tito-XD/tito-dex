// Alias definitions mirror cloudflare/journey-assistant/src/question_game_aliases.json.
// Keep both generated name tables in sync when adding a game; no backend key is invented.
class _GameAliases {
  const _GameAliases(this.targets, this.aliases, this.needsContext);
  final List<(String?, String)> targets;
  final List<String> aliases;
  final bool needsContext;
}

const _gameAliases = <_GameAliases>[
  _GameAliases([("diamond", "Diamond")], ["钻石", "Diamond"], true),
  _GameAliases([("pearl", "Pearl")], ["珍珠", "Pearl"], true),
  _GameAliases([("platinum", "Platinum")], ["白金", "Platinum"], true),
  _GameAliases([("heartgold", "HeartGold")], ["心金", "HeartGold"], false),
  _GameAliases([("soulsilver", "SoulSilver")], ["魂银", "SoulSilver"], false),
  _GameAliases([("black", "Black")], ["黑", "Black"], true),
  _GameAliases([("white", "White")], ["白", "White"], true),
  _GameAliases([("black-2", "Black 2")], ["黑2", "Black 2", "Black2"], false),
  _GameAliases([("white-2", "White 2")], ["白2", "White 2", "White2"], false),
  _GameAliases([("x", "X")], ["X"], true),
  _GameAliases([("y", "Y")], ["Y"], true),
  _GameAliases(
    [("omega-ruby", "Omega Ruby")],
    ["欧米伽红宝石", "Omega Ruby", "欧米加红宝石"],
    false,
  ),
  _GameAliases(
    [("alpha-sapphire", "Alpha Sapphire")],
    ["阿尔法蓝宝石", "Alpha Sapphire"],
    false,
  ),
  _GameAliases([("sun", "Sun")], ["太阳", "Sun"], true),
  _GameAliases([("moon", "Moon")], ["月亮", "Moon"], true),
  _GameAliases([("ultra-sun", "Ultra Sun")], ["究极之日", "Ultra Sun"], false),
  _GameAliases([("ultra-moon", "Ultra Moon")], ["究极之月", "Ultra Moon"], false),
  _GameAliases([("sword", "Sword")], ["剑", "Sword"], true),
  _GameAliases([("shield", "Shield")], ["盾", "Shield"], true),
  _GameAliases(
    [("brilliant-diamond", "Brilliant Diamond")],
    ["晶灿钻石", "Brilliant Diamond"],
    false,
  ),
  _GameAliases(
    [("shining-pearl", "Shining Pearl")],
    ["明亮珍珠", "Shining Pearl"],
    false,
  ),
  _GameAliases(
    [("legends-arceus", "Legends Arceus")],
    ["传说阿尔宙斯", "Legends Arceus", "传说 阿尔宙斯", "Legends: Arceus"],
    false,
  ),
  _GameAliases([("scarlet", "Scarlet")], ["朱", "Scarlet"], true),
  _GameAliases([("violet", "Violet")], ["紫", "Violet"], true),
  _GameAliases(
    [("scarlet", "Scarlet"), ("violet", "Violet")],
    ["朱紫", "Scarlet and Violet", "Scarlet/Violet", "S/V"],
    true,
  ),
  _GameAliases(
    [("sword", "Sword"), ("shield", "Shield")],
    ["剑盾", "SwSh"],
    false,
  ),
  _GameAliases(
    [("sword", "Sword"), ("shield", "Shield")],
    ["Sword and Shield", "Sword/Shield"],
    true,
  ),
  _GameAliases(
    [("diamond", "Diamond"), ("pearl", "Pearl")],
    ["钻石珍珠", "Diamond and Pearl", "Diamond/Pearl", "DP"],
    true,
  ),
  _GameAliases(
    [("heartgold", "HeartGold"), ("soulsilver", "SoulSilver")],
    ["心金魂银", "HGSS"],
    false,
  ),
  _GameAliases(
    [("heartgold", "HeartGold"), ("soulsilver", "SoulSilver")],
    ["HeartGold and SoulSilver"],
    true,
  ),
  _GameAliases(
    [("black", "Black"), ("white", "White")],
    ["黑白", "Black and White", "Black/White", "BW"],
    true,
  ),
  _GameAliases(
    [("black-2", "Black 2"), ("white-2", "White 2")],
    ["黑2白2", "B2W2"],
    false,
  ),
  _GameAliases(
    [("black-2", "Black 2"), ("white-2", "White 2")],
    ["Black 2 and White 2"],
    true,
  ),
  _GameAliases([("x", "X"), ("y", "Y")], ["XY", "X/Y"], true),
  _GameAliases(
    [("sun", "Sun"), ("moon", "Moon")],
    ["日月", "太阳月亮", "Sun and Moon", "Sun/Moon", "SM"],
    true,
  ),
  _GameAliases(
    [("ultra-sun", "Ultra Sun"), ("ultra-moon", "Ultra Moon")],
    ["究极日月", "USUM"],
    false,
  ),
  _GameAliases(
    [("ultra-sun", "Ultra Sun"), ("ultra-moon", "Ultra Moon")],
    ["Ultra Sun and Ultra Moon"],
    true,
  ),
  _GameAliases(
    [
      ("brilliant-diamond", "Brilliant Diamond"),
      ("shining-pearl", "Shining Pearl"),
    ],
    ["晶灿钻石明亮珍珠", "BDSP"],
    false,
  ),
  _GameAliases(
    [
      ("brilliant-diamond", "Brilliant Diamond"),
      ("shining-pearl", "Shining Pearl"),
    ],
    ["Brilliant Diamond and Shining Pearl"],
    true,
  ),
  _GameAliases(
    [("omega-ruby", "Omega Ruby"), ("alpha-sapphire", "Alpha Sapphire")],
    ["ORAS"],
    false,
  ),
  _GameAliases(
    [("omega-ruby", "Omega Ruby"), ("alpha-sapphire", "Alpha Sapphire")],
    ["Omega Ruby and Alpha Sapphire"],
    true,
  ),
  _GameAliases([(null, "Red")], ["红", "Red"], true),
  _GameAliases([(null, "Blue")], ["蓝", "Blue"], true),
  _GameAliases([(null, "Green")], ["绿", "Green"], true),
  _GameAliases([(null, "Yellow")], ["黄", "Yellow"], true),
  _GameAliases([(null, "Gold")], ["金", "Gold"], true),
  _GameAliases([(null, "Silver")], ["银", "Silver"], true),
  _GameAliases([(null, "Crystal")], ["水晶", "Crystal"], true),
  _GameAliases([(null, "FireRed")], ["火红", "FireRed", "Fire Red"], false),
  _GameAliases([(null, "LeafGreen")], ["叶绿", "LeafGreen", "Leaf Green"], false),
  _GameAliases([(null, "Ruby")], ["红宝石", "Ruby"], true),
  _GameAliases([(null, "Sapphire")], ["蓝宝石", "Sapphire"], true),
  _GameAliases([(null, "Emerald")], ["绿宝石", "Emerald"], true),
  _GameAliases(
    [(null, "Legends Z-A")],
    ["传说Z-A", "传说 Z-A", "Legends Z-A", "Legends: Z-A"],
    false,
  ),
  _GameAliases(
    [(null, "Red"), (null, "Blue")],
    ["红蓝", "红/蓝", "Red and Blue", "Red/Blue", "RB"],
    true,
  ),
  _GameAliases(
    [(null, "Gold"), (null, "Silver")],
    ["金银", "Gold and Silver", "Gold/Silver", "GS"],
    true,
  ),
  _GameAliases(
    [(null, "Ruby"), (null, "Sapphire")],
    ["红蓝宝石", "红宝石蓝宝石", "Ruby and Sapphire", "Ruby/Sapphire", "RS"],
    true,
  ),
  _GameAliases(
    [(null, "FireRed"), (null, "LeafGreen")],
    ["火红叶绿", "FireRed and LeafGreen", "FireRed/LeafGreen", "FRLG"],
    true,
  ),
  _GameAliases(
    [(null, "Let's Go Pikachu")],
    ["Let's Go Pikachu", "Let's Go 皮卡丘"],
    false,
  ),
  _GameAliases(
    [(null, "Let's Go Eevee")],
    ["Let's Go Eevee", "Let's Go 伊布"],
    false,
  ),
  _GameAliases([(null, "Champions")], ["Champions"], true),
  _GameAliases(
    [(null, "Legends Z-A Mega Dimension")],
    ["超级维度", "Mega Dimension"],
    false,
  ),
  _GameAliases([(null, "Yellow")], ["皮卡丘版"], false),
  _GameAliases([("scarlet", "Scarlet"), ("violet", "Violet")], ["朱/紫"], true),
  _GameAliases([("sword", "Sword"), ("shield", "Shield")], ["剑/盾"], true),
  _GameAliases([("diamond", "Diamond"), ("pearl", "Pearl")], ["钻石/珍珠"], true),
  _GameAliases([("sun", "Sun"), ("moon", "Moon")], ["太阳/月亮"], true),
  _GameAliases(
    [("ultra-sun", "Ultra Sun"), ("ultra-moon", "Ultra Moon")],
    ["究极之日/月"],
    true,
  ),
  _GameAliases(
    [(null, "Red"), (null, "Green"), (null, "Blue")],
    ["红/绿/蓝"],
    true,
  ),
  _GameAliases([(null, "Gold"), (null, "Silver")], ["金/银"], true),
  _GameAliases(
    [(null, "Let's Go Pikachu"), (null, "Let's Go Eevee")],
    ["Let's Go 皮卡丘/伊布", "Let's Go Pikachu/Eevee", "LGPE"],
    true,
  ),
  _GameAliases(
    [("heartgold", "HeartGold"), ("soulsilver", "SoulSilver")],
    ["心金/魂银"],
    true,
  ),
  _GameAliases([("black", "Black"), ("white", "White")], ["黑/白"], true),
  _GameAliases(
    [("black-2", "Black 2"), ("white-2", "White 2")],
    ["黑2/白2"],
    true,
  ),
  _GameAliases(
    [("omega-ruby", "Omega Ruby"), ("alpha-sapphire", "Alpha Sapphire")],
    ["欧米加红宝石/阿尔法蓝宝石", "欧米伽红宝石/阿尔法蓝宝石"],
    true,
  ),
  _GameAliases(
    [
      ("brilliant-diamond", "Brilliant Diamond"),
      ("shining-pearl", "Shining Pearl"),
    ],
    ["晶灿钻石/明亮珍珠"],
    true,
  ),
  _GameAliases([(null, "Ruby"), (null, "Sapphire")], ["红宝石/蓝宝石"], true),
  _GameAliases([(null, "FireRed"), (null, "LeafGreen")], ["火红/叶绿"], true),
];
const _gameEntityNames = [
  "Ability Shield",
  "Adamant Crystal",
  "Big Pearl",
  "Black Apricorn",
  "Black Augurite",
  "Black Belt",
  "Black Flute",
  "Black Glasses",
  "Black Hole",
  "Black Hole Eclipse",
  "Black Kyurem",
  "Black Mane Hair",
  "Black Sludge",
  "Blood Moon",
  "Blue Apricorn",
  "Blue Bottle",
  "Blue Card",
  "Blue Cup",
  "Blue Dish",
  "Blue Flare",
  "Blue Flute",
  "Blue Orb",
  "Blue Petal",
  "Blue Poké Ball Pick",
  "Blue Scarf",
  "Blue Shard",
  "Blue Tablecloth",
  "Blue-Flag Pick",
  "Blue-Sky Flower Pick",
  "Charizardite X",
  "Charizardite Y",
  "Crafty Shield",
  "Crystal Cluster",
  "Dauntless Shield",
  "Diamond Bottle",
  "Diamond Pattern Cup",
  "Diamond Storm",
  "Diamond Tablecloth",
  "Flower Shield",
  "Glimmet Crystal",
  "Gold Bottle",
  "Gold Bottle Cap",
  "Gold Cup",
  "Gold Leaf",
  "Gold Pick",
  "Gold Teeth",
  "Good as Gold",
  "Green Apricorn",
  "Green Bell Pepper",
  "Green Dish",
  "Green Petal",
  "Green Poké Ball Pick",
  "Green Scarf",
  "Green Shard",
  "Heroic Sword Pick",
  "Intrepid Sword",
  "King’s Shield",
  "Mewtwonite X",
  "Mewtwonite Y",
  "Moon Ball",
  "Moon Flute",
  "Moon Stone",
  "Morning Sun",
  "Pearl String",
  "Plaid Tablecloth (Y)",
  "Red Apricorn",
  "Red Bell Pepper",
  "Red Card",
  "Red Chain",
  "Red Dish",
  "Red Flute",
  "Red Nectar",
  "Red Onion",
  "Red Orb",
  "Red Petal",
  "Red Poké Ball Pick",
  "Red Scale",
  "Red Scarf",
  "Red Shard",
  "Red-Flag Pick",
  "Relic Gold",
  "Relic Silver",
  "Roaring Moon",
  "Rusted Shield",
  "Rusted Sword",
  "Sacred Sword",
  "Scarlet Book",
  "Secret Sword",
  "Shadow Shield",
  "Shellder Pearl",
  "Shield Dust",
  "Silver Bottle",
  "Silver Cup",
  "Silver Leaf",
  "Silver Nanab Berry",
  "Silver Pick",
  "Silver Pinap Berry",
  "Silver Powder",
  "Silver Razz Berry",
  "Silver Wind",
  "Silver Wing",
  "Spiky Shield",
  "Spoink Pearl",
  "Steel Bottle (Y)",
  "Sun Flute",
  "Sun Stone",
  "Sword of Ruin",
  "Violet Book",
  "White Apricorn",
  "White Dish",
  "White Flute",
  "White Herb",
  "White Kyurem",
  "White Mane Hair",
  "White Smoke",
  "X Accuracy",
  "X Accuracy 2",
  "X Accuracy 3",
  "X Accuracy 6",
  "X Attack",
  "X Attack 2",
  "X Attack 3",
  "X Attack 6",
  "X Defense",
  "X Defense 2",
  "X Defense 3",
  "X Defense 6",
  "X Sp. Atk",
  "X Sp. Atk 2",
  "X Sp. Atk 3",
  "X Sp. Atk 6",
  "X Sp. Def",
  "X Sp. Def 2",
  "X Sp. Def 3",
  "X Sp. Def 6",
  "X Speed",
  "X Speed 2",
  "X Speed 3",
  "X Speed 6",
  "X-Scissor",
  "Yellow Apricorn",
  "Yellow Bell Pepper",
  "Yellow Bottle",
  "Yellow Cup",
  "Yellow Dish",
  "Yellow Flute",
  "Yellow Nectar",
  "Yellow Petal",
  "Yellow Scarf",
  "Yellow Shard",
  "Yellow Tablecloth",
  "raichunite-x",
  "raichunite-y",
  "不屈之盾",
  "不挠之剑",
  "丸子珍珠",
  "兰紫色花蜜",
  "剑舞",
  "勇者之剑三明治签",
  "双剑鞘",
  "古代金币",
  "古代银币",
  "古剑豹",
  "叶绿爆震",
  "叶绿素",
  "圣剑",
  "坚盾剑怪",
  "大剑鬼",
  "大珍珠",
  "大白宝玉",
  "大白金宝玉",
  "大舌贝的珍珠",
  "大金刚宝玉",
  "太阳之力",
  "太阳之笛",
  "太阳伊布",
  "太阳岩",
  "太阳珊瑚",
  "妖火红狐",
  "小西红柿块",
  "小黄瓜片",
  "巨剑突击",
  "巨大金珠",
  "巨金怪",
  "巨金怪进化石",
  "席多蓝恩",
  "悔念剑",
  "护符金币",
  "断崖之剑",
  "暗黑气场",
  "暗黑洞",
  "暗黑爆破",
  "月亮之力",
  "月亮之笛",
  "月亮伊布",
  "月亮球",
  "朱之书",
  "朱红色宝珠",
  "朱红色花蜜",
  "水晶灯火灵",
  "浅绿桌巾",
  "淘金潮",
  "漆黑嘶鸣",
  "火红不倒翁",
  "灾祸之剑",
  "独剑鞘",
  "王者盾牌",
  "珍珠贝",
  "界限盾壳",
  "白海狮",
  "白玉宝珠",
  "白球果",
  "白色烟雾",
  "白色玻璃哨",
  "白色盘子",
  "白色香草",
  "白色鬃毛",
  "白蓬蓬",
  "白金宝珠",
  "白银喷雾",
  "白银香水",
  "白雾",
  "盾甲化石",
  "盾甲茧",
  "盾甲龙",
  "碧绿石板",
  "神秘之剑",
  "秘剑・千重涛",
  "粉红头巾",
  "粉红桌巾",
  "粉红水壶",
  "粉红水杯",
  "粉红花瓣",
  "精神剑",
  "紫之书",
  "紫色桌巾",
  "紫色花瓣",
  "纏红鹤",
  "红旗子三明治签",
  "红椒片",
  "红洋葱",
  "红牌",
  "红珠珠三明治签",
  "红球果",
  "红纹不锈钢水壶",
  "红线",
  "红色头巾",
  "红色格子桌巾",
  "红色玻璃哨",
  "红色盘子",
  "红色碎片",
  "红色花瓣",
  "红色锁链",
  "红色鳞片",
  "红莲铠骑",
  "纸御剑",
  "绯红脉动",
  "绿毛虫",
  "绿毛虫的糖果",
  "绿珠珠三明治签",
  "绿球果",
  "绿色头巾",
  "绿色盘子",
  "绿色碎片",
  "绿色花瓣",
  "缠红鹤的羽绒",
  "腐朽的剑",
  "腐朽的盾",
  "苍白嘶鸣",
  "草绿色宝珠",
  "蓝卡",
  "蓝天石板",
  "蓝旗子三明治签",
  "蓝珠珠三明治签",
  "蓝球果",
  "蓝纹不锈钢水壶",
  "蓝色头巾",
  "蓝色格子桌巾",
  "蓝色桌巾",
  "蓝色水壶",
  "蓝色水杯",
  "蓝色玻璃哨",
  "蓝色盘子",
  "蓝色碎片",
  "蓝色花瓣",
  "蓝蟾蜍",
  "蓝鳄",
  "蓝鸦",
  "蛋黄酱",
  "西红柿片",
  "角金鱼",
  "角金鱼的糖果",
  "谜之水晶",
  "跳跳猪的珍珠",
  "轰擂金刚猩",
  "轻金属",
  "酸黄瓜片",
  "重金属",
  "金假牙",
  "金刚宝珠",
  "金属怪",
  "金属爆炸",
  "金属爪",
  "金属粉",
  "金属膜",
  "金属防护",
  "金属音",
  "金枕果",
  "金珠",
  "金色三明治签",
  "金色凰梨果",
  "金色叶子",
  "金色王冠",
  "金色蔓莓果",
  "金色蕉香果",
  "金钛水壶",
  "金钛水杯",
  "金鱼王",
  "金黄色花蜜",
  "钻石风暴",
  "银伴战兽",
  "银河队钥匙",
  "银粉",
  "银色三明治签",
  "银色之羽",
  "银色凰梨果",
  "银色叶子",
  "银色旋风",
  "银色王冠",
  "银色蔓莓果",
  "银色蕉香果",
  "银钛水壶",
  "银钛水杯",
  "靛蓝色宝珠",
  "飞水手里剑",
  "黄椒片",
  "黄油",
  "黄球果",
  "黄纹不锈钢水壶",
  "黄色头巾",
  "黄色格子桌巾",
  "黄色桌巾",
  "黄色水壶",
  "黄色水杯",
  "黄色玻璃哨",
  "黄色盘子",
  "黄色碎片",
  "黄色花瓣",
  "黄芥末酱",
  "黄金之躯",
  "黄金喷雾",
  "黄金香水",
  "黑夜魔影",
  "黑夜魔灵",
  "黑带",
  "黑暗存储碟",
  "黑暗暴冲",
  "黑暗球",
  "黑暗石",
  "黑暗鸦",
  "黑暗鸦的宝物",
  "黑洞吞噬万物灭",
  "黑球果",
  "黑白草丛桌巾",
  "黑眼鳄",
  "黑眼鳄的爪子",
  "黑色污泥",
  "黑色玻璃哨",
  "黑色目光",
  "黑色眼镜",
  "黑色铁球",
  "黑色鬃毛",
  "黑萝卜",
  "黑雾",
  "黑鲁加",
  "黑鲁加进化石",
  "ＤＤ金勾臂",
];

final _nonGame = RegExp(
  r'动画|動畫|动漫|動漫|漫画|漫畫|特别篇|特別篇|卡牌|卡片|集换式|集換式|剧场版|电影|電影|台词|配音|声优|\b(?:anime|cartoon|manga|movie|film|episode|voice|tcg|ptcg|tcgp|cards?|pocket)\b',
  caseSensitive: false,
  unicode: true,
);
final _gameIntent = RegExp(
  r'捕捉|捕获|获得|进化|招式|学习|道馆|通关|图鉴|流程|版本|游戏|\b(?:catch|caught|capture|encounter|appear|find|found|obtain|evolve|evolution|learn|moves?|learnset|pokedex|gym|walkthrough|playthrough|games?|versions?)\b',
  caseSensitive: false,
  unicode: true,
);
final _followUp = RegExp(
  r'^(?:那|那么|然后|之后|接下来|下一步|它|它们|这个|那个|还有|再说|再问|具体|也能|能不能|还能|为什么会|怎么会)|^(?:怎么获得|怎么捕捉|在哪里|在哪儿|哪里|如何获得|可以吗|能吗|行吗|对吗|为什么|怎么做|怎么办|怎么进化|如何进化)[？?！!。\s]*$|^(?:what about (?:it|that|this|them|those|these)|(?:how|why|where|when)(?: does| do| is| are| can| would| should)? (?:it|they|that|this|those|these)\b|(?:can|could|does|do|is|are|will|would) (?:it|they|that|this)\b|(?:can|could) I (?:use|get|find|play|evolve) (?:it|them)\b|which ones?[?\s]*$|why[?\s]*$|how so[?\s]*$|what next[?\s]*$|and then[?\s]*$|tell me more[?\s]*$|go on[?\s]*$)',
  caseSensitive: false,
  unicode: true,
);

bool _isFollowUp(String question) => _followUp.hasMatch(
  question.trim().replaceAll(RegExp(r'[，。！？!?、\s]+$'), ''),
);

bool _qualified(String text, int start, int end, String alias) {
  final before = text.substring(0, start);
  final after = text.substring(end);
  final latin = RegExp(r'^[a-z]', caseSensitive: false).hasMatch(alias);
  if (RegExp(
    r'(?:宝可梦|寶可夢|神奇宝贝|口袋妖怪|pok[eé]mon|游戏|遊戲|game|version)\s*(?:[：:·]\s*)?$',
    caseSensitive: false,
    unicode: true,
  ).hasMatch(before)) {
    return true;
  }
  if (RegExp(
    r'^\s*(?:版|版本|游戏|遊戲|game\b|version\b)',
    caseSensitive: false,
    unicode: true,
  ).hasMatch(after)) {
    return true;
  }
  if (!latin && RegExp(r'^\s*(?:里|裡|中)', unicode: true).hasMatch(after)) {
    return true;
  }
  if (RegExp(r'[《「“"]\s*$', unicode: true).hasMatch(before) &&
      RegExp(r'^\s*(?:版)?[》」”"]', unicode: true).hasMatch(after)) {
    return true;
  }
  return latin &&
      _gameIntent.hasMatch(text) &&
      RegExp(r'\b(?:in|for|on|of)\s*$', caseSensitive: false).hasMatch(before);
}

List<(String?, String)> _explicitGames(String question) {
  final text = String.fromCharCodes(
    question.runes.map(
      (rune) => rune == 0x3000
          ? 0x20
          : rune >= 0xff01 && rune <= 0xff5e
          ? rune - 0xfee0
          : rune,
    ),
  );
  if (_nonGame.hasMatch(text)) return const [];
  final candidates = [
    for (final group in _gameAliases)
      for (final alias in group.aliases) (group, alias),
  ]..sort((a, b) => b.$2.length.compareTo(a.$2.length));
  final entitySpans = <(int, int)>[
    for (final name in _gameEntityNames)
      for (final match in RegExp(
        RegExp.escape(name),
        caseSensitive: false,
        unicode: true,
      ).allMatches(text))
        (match.start, match.end),
  ];
  final spans = <(int, int)>[];
  final targets = <String, (String?, String)>{};
  for (final candidate in candidates) {
    final boundary =
        RegExp(r'^[a-z]', caseSensitive: false).hasMatch(candidate.$2)
        ? '(?:(?<![a-z0-9])|(?<=pok[eé]mon))'
        : '';
    final pattern = RegExp(
      '$boundary${RegExp.escape(candidate.$2)}(?![a-z0-9])',
      caseSensitive: false,
      unicode: true,
    );
    for (final match in pattern.allMatches(text)) {
      if (spans.any((span) => match.start < span.$2 && match.end > span.$1)) {
        continue;
      }
      if (entitySpans.any(
        (span) =>
            span.$1 <= match.start &&
            span.$2 >= match.end &&
            (span.$1 < match.start || span.$2 > match.end),
      )) {
        continue;
      }
      if (RegExp(
        r'^\s*[》」”"]?\s*(?:(?:这个|这种|这个叫|作为)(?:道具|特性|招式)|the (?:item|ability|move)\b)',
        caseSensitive: false,
        unicode: true,
      ).hasMatch(text.substring(match.end))) {
        spans.add((match.start, match.end));
        continue;
      }
      if (candidate.$1.needsContext &&
          !_qualified(text, match.start, match.end, candidate.$2)) {
        continue;
      }
      spans.add((match.start, match.end));
      for (final target in candidate.$1.targets) {
        targets[target.$1 ?? target.$2] = target;
      }
    }
  }
  return targets.values.toList(growable: false);
}

/// Prevents local hints for the global save from taking ownership of another game's question.
/// It does not change the global edition, HTTP contract or saved progress.
bool shouldSkipLocalGameHints(
  String question,
  String? globalGame,
  List<Map<String, String>> history,
) {
  var targets = _explicitGames(question);
  if (targets.isEmpty &&
      _isFollowUp(question) &&
      !_nonGame.hasMatch(question)) {
    // Incomplete/failed history is a boundary, never a way to revive an older game.
    if (history.isNotEmpty &&
        (history.last['role'] != 'assistant' ||
            (history.last['content'] ?? '').trim().isEmpty)) {
      return false;
    }
    for (final message in history.reversed) {
      if (message['role'] != 'user') continue;
      final content = message['content'] ?? '';
      if (_nonGame.hasMatch(content) || content.trim().isEmpty) break;
      targets = _explicitGames(content);
      if (targets.isNotEmpty || !_isFollowUp(content)) break;
    }
  }
  return targets.isNotEmpty &&
      (targets.length != 1 ||
          targets.single.$1 == null ||
          targets.single.$1 != globalGame);
}
