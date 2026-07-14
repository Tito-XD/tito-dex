/// Simplified Chinese UI copy for TitoDex.
import '../features/dex/dex_models.dart';

abstract final class AppZh {
  static const appTitle = 'TitoDex';

  /// Home header title — default TitoDex; custom trainer → «Name»Dex.
  static String displayTitleForTrainer(String trainerName) {
    final trimmed = trainerName.trim();
    if (trimmed.isEmpty || trimmed == 'Tito' || trimmed == 'Trainer') {
      return appTitle;
    }
    return '${trimmed}Dex';
  }

  static const navHome = '首页';
  static const navTeam = '队伍';
  static const navJourney = '旅程';
  static const navDex = '图鉴';
  static const navSearch = '搜索';
  static const navSettings = '设置';

  static const trainerCard = '训练家卡片';
  static const companion = '同伴';

  static String timeGreeting(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 8) return '早上好';
    if (hour >= 8 && hour < 11) return '上午好';
    if (hour >= 11 && hour < 13) return '中午好';
    if (hour >= 13 && hour < 17) return '下午好';
    if (hour >= 17 && hour < 19) return '傍晚好';
    if (hour >= 19 && hour < 23) return '晚上好';
    return '深夜好';
  }

  static String trainerGreeting(String trainerName, [DateTime? time]) =>
      '${timeGreeting(time ?? DateTime.now())}，训练家 $trainerName';

  static const journeyCardTitle = '旅程';
  static const journeyOpenDetail = '查看旅程详情';
  static const emulatorContinueHint = '从模拟器继续';
  static const partySaveDiffBanner = '与最新存档不同 · 点击同步';
  static const partySaveSyncConfirm = '用存档队伍覆盖当前编辑？';
  static const settingsChangeAvatar = '更换头像';
  static const settingsJourneyReadOnly = '旅程信息（来自存档）';
  static const teamSummaryTitle = '队伍概览';
  static const sleepToolsTitle = 'Pokémon Sleep 工具';
  static const sleepToolsTierAHint = 'Tier A：静态链接，点击复制到剪贴板';
  static const dexManualMarkSeen = '已标记为见过';
  static const dexManualMarkCaught = '已标记为捕获';
  static const dexManualMarkClear = '已清除标记';

  static const continueJourney = '继续旅程';
  static const cityView = '★  城景  ★';
  static const continueButton = '继续';

  static const labelGame = '游戏';
  static const labelPlayTime = '游戏时间';
  static const labelBadges = '徽章';

  static const party = '队伍';
  static const currentParty = '当前队伍';
  static String partySlot(int index) => '#$index';
  static const level = 'Lv';

  static const journeySince2026 = '旅程始于 2026';
  static const widgetContinue = '继续';
  static String companionMessage(String location) => '$location 今天也很热闹！';

  static const dexScopeNote =
      '全国图鉴 1–1025，中文名与属性来自在线图鉴；已捕获/已见过状态来自存档与同行队伍。';
  static const dexCaught = '已捕获';
  static const dexSeen = '已见过';
  static const dexUnknown = '未见过';
  static const dexFilterAll = '全部';
  static const dexFilterCaught = '已捕获';
  static const dexFilterSeen = '已见过';
  static const dexFilterUnseen = '未见过';
  static String dexScopeProgress(int caught, int seen, int total) =>
      '捕获 $caught · 见过 $seen / $total';
  static const dexTabNational = '全国图鉴';
  static String dexRegionalDexTitle(String regionLabel) => '$regionLabel图鉴';
  static const dexPickRegionalPokedex = '选择地区图鉴';
  static const dexTabJourney = '旅程同行';
  static const dexFilterEmpty = '当前筛选条件下暂无图鉴条目。';
  static String dexRegionProgress(
    int startId,
    int endId,
    int seen,
    int caught,
    int total,
  ) =>
      '#$startId–$endId · 已见 $seen / 已捕 $caught / 共 $total';
  static const dexRegionNational = '全国';
  static const dexRegionJohto = '城都';
  static const dexRegionKanto = '关东';
  static const dexJourneyEmpty = '当前旅程同行里还没有载入图鉴条目，试试全国图鉴。';
  static const dexCaughtEmpty = '还没有已捕获的图鉴条目，同行宝可梦会自动标记为已捕获。';
  static const dexSeenEmpty = '还没有已见过的图鉴条目。';
  static String dexLoadingProgress(int loaded, int total) =>
      '正在加载图鉴 $loaded / $total…';
  static const dexLoadingDetail = '正在从 PokeAPI 拉取详情…';
  static const dexLoadFailed = '图鉴数据加载失败';
  static String dexLoadFailedDetail(int statusCode) =>
      'PokeAPI 请求失败（HTTP $statusCode）。请检查网络，或在设置中下载离线图鉴后重试。';
  static const errorGeneric = '加载失败，请稍后重试。';
  static const errorFormatDetail = '数据格式异常，请检查网络后重试，或下载离线图鉴。';
  static const dexRetry = '重试';
  static const dexHeight = '身高';
  static const dexWeight = '体重';
  static const dexWeaknesses = '弱点（受到 ×2）';
  static const dexResistances = '抗性（受到 ×0.5）';
  static const dexImmunities = '免疫（受到 ×0）';
  static const dexStabEffective = '本系克制（打出 ×2）';
  static const dexEvolution = '进化链';
  static const dexObtainHgss = '心金·魂银 出现地点';
  static const dexObtainEmpty =
      'PokeAPI 未收录该宝可梦在心金/魂银的野外遭遇数据（可能为进化、赠送或不可野生捕获）。';
  static const dexFlavorEnglishNote = '该世代暂无官方中文描述，以下为英文原文。';
  static const dexFlavorZhFallbackNote =
      '心金/魂银世代无中文图鉴文案，以下为近世代中文译名供参考。';
  static const dexNone = '无';
  static const dexApiNote =
      '数据来源：PokeAPI。部分后世代属性修正（如妖精系）可能与 HGSS 游戏内略有不同，仅供参考。';
  static const dexMoves = '升级招式';
  static String dexMovesMore(int count) => '另有 $count 个招式已缓存';
  static const dexTabIntro = '简介';
  static const dexTabBasic = '基本信息';
  static const dexTabObtain = '获取';
  static const dexTabMoves = '招式';
  static const dexFlavorTitle = '图鉴描述';
  static const dexFlavorEmpty = '暂无可用图鉴描述（PokeAPI 未提供该版本中文文案时会显示英文）。';
  static const dexAbilities = '特性';
  static const dexAbilityHidden = '隐藏特性';
  static const dexAbilityAllVersions = '全版本';
  static const dexAbilitySinceGen5 = '第五世代起';
  static const dexAbilityFilter = '特性筛选';
  static const dexAbilityUnknownName = '待收录';
  static const dexAbilityPlaceholder = '特性资料整理中，将随后续图鉴数据包更新。';
  static const dexAbilityEmptyPending = '暂无特性数据。';
  static const dexBaseHappiness = '初始亲密度';
  static const dexCaptureRate = '捕获率';
  static const dexEvYield = '基础点数 (EV)';
  static const dexObtainEmptyVersion = '暂无野外出现地点（可能为进化、赠送或不可野生捕获）。';
  static String dexObtainForGame(String gameLabel) => '$gameLabel 出现地点';
  static const dexFlavorNoEdition =
      '当前版本暂无图鉴描述';
  static const dexFlavorPickEdition = '选择其他版本查看';
  static const dexMoveFilterAll = '全部';
  static const dexMoveFilterLevel = '等级';
  static const dexMoveFilterMachine = '学习器';
  static const dexMoveFilterEgg = '蛋';
  static const dexMoveFilterTutor = '教学';
  static const dexBaseStats = '种族值';
  static const dexBaseStatTotal = '种族值合计';
  static const dexTypeGridTitle = '当受到以下属性攻击时';
  static const dexGenderRatio = '性别比例';
  static String dexGenderFemale(double percent) =>
      '雌性 ${percent.toStringAsFixed(1)}%';
  static const dexEggGroups = '生蛋分组';
  static const dexHatchSteps = '孵化步数';
  static const dexNoEvolution = '没有进化链记录。';
  static const dexMovesHgssScope = '以下招式范围：心金 / 魂银';
  static String dexMovesScope(String gameLabel) => '以下招式范围：$gameLabel';
  static const dexBaseStatsRadar = '能力雷达';
  static const dexBaseStatsBars = '种族值条';
  static const dexReferenceTitle = '常用资料';
  static const dexReferenceMoves = '招式图鉴';
  static const dexReferenceAbilities = '特性图鉴';
  static const dexReferenceSearchHint = '搜索名称或编号…';
  static const dexReferenceEmpty = '没有匹配的资料条目。';
  static const dexReferenceNoDescription = '暂无特性说明。';
  static const dexReferenceFindPokemon = '搜索拥有此资料的宝可梦';
  static String dexReferenceMoveMeta(
    String category,
    int? power,
    int? accuracy,
    int? pp,
  ) {
    final parts = <String>[category];
    if (power != null) {
      parts.add('威力 $power');
    }
    if (accuracy != null) {
      parts.add('命中 $accuracy');
    }
    if (pp != null) {
      parts.add('PP $pp');
    }
    return parts.join(' · ');
  }
  static const dexReferenceNatureStats = '能力变化';
  static const dexReferenceNatureFlavors = '口味偏好';
  static const dexReferenceNatureNeutral = '无能力变化（中性性格）';
  static String dexReferenceLikesFlavor(String flavor) => '喜好 $flavor 味';
  static String dexReferenceHatesFlavor(String flavor) => '厌恶 $flavor 味';
  static const dexReferenceViewEggGroupPokemon = '查看蛋群宝可梦';
  static const dexReferenceViewMoveLearners = '会此招式的宝可梦';
  static const dexReferenceViewAbilityPokemon = '拥有此特性的宝可梦';
  static const dexReferenceItemEffect = '效果';
  static const dexReferenceNoEffect = '暂无说明';
  static String dexReferenceItemCost(String cost) => '售价 ¥$cost';
  static const dexReferenceTypeModifiers = '属性倍率变化';
  static const dexReferenceMovePowerSymbol = '⚔';
  static const dexReferenceMoveAccuracySymbol = '🎯';
  static const dexReferenceMovePpSymbol = 'PP';
  static String dexReferencePokemonCount(int count) => '共 $count 只宝可梦';
  static String dexFilterByEggGroup(String name) => '蛋群：$name';
  static const dexFilterClear = '清除筛选';
  static const dexFilterActive = '已启用图鉴筛选';
  static String dexFilterByMove(String name) => '招式 · $name';
  static String dexFilterByAbility(String name) => '特性 · $name';
  static String dexFilterMoveLabel(String name) => dexFilterByMove(name);
  static String dexFilterAbilityLabel(String name) => dexFilterByAbility(name);
  static const dexGameVersionHgss = '心金·魂银';
  static const dexGameVersionSv = '朱紫';
  static const dexGameVersionSwsh = '剑盾';

  static const settingsDexOffline = '离线图鉴缓存';
  static const settingsDexOfflineHint =
      '离线图鉴缓存包含以下内容（可在下方勾选要下载/保留的部分）。推荐先下载 CDN 预打包数据包；手绘导航图标仍随 APK 内置。';
  static const settingsDexOfflineBundledHint =
      '本安装包已内置当前 CDN 离线图鉴包（图鉴数据、中文对照、列表精灵图等）。首次启动会自动解压到本机，无需联网即可使用。';
  static const settingsDexOfflineBundledBadge = '已随 APK 内置 · 打开即用';
  static const settingsDexCacheContentsTitle = '缓存内容筛选';
  static const settingsDexCacheExpandHint = 'PokeAPI 备用下载时可勾选缓存项';
  static const settingsDexAdvancedOptions = '高级选项';
  static const settingsDexCacheOptionJson =
      '图鉴 JSON（摘要、详情、招式/特性/性格/天气/道具索引）';
  static const settingsDexCacheOptionSprites =
      '列表小图（按当前游戏版本世代，约 1025 张 × 单版本 ~25MB）';
  static const settingsDexCacheOptionSpritesAllVersions =
      '全版本小图（21 个版本组各一套，体积大，仅 Wi‑Fi 推荐）';
  static const settingsDexCacheOptionArtwork =
      '官方立绘大图（详情页查看，约 1025 张 ~80–120MB）';
  static const settingsDexCacheOptionAnimated =
      'Showdown 动图（PokeAPI GIF，约 1025 张 ~40–60MB）';
  static const settingsDexCacheOptionL10n =
      '中文对照表（物种/招式/特性/道具名、地点、HGSS 地图）';
  static const settingsDexCacheOptionTypeIcons = '属性图标（18 个，内置仓库资源）';
  static const settingsDexCacheOptionConfig =
      '应用配置（Sleep 工具链接、游戏版本图标索引等）';
  static String settingsDexCacheEstimate(String items) =>
      '预计体积（勾选合计）：$items';
  static const settingsDexOfflineUnset = '尚未下载离线数据包';
  static String settingsDexOfflinePartial(int pokemonCount) =>
      '部分缓存 $pokemonCount / $titodexMaxNationalDexId，可点「继续下载」补全';
  static String settingsDexOfflineReady(
    int pokemonCount,
    int moveCount,
    String size,
    String downloadedAt,
  ) => '已安装 $pokemonCount 只 · $moveCount 招式 · 含中文对照与配置 · $size · $downloadedAt';
  static const settingsDexOfflineDownload = '下载离线图鉴';
  static const settingsDexOfflineResume = '继续下载离线图鉴';
  static const settingsDexOfflineClear = '清除离线缓存';
  static const settingsDexOfflinePrefer = '优先使用离线缓存';
  static String settingsDexOfflineProgress(
    String phase,
    int current,
    int total,
  ) {
    final phaseLabel = switch (phase) {
      'types' => '属性',
      'pokemon' => '宝可梦',
      'cdn_manifest' => '图鉴包清单',
      'cdn_download' => '图鉴包下载',
      'cdn_verify' => '校验',
      'cdn_decompress' => '解压',
      'cdn_extract' => '写入',
      'apk_seed_manifest' => '内置包清单',
      'apk_seed_load' => '读取内置包',
      'apk_seed_verify' => '校验内置包',
      'apk_seed_decompress' => '解压内置包',
      'apk_seed_extract' => '写入内置包',
      'l10n_download' => '中文对照',
      'done' => '完成',
      'partial' => '部分完成',
      _ => phase,
    };
    return '正在缓存$phaseLabel $current / $total';
  }

  static const settingsDexCdnDownload = '下载预打包数据包';
  static const settingsDexCdnUpdate = '检查并更新预打包数据';
  static const settingsDexCdnDownloadHint =
      '推荐：一次性下载预打包数据包（图鉴 + 中文对照 + HGSS 地图 + 游戏图标 + 应用配置），安装后完全离线可用；无需逐条请求 PokeAPI。';
  static const settingsDexCdnUpdateHint =
      '内置包已可用。若日后有新版本，可联网检查并覆盖更新。';
  static const settingsDexOfflineDownloadPokeApi = '从 PokeAPI 下载（备用）';
  static const settingsDexDefaultGameVersion = '默认图鉴游戏版本';
  static const settingsDexDefaultGameVersionHint =
      '浏览图鉴详情与招式时使用的心金 / 朱紫 / 剑盾等版本组；列表小图默认展示该版本对应世代的游戏内像素图。';
  static const snackDexCdnDone = '预打包数据包已安装完成';
  static const snackDexCdnFailed = '预打包数据包下载失败';

  static const offlinePromptTitle = '下载离线图鉴数据';
  static const offlinePromptBody =
      '建议在设置中下载 CDN 预打包数据包，离线可用全国图鉴 1–1025、中文对照表与 HGSS 地图名。';
  static const offlinePromptLater = '稍后';
  static const offlinePromptGoSettings = '去设置';

  static const updateAvailableTitle = '图鉴数据有更新';
  static const updateAvailableBody =
      'CDN 上有较新的图鉴包或中文对照表，可在设置中下载更新。';
  static const updateAvailableLater = '稍后';
  static const updateAvailableGoSettings = '去设置';

  static const snackDexOfflineDone = '离线图鉴已下载完成';
  static String snackDexOfflinePartial(int count) =>
      '已缓存 $count / $titodexMaxNationalDexId 只宝可梦，可再次点击继续下载补全';
  static const snackDexOfflineCleared = '已清除离线图鉴缓存';
  static const snackDexOfflineClearedReseeded = '已清除并重新从安装包恢复离线图鉴';
  static const snackDexOfflineFailed = '离线图鉴下载失败';

  static const searchPlaceholder = '搜索全国图鉴：中文名、英文名、编号或属性…';
  static const searchPrompt = '搜索宝可梦';
  static const searchEmptyHint = '可搜索 1–1025 号宝可梦的中文名、英文名、编号或属性。';
  static const searchRecent = '最近搜索';
  static const searchTrending = '热门搜索';
  static const searchNoResults = '没有找到匹配的宝可梦。';
  static const searchHubSearch = '搜索';
  static const searchHubReference = '常用资料';
  static const searchHubBattle = '对战资料';
  static const searchHubGuideTitle = '指南';
  static const searchHubDataTitle = '资料列表';
  static const searchHubBattleTitle = '对战工具';
  static const searchHubBreedTitle = '培育工具';
  static const searchHubOnlineTitle = '在线资源';
  static const searchHubRegionalDex = '地区图鉴';
  static const searchRefNatures = '性格';
  static const searchRefEggGroups = '生蛋分组';
  static const searchRefItems = '道具';
  static const searchRefWeather = '天气';
  static const searchRefTerrains = '场地';
  static const searchRefStatus = '状态异常';
  static const searchRefPlaceholder = '资料加载中，请先下载预打包图鉴或检查网络。';
  static const searchBattleTypeMatchup = '属性克制';
  static const searchBattleStatCalc = '能力值计算';
  static const searchBattleQuickDamage = '伤害速算';
  static const searchOnlineShowdown = 'Showdown 网页版';
  static const searchOnlineUsage = '使用率排行';

  static const companionToolsTitle = '对战助手';
  static String companionToolsSubtitle(String gameTitle) =>
      '跟随当前游戏：$gameTitle';
  static String companionToolsFacility(String facility) =>
      '参考场景：$facility';
  static const companionToolDex = '打开图鉴';
  static const companionToolDexHint = '查种族值、属性、招式与克制关系';
  static const companionToolTypeMatchup = '属性克制速查';
  static const companionToolTypeMatchupHint = '选防守方属性，看弱点与抗性';
  static const companionToolStatCalc = '能力值计算';
  static const companionToolStatCalcHint = '等级、个体值、努力值与性格 → 实际数值';
  static String companionToolQuickDamageHint(String facility) =>
      '估算能不能秒 / 能不能扛（$facility 参考）';
  static const companionToolQuickDamage = '伤害速算';
  static const companionPokemonSearchHint = '搜索宝可梦…';
  static const companionLinkedTypes = '属性';
  static const companionTypeDefenderTitle = '防守方';
  static const companionTypeManualPick = '手动选择属性（最多 2 个）';
  static const companionTypeSummaryTitle = '克制摘要';
  static const companionTypeAttackerTitle = '进攻方（可选）';
  static const companionTypeAttackerPick = '攻击方属性（本系克制参考）';
  static const companionDefenderAbilityPick = '防守方特性（影响属性抗性）';
  static const companionAttackerAbilityPick = '进攻方特性（破免疫 / 皮肤 / 大力士等）';
  static const companionManualAbilityPick = '手动选特性（未搜宝可梦时）';
  static const companionWeatherPick = '天气';
  static const companionTerrainPick = '场地';
  static const companionTerastalToggle = '太晶化';
  static const companionTerastalType = '太晶属性';
  static const companionDefenderTerastal = '防守方太晶化';
  static const companionAttackerTerastal = '进攻方太晶化';
  static const companionHeldItemPick = '携带道具';
  static const companionTypeBoostItemType = '属性强化道具类型';
  static const companionStatusPick = '异常状态（攻击方）';
  static const companionContactMove = '接触类招式（毛茸茸等）';
  static const companionToolBlindSpot = '打击 / 联防盲点';
  static const companionToolBlindSpotHint = '本系打不动谁、谁克你';
  static const companionOffensiveBlindSpots = '打击盲点';
  static const companionDefensiveBlindSpots = '联防盲点';
  static const companionGenerationTypeNote = '属性按当前游戏世代修正（Gen 4/5 无妖精）';
  static String companionDamageExtra(String extra) => '环境/特性修正 ×$extra';
  static const companionStatInputsTitle = '输入';
  static String companionStatFacilityNote(String facility) =>
      '默认等级按 $facility 常见配置（Lv.50）';
  static const companionStatBase = '种族值';
  static const companionStatLevel = '等级';
  static const companionStatIv = '个体值';
  static const companionStatEv = '努力值';
  static const companionStatResultTitle = '计算结果';
  static const companionStatResultHint =
      '此为理论值；对战设施对手的实际数值可能含道具或强化。';
  static const companionDamageInputsTitle = '对战双方';
  static String companionDamageFacility(String facility) => '场景：$facility';
  static const companionAttackerSearchHint = '搜索进攻方宝可梦…';
  static const companionDefenderSearchHint = '搜索防守方宝可梦…';
  static const companionMoveType = '招式属性';
  static const companionMovePower = '招式威力';
  static const companionAttackStat = '攻击';
  static const companionSpAttackStat = '特攻';
  static const companionDefenseStat = '防御';
  static const companionSpDefenseStat = '特防';
  static const companionDefenderHp = '防守方 HP';
  static const companionDamageResultTitle = '估算结果';
  static String companionDamageRange(int min, int max) => '伤害 $min ~ $max';
  static String companionDamagePercent(double min, double max) =>
      '约占 HP ${min.toStringAsFixed(1)}% ~ ${max.toStringAsFixed(1)}%';
  static const companionDamageOffense = '进攻';
  static const companionDamageDefense = '防守';
  static String companionDamageModifiers(String type, String stab) =>
      '属性倍率 ×$type · 本系 ×$stab · 随机 85%–100%';

  static const recentTimeline = '最近动态';
  static const nextPrefix = '下一步：';
  static const journeyTimelineEmpty = '还没有旅程记录';

  static const teamNote = '队伍数据来自当前存档或演示旅程。后续可在这里编辑同行宝可梦。';
  static const teamEmptySlot = '空位';
  static String teamSubtitle(int count) => '同行 $count 只';
  static String teamSummaryAvgLevel(double avg) =>
      '平均 Lv ${avg.toStringAsFixed(1)}';
  static String teamSummaryBstSum(int sum) => '种族值合计 $sum';
  static String teamSummaryTypeCoverage(int count) => '属性覆盖 $count/18';
  static String teamSummaryWeaknesses(String types) => '常见弱点：$types';
  static String teamSummarySharedWeaknesses(String types) => '共同弱点（≥2 只）：$types';
  static const teamEditTitle = '编辑同行';
  static const teamEditLevel = '等级';
  static const teamEditNickname = '昵称';
  static const teamAddTitle = '添加宝可梦';
  static const teamAddByIdHint = '全国图鉴编号（1–1025）';
  static const teamAddPick = '从列表选择';
  static const teamAddInvalidId = '无效编号';
  static const confirm = '确定';
  static const cancel = '取消';
  static const sleepToolsMain = 'Neroli\'s Lab 主页';
  static const sleepToolsGuides = '攻略指南';
  static const sleepToolsDocs = '开发文档';
  static const sleepLinkCopied = '链接已复制到剪贴板';

  static const settingsTrainerProfile = '训练家资料';
  static const settingsGroupTrainer = 'Trainer';
  static const settingsGroupSaveSync = 'Save sync';
  static const settingsGroupAdvanced = 'Advanced';
  static const settingsDisplayName = '显示名称';
  static const settingsDisplayNameHint = 'Tito';
  static const settingsSaveTrainerName = '保存名称';
  static const settingsSaveTrainerHint = '民间汉化版的显示名可能与存档字节解码不同。';
  static String settingsSaveDecodeHint(String saveName) =>
      '存档标准解码：$saveName（汉化版可能显示不同）';

  static const settingsCurrentGame = '当前游戏';
  static const settingsLocation = '当前地点';
  static const settingsPlayTime = '游戏时间';
  static const settingsBadges = '徽章';
  static const settingsNextReminder = '下一步提醒';
  static const settingsEditJourney = '编辑旅程信息';
  static const settingsSaveJourneyEdits = '保存旅程信息';

  static const settingsJourneyData = '旅程数据';
  static const settingsImportSave = '导入内置 PKMSS.sav';
  static const settingsResetMock = '恢复演示数据';
  static const settingsExportJourney = '复制旅程 JSON';
  static const settingsImportJourney = '从 JSON 导入旅程';

  static const settingsEmulator = '模拟器';
  static const settingsEmulatorHint = '第一次点「继续」时也可以选择要启动的应用。';
  static const settingsEmulatorUnset = '未选择模拟器';
  static const settingsPickEmulator = '选择模拟器';
  static const settingsClearEmulator = '清除选择';
  static String settingsEmulatorSelected(String name) => '已选择：$name';

  static const settingsSaveDirectory = '存档目录';
  static const settingsSaveDirectoryHint =
      '选择 melonDS / Delta 等模拟器的存档文件夹，启动时自动读取最新的 .sav。';
  static const settingsSaveDirectoryUnset = '未设置';
  static const settingsPickSaveDirectory = '选择存档文件夹';
  static const settingsClearSaveDirectory = '清除目录';
  static const settingsAutoLoadOnStartup = '启动时自动加载最新存档';
  static const settingsSyncNow = '立即同步';
  static String settingsLastSynced(String fileName) => '上次同步：$fileName';
  static const settingsLastSyncedNone = '尚未从目录同步过存档';

  static const snackSaveDirectorySet = '存档目录已设置';
  static const snackSaveDirectoryCleared = '已清除存档目录';
  static const snackSaveSyncUnchanged = '存档未变化，无需更新';
  static const snackSaveSyncNoDirectory = '请先在设置中选择存档目录';
  static const snackSaveSyncNoSave = '目录中未找到 512 KB 的 .sav 文件';
  static const snackSaveSyncUnsupported = '找到的存档格式不受支持';
  static String snackSaveSyncLoaded(String fileName) => '已从 $fileName 同步存档';

  static const snackTrainerSaved = '训练家名称已保存';
  static const snackJourneySaved = '旅程信息已保存';
  static const snackJourneyExported = '旅程 JSON 已复制到剪贴板';
  static const snackJourneyImported = '已从 JSON 导入旅程';
  static String snackSaveLoaded(String name, int partyCount) =>
      '已加载 $name 的存档 · 队伍 $partyCount 只';
  static String snackSaveLoadedWarnings(int count) => '已加载存档（$count 条解析提示）';
  static const snackMockRestored = '已恢复演示旅程';

  static const continueSheetTitle = '继续旅程';
  static const continueSheetPickEmulator = '选择要启动的模拟器';
  static const continueSheetLaunch = '启动';
  static const continueSheetChange = '换一个';
  static const continueSheetNoEmulators = '未找到已安装的模拟器应用';
  static const continueSheetEmulatorLoadFailed = '读取已安装应用失败，请稍后重试';
  static const continueSheetDesktopHint = '模拟器启动目前仅支持 Android';
  static String continueSheetLaunching(String name) => '正在打开 $name…';
  static const snackEmulatorSaved = '已记住模拟器选择';
  static const snackEmulatorCleared = '已清除模拟器选择';
  static const snackEmulatorLaunchFailed = '无法启动该应用';

  static const snackAvatarConfirmAgain = '再次点击修改头像';
  static const snackAvatarUpdated = '头像已更新';
  static const snackAvatarFailed = '头像更换失败，请重试';
  static const avatarPickGallery = '从相册选择';
  static String snackGameSwitched(String gameTitle) => '已切换至 $gameTitle';

  static String placeholderScreen(String title) => '$title 页面开发中';
}
