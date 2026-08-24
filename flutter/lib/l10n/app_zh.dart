/// Simplified Chinese UI copy for TitoDex.
library;

import '../features/dex/dex_models.dart';

abstract final class AppZh {
  static const appTitle = 'TitoDex';
  static const bootstrapLoading = '正在准备你的旅程…';
  static const companionLoading = '正在加载对战数据…';
  static const progressDialogTitle = '正在处理…';
  static const snackDownloadCancelled = '下载已取消';
  static const searchLoading = '正在搜索…';
  static const referenceLoading = '正在加载资料…';

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

  static String trainerNameLine(String trainerName) {
    final name = trainerName.isNotEmpty ? trainerName : 'Tito';
    return '训练家 $name';
  }

  static const journeyCardTitle = '旅程';
  static const journeyOpenDetail = '查看旅程详情';
  static const journeyAssistantTitle = '存档助手';
  static const journeyAssistantMeta = '助手';
  static const journeyAssistantLoading = '整理中';
  static const journeyAssistantLoadFailed = '存档助手暂时无法读取地点或图鉴资料。';
  static const journeyAssistantNearbyTitle = '附近未捕获';
  static const journeyAssistantNearbyComplete = '当前地点的宝可梦已经捕获齐全。';
  static const journeyAssistantLocationUnknown =
      '存档地点暂时无法和地点图鉴匹配；可以进入地点图鉴手动查找。';
  static const journeyAssistantLocationDex = '打开地点图鉴';
  static const journeyAssistantPartyTitle = '队伍与进化';
  static const journeyAssistantPartyComplete = '当前队伍没有可识别的下一阶段进化提醒。';
  static const journeyAssistantVersionTitle = '版本补全';
  static const journeyAssistantPickVersion = '选择一个精确版本后，可区分配对版本的直接遭遇缺口。';
  static String journeyAssistantNearbyCount(int count) => '附近还有 $count 种未捕获';
  static String journeyAssistantEncounterGap(
    String version,
    String paired,
    int count,
  ) => '$version 中无直接遭遇、但 $paired 可直接遇到的未捕获宝可梦：$count 种';
  static String journeyAssistantEvolutionGap(int count) =>
      '当前版本另有 $count 种未捕获宝可梦需要进化、生蛋或交换取得';
  static String journeyAssistantEvolutionRoute(
    String from,
    String to,
    String trigger,
  ) => '$from → $to · $trigger';
  static const askTitoDexEntry = '卡住了？问 TitoDex';
  static const askTitoDexEntryHint = '按当前版本、地点和可靠存档进度查找下一步';
  static const askTitoDexTitle = '问 TitoDex';
  static const askTitoDexSubtitle = '旅程与通用问答 · 可选扩展资料';
  static const askTitoDexContextTitle = '发送前检查上下文';
  static const askTitoDexContextHint = '游戏版本始终保留；地点和徽章可点 × 移除。';
  static const askTitoDexLocationNotSent = '当前地点无法可靠匹配，因此不会发送。';
  static const askTitoDexGameUnknown = '版本未确认';
  static String askTitoDexBadgeContext(int count) => '已确认 $count 枚徽章';
  static const askTitoDexQuestionLabel = '你被什么挡住了？';
  static const askTitoDexQuestionHint = '例如：36号道路这棵树怎么过去？';
  static const askTitoDexSubmit = '查找下一步';
  static const askTitoDexLoading = '正在核对资料…';
  static const askTitoDexLocalAnswerLabel = '结构化资料 · 本地回答';
  static const askTitoDexOnlineAnswerLabel = '结构化资料 + AI 组织';
  static const askTitoDexWorkerChecking = '正在检查在线链路';
  static const askTitoDexWorkerOnline = 'Journey Assistant 已连接';
  static const askTitoDexWorkerDisabled = '在线 AI 已关闭';
  static const askTitoDexWorkerUnavailable = '当前仅可使用本地资料';
  static const askTitoDexWorkerRefresh = '重新检查连接';
  static const askTitoDexQwenConfigured = 'Qwen 已配置';
  static const askTitoDexAiSearchEnabled = 'AI Search 已开启';
  static const askTitoDexCuratedSourcesEnabled = '限定来源已开启';
  static const askTitoDexBraveNotConnected = '未接入 Brave Search';
  static const askTitoDexStatusDisabledHint = '可在设置中开启“在线 AI 回答”。';
  static const askTitoDexStatusUnavailableHint = 'Worker 未连接或暂时不可达，回答会安全回退到本地。';
  static const askTitoDexStatusOnlineHint =
      '百科与攻略来源已合并显示；完整允许名单和许可说明见设置里的“数据来源与许可”。连接状态只表示已配置，本次实际命中来源仍会显示在答案上。';
  static const askTitoDexRouteLocal = '审核资料 · 本地回答';
  static const askTitoDexRouteAuditedOnline = '审核资料 · Qwen 在线匹配';
  static const askTitoDexRouteAiSearch = 'R2 AI Search · Qwen 匹配';
  static const askTitoDexRouteCuratedDeterministic = '限定来源 · 确定性提取';
  static const askTitoDexRouteCuratedQwen = '限定来源 · Qwen 整理';
  static const askTitoDexTraceNoModel = '本次未调用 Qwen';
  static const askTitoDexTraceModel = 'Qwen 已参与';
  static const askTitoDexTraceAiSearch = 'AI Search 已命中';
  static String askTitoDexTraceSearchRoutes(int count) => '检索 $count 路';
  static const askTitoDexOnlineFallback = '在线链路失败，本次已回退到本地资料。';
  static const askTitoDexOnlineTimeoutFallback = '在线整理超时，本次已回退到本地资料。';
  static const askTitoDexOnlineSearchedNoMatch = '在线助手已查找，但没有足够可靠的答案。';
  static const askTitoDexUnknownWarning = '部分状态无法从当前存档解析，请按答案中的未知提示自行确认。';
  static const askTitoDexSources = '核验来源';
  static String askTitoDexSourceSummary(int count) => '参考 $count 个来源';
  static String askTitoDexEvidenceVerified(int count) => '已核验 · 参考 $count 个来源';
  static String askTitoDexEvidenceLowConfidence(int count) =>
      '低置信度 · 参考 $count 个来源';
  static const askTitoDexEvidenceLocalVerified = '本地资料已核验';
  static const askTitoDexEvidenceUnverified = '低置信度 · 尚无可展开引用';
  static const askTitoDexSourceSheetTitle = '回答引用';
  static const askTitoDexSourceSheetHint = '这些页面用于生成或核验本条回答，点击即可打开原始链接。';
  static const askTitoDexSourceLinkUnavailable = '这个引用链接暂时无法打开。';
  static const askTitoDexSourceLinkInvalid = '链接不可用';
  static const askTitoDexNeedsClarification = '请补充游戏版本或具体地点。';
  static const askTitoDexTimeout = '在线整理超时了。旅程和存档没有受到影响，可以重试。';
  static const askTitoDexNetworkFailed = '在线服务暂时不可用。旅程仍可离线使用，请稍后重试。';
  static const askTitoDexNoticeTitle = '开启问 TitoDex？';
  static const askTitoDexNoticeBody =
      '这个助手默认关闭。确认开启后，TitoDex 仍会优先使用 App 内的本地资料；本地不足时才会连接 Journey Worker，并可能使用 AI Search、Workers AI（Qwen）、限定来源联网检索与 DeepSeek 来整理答案。请求只包含你确认后的游戏版本、可靠的地点/徽章/里程碑 ID、语言、解析器版本、本次问题，以及同一游戏最近最多 6 组问答用于理解追问。最近 50 组问答只保存在本机，超出会自动删除最早一组。不会上传原始存档、训练家姓名、ID、金钱、队伍或个体数据。你之后可单独关闭在线回答，或关闭整个助手并隐藏所有入口。';
  static const askTitoDexNoticeAccept = '确认开启';
  static const settingsAskTitoDex = '允许在线 AI 与检索';
  static const settingsAskTitoDexHint =
      '本地资料无法回答时才连接 Journey Worker；关闭后助手仍可使用内建离线答案。';
  static const extensionJourneyTitle = '旅程助手';
  static const extensionBuiltIn = '主 App 内建';
  static const extensionBuiltInHint =
      '默认关闭；确认后才启用。关闭时 Journey 与 Search 不显示入口，也不预留位置。';
  static const extensionNotInstalled = '未安装';
  static const extensionInstallHint = '按需从 TitoDex 扩展目录下载；Android 会显示系统安装确认。';
  static const extensionInstall = '下载并安装';
  static const extensionInstalling = '正在准备扩展…';
  static const extensionCheckUpdate = '检查并安装扩展更新';
  static const extensionUpToDate = '旅程助手扩展已是最新版本';
  static const extensionCatalogUnavailable = '此版本未配置扩展下载目录，可继续使用现有离线功能。';
  static const extensionInstallStarted = '已交给 Android，请在系统页面确认安装';
  static const extensionInstallFailed = '扩展安装未能开始，请稍后再试';
  static const extensionInstalled = '已安装';
  static const extensionEnabled = '启用问 TitoDex 助手';
  static const extensionUninstall = '卸载扩展';
  static const extensionUninstallHint = '将打开 Android 系统卸载确认页面。';
  static const extensionOnlineTitle = '旅程助手与在线功能';
  static const extensionSearchDisplay = '在搜索页显示';
  static const extensionSearchProminent = '重点显示';
  static const extensionSearchCompact = '紧凑显示';
  static const extensionSearchHidden = '不显示';
  static const extensionSearchAsk = '通用问答';
  static const extensionSearchAskHint = '不读取原始存档；可按当前选择的游戏版本查询扩展资料。';
  static const emulatorContinueHint = '从模拟器继续';
  static const partySaveDiffBanner = '与最新存档不同 · 点击同步';
  static const partySaveDiffDismiss = '不再提示本次差异';
  static const partySaveSyncConfirm = '用存档队伍覆盖当前编辑？';
  static const settingsChangeAvatar = '更换头像';
  static const settingsJourneyReadOnly = '旅程信息（来自存档）';
  static const settingsTrainerId = '训练家 ID';
  static const settingsTrainerSecretId = '隐藏 ID';
  static const settingsTrainerGender = '训练家性别';
  static const settingsSaveLanguage = '存档语言';
  static const settingsSaveMoney = '随身资金';
  static const settingsMotherMoney = '妈妈保管';
  static const settingsStarter = '最初的伙伴';
  static const settingsMapCoordinates = '地图坐标';
  static const settingsJourneyStarted = '旅程开始';
  static const settingsLeagueChampion = '首次通关';
  static const settingsDexProgress = '图鉴进度';
  static const teamSummaryTitle = '队伍概览';
  static const sleepToolsTitle = 'Pokémon Sleep 工具';
  static const sleepToolsTierAHint = '内置离线试算，并保留 Neroli’s Lab 资料入口';
  static const sleepToolsOpen = '打开睡眠与料理试算';
  static const sleepToolsOpenHint = '睡眠分数 · 食材基础能量 · 食谱等级加成';
  static const sleepToolsSubtitle = '离线小工具 · 不读取 Pokémon Sleep 账号或记录';
  static const sleepScoreTitle = '睡眠分数';
  static const sleepScoreHint = '按入睡与起床时间估算；8 小时 30 分达到 100 分。';
  static const sleepBedtime = '入睡时间';
  static const sleepWakeup = '起床时间';
  static String sleepDurationResult(int hours, int minutes) =>
      '睡眠时长 $hours 小时 $minutes 分钟';
  static const sleepRecipeTitle = '料理能量试算（基础）';
  static const sleepRecipeHint = '添加本次食材并设置食谱等级；这是透明的基础公式，不包含完整食谱、锅容量或队伍生产模拟。';
  static const sleepIngredientAdd = '点击添加食材（名称 · 单个基础能量）';
  static const sleepIngredientEmpty = '尚未添加食材。';
  static const sleepIngredientDecrease = '减少一个';
  static const sleepIngredientIncrease = '增加一个';
  static String sleepRecipeLevel(int level) => '食谱等级 · Lv $level';
  static const sleepRecipeBonus = '食谱固有加成（%）';
  static String sleepRecipeEnergy(int value) => '通常料理能量 · $value';
  static String sleepRecipeBreakdown(int base, double level, int bonus) =>
      '食材 $base × 等级 ${level.toStringAsFixed(2)} × 固有加成 ${100 + bonus}%';
  static String sleepRecipeCrit(int weekday, int sunday) =>
      '大成功参考：平日 2 倍 $weekday · 周日 3 倍 $sunday';
  static const sleepSourceTitle = '公式与范围';
  static const sleepSourceBody =
      '睡眠分数、19 种食材基础能量、1–70 级食谱倍率与料理公式移植自 Neroli’s Lab 固定提交 cb533f2，依 Apache-2.0 使用并在 App 许可证页完整署名。中文食材名参考神奇宝贝百科。完整配队、食材生产与长期模拟仍请使用 Neroli’s Lab。';
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

  static const dexScopeNote = '全国图鉴 1–1025，中文名与属性来自在线图鉴；已捕获/已见过状态来自存档与同行队伍。';
  static const dexCaught = '已捕获';
  static const dexSeen = '已见过';
  static const dexUnknown = '未见过';
  static const dexFilterAll = '全部';
  static const dexFilterCaught = '已捕获';
  static const dexFilterSeen = '已见过';
  static const dexFilterUnseen = '未见过';
  static String dexScopeProgress(
    int caught,
    int seen,
    int total, {
    int? evolutionOrTrade,
  }) =>
      '捕获 $caught · 见过 $seen'
      '${evolutionOrTrade == null ? '' : ' · 交换/进化 $evolutionOrTrade'} / $total';
  static const dexTabNational = '全国图鉴';
  static String dexRegionalDexTitle(String regionLabel) => '$regionLabel图鉴';
  static const dexPickRegionalPokedex = '选择地区图鉴';
  static const dexPickBrowseScope = '选择图鉴范围';
  static const dexBrowseByRegion = '按地区';
  static const dexBrowseByRegionHint = '全国、关东、城都及其他地区图鉴';
  static const dexBrowseByGeneration = '按世代';
  static const dexBrowseByGenerationHint = '按首次登场世代筛选 G1–G9';
  static const dexGenerationDebutHint = '按首次登场世代统计';
  static const dexTabJourney = '旅程同行';
  static const dexFilterEmpty = '当前筛选条件下暂无图鉴条目。';
  static String dexRegionProgress(
    int startId,
    int endId,
    int seen,
    int caught,
    int total,
  ) => '#$startId–$endId · 已见 $seen / 已捕 $caught / 共 $total';
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
      'PokeAPI 请求失败（HTTP $statusCode）。请检查网络，或在设置中下载离线资料包后重试。';
  static const errorGeneric = '加载失败，请稍后重试。';
  static const errorFormatDetail = '数据格式异常，请检查网络后重试，或下载离线资料包。';
  static const dexRetry = '重试';
  static const dexHeight = '身高';
  static const dexWeight = '体重';
  static const dexWeaknesses = '弱点（受到 ×2）';
  static const dexResistances = '抗性（受到 ×0.5）';
  static const dexImmunities = '免疫（受到 ×0）';
  static const dexStabEffective = '本系克制（打出 ×2）';
  static const dexEvolution = '进化链';
  static const dexObtainLocations = '出现地点';
  static const dexObtainEmpty = '当前版本未收录该宝可梦的野外遭遇数据（可能需进化、交换、赠送，或不可野生捕获）。';
  static const dexFlavorEnglishNote = '该世代暂无官方中文描述，以下为英文原文。';
  static const dexFlavorZhFallbackNote = '心金/魂银世代无中文图鉴文案，以下为近世代中文译名供参考。';
  static const dexNone = '无';
  static const dexApiNote = '数据主要来自 PokeAPI；属性、招式与获取方式会随所选游戏版本切换，仅供资料查询。';
  static const dexFormStatusMega = '超级进化';
  static const dexFormStatusBattleOnly = '对战限定';
  static const dexFormStatusNotObtainable = '不可常驻';
  static const dexFormStatusCosmetic = '外观';
  static const dexFormStatusPartial = '资料不完整';
  static const dexFormStatusUnavailableHere = '当前版本不可用';
  static const dexFormStatusNotObtainableHere = '当前版本不可常驻获得';
  static const dexFormStatusEventOnly = '活动限定';
  static const dexFormStatusDeprecated = '历史形态';
  static String dexFormIntroducedIn(String game) => '初次登场：$game';

  static const settingsAttributionTitle = '关于 TitoDex · 数据来源与许可';
  static const settingsAttributionHint = '非官方学习工具 · 查看完整 Credits 与权利说明';
  static const settingsOpenSourceLicenses = '查看开源许可证';
  static const settingsUnofficialNotice =
      '非官方学习工具：与 Nintendo、Creatures、GAME FREAK、The Pokémon Company 无隶属、授权、赞助或认可关系。';
  static const settingsAttributionBody =
      'TitoDex 是非官方、非商业、仅面向学习与个人游玩辅助的工具，与 Nintendo Co., Ltd.、Creatures Inc.、GAME FREAK inc.、The Pokémon Company 及其关联公司不存在隶属、授权、赞助或认可关系。Pokémon、宝可梦、角色、游戏名称、图像、音频与商标归各自权利人所有；本工具不提供 ROM、密钥、付费内容或存档修改。\n\n'
      '资料与文字：PokéAPI（物种、形态、招式、特性、道具、版本与基础地点；数据／代码仓库 BSD-3-Clause）、52Poké Wiki／神奇宝贝百科（部分中文说明、携带道具、地点与体形；百科原创内容 CC BY-NC-SA 3.0）、Bulbapedia（道具分组与少量地点语言链接；CC BY-NC-SA 2.5）、PKHeX（固定提交导出的现代遭遇覆盖；GPL-3.0-or-later，App 不嵌入或执行）、Project Pokémon（HGSS 存档／PKM 结构与地图编号技术参考）。\n\n'
      '问 TitoDex 的限定联网来源：中文检索优先 52Poké Wiki；没有足够可靠的结果时，才回退到 Pokémon 官方网站、Bulbapedia、StrategyWiki、Serebii、PokéAPI、Wikidata、Pokémon Database、Smogon、Marriland、GameFAQs、Game8、IGN、Nintendo Life 与 Eurogamer。联网摘要只用于当次回答与引用核验，不会自动写入 R2、AI Search、APK 或本地图鉴包；各站内容仍适用其自身条款与权利说明。Tavily 与 DeepSeek 是检索／生成服务，不是百科内容权利人。\n\n'
      '媒体：PokéAPI/sprites、Pokémon Showdown／Smogon 社区创作者、PokéSprite 类型图标（MIT）、SteamGridDB 社区来源页、Pokémon HOME 与各代游戏的官方图像／音频；Nunito 字体依 SIL OFL 1.1 随包分发。百科开放许可不自动覆盖其中的官方游戏媒体，各素材仍按记录级来源与原权利状态处理。\n\n'
      '外部工具：Pokémon Sleep 二级页的睡眠分数、19 种食材数值、食谱等级倍率与料理能量公式移植自 Neroli’s Lab 固定提交 cb533f2，依 Apache-2.0 使用并随 App 提供许可证与 NOTICE；完整配队和长期模拟仍保留为外部入口。\n\n'
      '来源入口：pokemon.com · wiki.52poke.com · bulbapedia.bulbagarden.net · strategywiki.org · serebii.net · pokeapi.co · wikidata.org · pokemondb.net · smogon.com · marriland.com · gamefaqs.gamespot.com · game8.co · ign.com · nintendolife.com · eurogamer.net · github.com/PokeAPI/sprites · github.com/msikma/pokesprite · github.com/kwsch/PKHeX · projectpokemon.org · pokemonshowdown.com · steamgriddb.com · nerolislab.com。固定提交、逐文件来源和构建批次说明见项目根目录 CREDITS.md、THIRD_PARTY_NOTICES.md 及数据包随附 attribution 文件。';
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
  static const dexAbilityPlaceholder = '特性资料整理中，将随后续离线资料包更新。';
  static const dexAbilityEmptyPending = '暂无特性数据。';
  static const dexBaseHappiness = '初始亲密度';
  static const dexCaptureRate = '捕获率';
  static const dexEvYield = '基础点数 (EV)';
  static const dexObtainEmptyVersion = '暂无野外出现地点（可能为进化、赠送或不可野生捕获）。';
  static const dexObtainExactVersion = '精确版本';
  static const dexObtainCombinedVersions = '版本合并';
  static const dexWildHeldItems = '野生携带道具';
  static const dexWildHeldItemsHint = '概率按当前选择的版本分别显示。';
  static const dexChainPlanningTitle = '当前版本集齐规划';
  static const dexChainPlanningPickVersion = '选择一个精确版本后，可判断这条进化链能否单版本集齐。';
  static const dexChainPlanningLoading = '正在整理这条进化链的获得方式…';
  static const dexChainPlanningUnavailable = '暂时无法读取这条进化链的版本资料。';
  static String dexChainSelfContained(String version) => '$version可独立集齐这条进化链';
  static const dexChainTradeRequired = '需要通讯交换才能集齐这条进化链';
  static String dexChainUnavailable(String version) => '$version无法独立集齐这条进化链';
  static const dexChainMethodCatch = '直接捕获';
  static const dexChainMethodEvolve = '进化获得';
  static const dexChainMethodTrade = '需要通讯交换';
  static const dexChainMethodBreed = '生蛋获得';
  static const dexChainMethodUnavailable = '当前版本无获得路径';
  static const dexVersionBoth = '版本限定：配对版本均可直接遇到';
  static String dexVersionOnlyThis(String version) => '版本限定：仅$version可直接遇到';
  static String dexVersionOnlyOther(String version) => '版本限定：可在$version捕获后交换';
  static const dexVersionNeither = '配对版本均无直接遭遇，通常需要进化、赠送或活动获得';
  static const dexFilterEvolutionOrTrade = '待进化';
  static const dexFilterCalculating = '整理中';
  static const dexEvolutionOrTradeLoading = '正在整理交换/进化缺口…';
  static String dexObtainForGame(String gameLabel) => '$gameLabel 出现地点';
  static String dexObtainScope(String gameLabel) => '以下出现地点：$gameLabel';
  static const dexFlavorNoEdition = '当前版本暂无图鉴描述';
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
  static const dexGrowthRate = '经验组';
  static const dexBaseExperience = '基础经验值';
  static const dexHabitat = '栖息地';
  static const dexGenderDifferences = '性别外观差异';
  static const dexGenderDifferencesYes = '有';
  static const dexSpeciesAxes = '体形 · 颜色 · 大小';
  static String dexShapeBeforeGen6(String label) => '$label（六代前）';
  static const dexHatchSteps = '孵化步数';
  static const dexNoEvolution = '没有进化链记录。';
  static const dexMovesHgssScope = '以下招式范围：心金 / 魂银';
  static String dexMovesScope(String gameLabel) => '以下招式范围：$gameLabel';
  static String dexDataFallbackNote(String gameLabel) =>
      '当前游戏暂无此数据，以下来自：$gameLabel';
  static const dexFormDataInherited = '该形态暂无独立资料，以下数据沿用默认形态。';
  static const dexFormDataPartial = '该形态资料不完整，部分战斗数据缺失或沿用默认形态。';
  static const dexBaseStatsRadar = '能力雷达';
  static const dexBaseStatsBars = '种族值条';
  static const dexReferenceTitle = '常用资料';
  static const dexReferenceMoves = '招式图鉴';
  static const dexReferenceAbilities = '特性图鉴';
  static const dexReferenceSearchHint = '搜索名称或编号…';
  static const dexReferenceEmpty = '没有匹配的资料条目。';
  static const dexReferenceDataMissing = '当前数据包中没有这条资料，请更新资料后重试。';
  static const dexReferenceUnavailableInGame = '当前版本不可用';
  static const dexReferenceScopeUnknown = '当前版本的资料范围尚未确认';
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
  static String dexReferenceItemCost(String cost) => '参考价格 ₽$cost';
  static const dexReferenceTypeModifiers = '属性倍率变化';
  static const dexReferenceMovePowerSymbol = '⚔';
  static const dexReferenceMoveAccuracySymbol = '🎯';
  static const dexReferenceMovePpSymbol = 'PP';
  static String dexReferencePokemonCount(int count) => '共 $count 只宝可梦';
  static String dexFilterByEggGroup(String name) => '蛋群：$name';
  static const dexFilterClear = '清除筛选';
  static const dexFilterActive = '已启用图鉴筛选';
  static const dexSpeciesFilterOpen = '体形筛选';
  static const dexSpeciesFilterTitle = '按体形 · 颜色 · 大小筛选';
  static const dexSpeciesFilterShape = '体形';
  static const dexSpeciesFilterShapeHint = '图标对应游戏内图鉴 / Pokémon HOME 的体形检索';
  static const dexSpeciesFilterColor = '颜色';
  static const dexSpeciesFilterColorHint = '可多选：图鉴配色没有橙色，橙色系请同时选「棕」和「红」';
  static const dexSpeciesFilterSize = '大小';
  static const dexSpeciesFilterSizeHint = '按身高分档，与图鉴检索里的大小轴一致';
  static const dexSpeciesFilterReset = '重置';
  static const dexSpeciesFilterApply = '查看结果';
  static String dexFilterByMove(String name) => '招式 · $name';
  static String dexFilterByAbility(String name) => '特性 · $name';
  static String dexFilterMoveLabel(String name) => dexFilterByMove(name);
  static String dexFilterAbilityLabel(String name) => dexFilterByAbility(name);
  static const dexGameVersionHgss = '心金·魂银';
  static const dexGameVersionSv = '朱紫';
  static const dexGameVersionSwsh = '剑盾';

  static const settingsDexOffline = '离线资料包';
  static const settingsDexOfflineHint =
      '完整离线资料包可一次安装全国图鉴与形态、进化链、招式、特性、道具等资料，以及中文对照、地图、图片和应用配置。';
  static const settingsDexAdvancedOptions = '高级选项';
  static const settingsDexOfflineUnset = '尚未下载离线资料包';
  static String settingsDexOfflinePartial(int pokemonCount) =>
      '部分缓存 $pokemonCount / $titodexMaxNationalDexId，可点「继续下载」补全';
  static const settingsDexVerify = '校验离线数据';
  static const settingsDexVerifyRunning = '正在校验…';
  static const settingsDexVerifyNoData = '尚未安装离线资料包，无需校验。';
  static String settingsDexVerifyOk(int pokemonCount) =>
      '校验通过：$pokemonCount 只宝可梦的离线资料完整。';
  static String settingsDexVerifyProblems(int missingDetails) =>
      '发现问题：缺失 $missingDetails 份详情资料，建议重新下载数据包。';
  static const settingsDexVerifyIncomplete =
      '离线数据不完整（下载未完成或索引缺失），建议继续或重新下载数据包。';
  static String settingsDexVerifySpriteNote(int missingSprites) =>
      '另有 $missingSprites 张图片缺失（在线时会自动回退加载）。';
  static String settingsDexOfflineReady(
    int pokemonCount,
    int moveCount,
    String size,
    String downloadedAt,
  ) =>
      '已安装 $pokemonCount 只 · $moveCount 招式 · 含完整资料库与图片 · $size · $downloadedAt';
  static const settingsDexOfflineDownload = '下载离线资料包';
  static const settingsDexOfflineResume = '继续下载离线资料包';
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
      'cdn_manifest' => '获取数据包清单',
      'cdn_download' => '下载数据包',
      'cdn_verify' => '校验数据包',
      'cdn_decompress' => '解压数据包',
      'cdn_extract' => '写入离线数据',
      'cdn_index' => '准备筛选索引',
      'apk_seed_manifest' => '准备清单',
      'apk_seed_read' => '读取内置数据包',
      'apk_seed_verify' => '校验内置数据包',
      'apk_seed_decompress' => '解压',
      'apk_seed_extract' => '写入',
      'apk_seed_index' => '准备筛选索引',
      'index' => '准备筛选索引',
      'l10n_download' => '中文对照',
      'done' => '完成',
      'partial' => '部分完成',
      _ => phase,
    };
    final isBundlePhase =
        phase.startsWith('cdn_') || phase.startsWith('apk_seed_');
    final verb = isBundlePhase ? '正在' : '正在缓存';
    final showCount =
        phase != 'cdn_download' &&
        phase != 'cdn_manifest' &&
        phase != 'cdn_verify' &&
        phase != 'cdn_decompress' &&
        phase != 'cdn_index' &&
        phase != 'apk_seed_manifest' &&
        phase != 'apk_seed_read' &&
        phase != 'apk_seed_verify' &&
        phase != 'apk_seed_decompress' &&
        phase != 'apk_seed_index' &&
        phase != 'done';
    return '$verb$phaseLabel${showCount ? ' $current / $total' : ''}';
  }

  static const offlineSeedProgressTitle = '正在准备离线资料包';

  static const settingsDexCdnDownload = '下载完整离线资料包';
  static const settingsDexCdnDownloadHint =
      '推荐：一次性下载完整离线资料包，包含全国图鉴与形态、进化链、招式、特性、道具等资料，以及中文对照、地图、图片和应用配置；下载完成后可离线使用。';
  static const settingsDexBackgroundDownload = '后台下载';
  static const settingsDexCancelDownload = '取消下载';
  static const snackDexBackgroundDownload = '已转到后台，可从通知栏查看进度';
  static const snackDexBackgroundDownloadNoNotification =
      '已转到后台；通知权限未开启，可返回设置查看进度';
  static const snackDexBackgroundDownloadFailed = '无法启动后台下载，请保持 TitoDex 在前台';
  static const dexDownloadNotificationTitle = '正在准备离线资料包';
  static const dexDownloadNotificationDoneTitle = '离线资料包已准备完成';
  static const dexDownloadNotificationDoneBody = '现在可以离线使用完整图鉴与资料库';
  static const dexDownloadNotificationPartialTitle = '离线资料包已部分完成';
  static const dexDownloadNotificationPartialBody = '返回 TitoDex 可继续补全剩余资料';
  static const dexDownloadNotificationFailedTitle = '离线资料包准备失败';
  static const dexDownloadNotificationFailedBody = '返回 TitoDex 后可重新下载';
  static const settingsDexOfflineDownloadPokeApi = '从 PokeAPI 下载（备用）';
  static const settingsDexDefaultGameVersion = '默认图鉴游戏版本';
  static const settingsDexDefaultGameVersionHint =
      '浏览图鉴详情与招式时使用的心金 / 朱紫 / 剑盾等版本组；列表小图默认展示该版本对应世代的游戏内像素图。';
  static const snackDexCdnDone = '完整离线资料包已安装完成';
  static const snackDexCdnFailed = '完整离线资料包下载失败';

  static const offlinePromptTitle = '下载完整离线资料包';
  static const offlinePromptBody =
      '建议下载完整离线资料包，包含全国图鉴与形态、进化链、招式、特性、道具等资料，以及中文对照、地图、图片和应用配置。';
  static const offlinePromptLater = '稍后';
  static const offlinePromptGoSettings = '去设置';

  static const updateAvailableTitle = '离线资料有更新';
  static const updateAvailableBody = '有较新的完整离线资料包，可在设置中下载更新。';
  static const updateAvailableLater = '稍后';
  static const updateAvailableGoSettings = '去设置';

  static const snackDexOfflineDone = '离线资料包已下载完成';
  static String snackDexOfflinePartial(int count) =>
      '已缓存 $count / $titodexMaxNationalDexId 只宝可梦，可再次点击继续下载补全';
  static const snackDexOfflineCleared = '已清除离线资料包缓存';
  static const snackDexOfflineFailed = '离线资料包下载失败';

  static const searchPlaceholder = '搜索全国图鉴：中文名、英文名、编号或属性…';
  static const searchPrompt = '搜索宝可梦';
  static const searchEmptyHint =
      '可搜索 1–1025 号宝可梦的中文名、英文名、编号、分类或属性。空格分隔可叠加条件，如「四足 棕」。';
  static const searchSuggestionTitle = '试试这些';
  static const searchRecent = '最近搜索';
  static const searchRecentClear = '清空';
  static const settingsSwitchGame = '更换';
  static String dexFlavorZhReference(String source) => '中文参考 · 来自$source：';
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
  static const locationDexTitle = '地点图鉴';
  static const locationDexHint = '按当前游戏版本查看每个地点会遇到的宝可梦；展开地点即可核对捕获完成度。';
  static const locationDexSearchHint = '搜索地点或宝可梦';
  static const locationDexLoadFailed = '地点资料暂时无法载入，请检查离线资料包或网络。';
  static const locationDexEmpty = '当前版本没有匹配的地点资料。';
  static String locationDexCompletion(int caught, int total) =>
      '已捕获 $caught / $total';
  static const searchRefPlaceholder = '资料加载中，请先下载完整离线资料包或检查网络。';
  static const searchBattleTypeMatchup = '属性克制';
  static const searchBattleStatCalc = '能力值计算';
  static const searchBattleQuickDamage = '伤害速算';
  static const searchOnlineShowdown = 'Showdown 网页版';
  static const searchOnlineUsage = '使用率排行';

  static const companionStandbyLabel = '同行宝可梦';
  static const companionPickerTitle = '选择同行宝可梦';
  static const companionPickerHint = '选中后会按需下载它的动图，不占安装包体积。';
  static const companionPickerSearchHint = '搜索中文名、英文名或编号…';
  static String companionPicked(String name) => '$name 加入同行！';
  static String companionFriendship(String name) => '$name 的好感度爆棚了！❤';
  static const companionSettingsTitle = '同行宝可梦';
  static const companionSettingsHint = '它会以动图形式待在主页右下角，点它有惊喜。';
  static const companionSettingsToggle = '在主页显示同行宝可梦';
  static const companionSettingsSize = '同行大小';
  static String companionMediaTitle(String name) => '准备 $name 中…';
  static const companionMediaGif = '载入动图';
  static const companionMediaCry = '载入叫声';
  static const companionMediaFailedHint = '部分资源载入失败，将使用静态图或稍后重试。';
  static const settingsGroupAdvancedHint = '内置存档导入、旅程 JSON 导入/导出与重置';
  static const settingsGroupInterface = '界面风格';
  static const settingsRetroStyle = 'Material 表面层次';
  static const settingsRetroStyleHint = '开启后卡片使用轻量高度；关闭后改为描边表面，按钮仍保留原生状态反馈。';
  static const settingsListAnimations = '列表渐入动画';
  static const settingsListAnimationsHint = '图鉴、搜索、常用资料等列表的渐入小动画；关闭后内容会立即显示。';
  static const settingsAppShortcuts = '桌面快捷入口';
  static const settingsAppShortcutsHint = '默认显示图鉴和搜索；可替换或补充下方任意资料与工具，最多三个。';
  static const settingsAppShortcutsLimit = '最多只能选择三个快捷入口。';
  static const settingsAppShortcutsCustomize = '自定义快捷入口';
  static const settingsAppShortcutsReset = '恢复默认';
  static const settingsAppShortcutsNone = '当前不显示快捷入口';
  static const companionSettingsPick = '更换同伴';
  static const companionSettingsReset = '恢复默认（随存档御三家）';
  static const companionSettingsPosition = '调整位置';
  static const companionPositionTitle = '调整同行位置';
  static const companionPositionHint = '拖拽下方预览里的图标到你想让同行宝可梦停留的位置。';
  static const companionPositionReset = '恢复默认位置';
  static String shinyPartyFound(String name) => '✨ 你的 $name 今天在闪光！';
  static const quizTitle = '猜猜我是谁';
  static const quizEntryHint = '剪影问答';
  static const quizPrompt = '这只宝可梦是谁？';
  static const quizNext = '下一题';
  static const quizCorrect = '答对了！';
  static String quizWrong(String name) => '是 $name 才对！';
  static String quizScore(int correct, int total) => '战绩 $correct / $total';
  static String quizStreak(int streak) => '连对 $streak';
  static String quizBestStreak(int streak) => '最佳连对 $streak';
  static const quizAdoptCompanion = '设为同行';
  static String quizAdopted(String name) => '$name 现在陪你同行啦！';

  static const companionToolsTitle = '对战助手';
  static String companionToolsSubtitle(String gameTitle) => '跟随当前游戏：$gameTitle';
  static String companionToolsFacility(String facility) => '参考场景：$facility';
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
  static const companionCriticalHit = '击中要害';
  static const companionDefenderScreen = '对方有光墙/反射壁';
  static const companionSpreadMove = '双打·多目标招式';
  static const companionStatApplyAttack = '带入伤害计算（攻击侧）';
  static const companionStatApplyDefense = '带入伤害计算（防御侧）';
  static const companionStatApplyHp = '带入伤害计算（对方 HP）';
  static const companionDamageAssumptions =
      '计算假设：默认单打；勾选「双打·多目标招式」后按命中多个目标 ×0.75 计算；'
      '伤害含 85%–100% 随机浮动；'
      '击中要害按世代倍率（第六世代起 ×1.5，此前 ×2）并无视光墙/反射壁；'
      '按一次命中的固定威力招式估算，不处理固定伤害、连续攻击、动态威力或招式专属效果；'
      '未收录的特性、道具与场地细节不计入，结果仅供旅途参考。';
  static const companionStatInputsTitle = '输入';
  static String companionStatFacilityNote(String facility) =>
      '默认等级按 $facility 常见配置（Lv.50）';
  static const companionStatBase = '种族值';
  static const companionStatLevel = '等级';
  static const companionStatIv = '个体值';
  static const companionStatEv = '努力值';
  static const companionStatResultTitle = '计算结果';
  static const companionStatResultHint = '此为理论值；对战设施对手的实际数值可能含道具或强化。';
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
  static String teamSummarySharedWeaknesses(String types) =>
      '共同弱点（≥2 只）：$types';
  static const teamEditTitle = '编辑同行';
  static const teamEditLevel = '等级';
  static const teamEditNickname = '昵称';
  static const teamEditTypes = '属性';
  static const teamEditAbility = '特性';
  static const teamEditDelete = '移出队伍';
  static const teamEditSwapPrev = '与前一位交换';
  static const teamEditSwapNext = '与后一位交换';
  static const teamAddTitle = '添加宝可梦';
  static const teamAddInvalidId = '无效编号';
  static const confirm = '确定';
  static const cancel = '取消';
  static const retry = '重试';
  static const sleepToolsMain = 'Neroli\'s Lab 主页';
  static const sleepToolsGuides = '攻略指南';
  static const sleepToolsDocs = '开发文档';
  static const sleepLinkCopied = '链接已复制到剪贴板';

  static const settingsGroupTrainer = '训练家';
  static const settingsGroupSaveSync = '存档同步';
  static const settingsGroupAdvanced = '高级';
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

  static const settingsSaveFileHint =
      '选择一个具体的 .sav 存档文件。TitoDex 只会保存并重读这个文件，不会扫描任何文件夹。';
  static const settingsSaveFileUnset = '尚未选择存档文件';
  static const settingsPickSaveFile = '选择 .sav 存档文件';
  static String settingsSelectedSaveFile(String name) => '已选择文件：$name';
  static const settingsClearSaveFile = '清除所选存档文件';
  static const settingsAutoLoadOnStartup = '启动时自动重读所选存档';
  static const settingsSyncNow = '立即同步';
  static String settingsLastSynced(String fileName) => '上次同步：$fileName';
  static const settingsLastSyncedNone = '尚未读取所选存档';

  static const snackSaveFileSet = '存档文件已选择并解析';
  static const snackSaveFileCleared = '已清除所选存档文件';
  static const snackSaveSyncUnchanged = '存档未变化，无需更新';
  static const snackSaveSyncNoFile = '请先在设置中选择一个 .sav 存档文件';
  static const snackSaveFileUnavailable = '无法再次读取所选存档，请重新选择文件';
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
  static const continueSheetPickEmulator = '选择要启动的应用';
  static const continueSheetLaunch = '启动';
  static const continueSheetChange = '换一个';
  static const continueSheetNoEmulators = '未找到可启动的应用';
  static const continueSheetSearchHint = '搜索应用名称或包名';
  static const continueSheetRecommended = '推荐模拟器';
  static const continueSheetOtherApps = '其他应用';
  static const continueSheetSearchResults = '搜索结果';
  static const continueSheetNoSearchResults = '没有匹配的应用';
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
