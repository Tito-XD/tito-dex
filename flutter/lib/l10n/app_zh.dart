/// UI copy for TitoDex (Simplified Chinese source + English via [kAppEn]).
library;

import '../features/dex/dex_models.dart';
import 'app_en.dart';
import 'app_locale.dart';

abstract final class AppZh {
  static String t(String id, String zh, [Map<String, Object>? vars]) {
    if (!AppLocale.instance.isEnglish) {
      return zh;
    }
    var text = kAppEn[id] ?? zh;
    if (vars != null) {
      for (final entry in vars.entries) {
        text = text.replaceAll('{${entry.key}}', '${entry.value}');
      }
    }
    return text;
  }

  static String get appTitle => t('appTitle', 'TitoDex');
  static String get bootstrapLoading => t('bootstrapLoading', '正在准备你的旅程…');
  static String get companionLoading => t('companionLoading', '正在加载对战数据…');
  static String get progressDialogTitle => t('progressDialogTitle', '正在处理…');
  static String get snackDownloadCancelled =>
      t('snackDownloadCancelled', '下载已取消');
  static String get searchLoading => t('searchLoading', '正在搜索…');
  static String get referenceLoading => t('referenceLoading', '正在加载资料…');

  /// Home header title — default TitoDex; custom trainer → «Name»Dex.
  static String displayTitleForTrainer(String trainerName) {
    final trimmed = trainerName.trim();
    if (trimmed.isEmpty || trimmed == 'Tito' || trimmed == 'Trainer') {
      return appTitle;
    }
    return t('displayTitleForTrainer', '${trimmed}Dex', {
      'trainerName': trimmed,
    });
  }

  static String get navHome => t('navHome', '首页');
  static String get navTeam => t('navTeam', '队伍');
  static String get navJourney => t('navJourney', '旅程');
  static String get navDex => t('navDex', '图鉴');
  static String get navSearch => t('navSearch', '搜索');
  static String get navSettings => t('navSettings', '设置');

  static String get trainerCard => t('trainerCard', '训练家卡片');
  static String get companion => t('companion', '同伴');

  static String timeGreeting(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 8) {
      return t('timeGreetingEarlyMorning', '早上好');
    }
    if (hour >= 8 && hour < 11) {
      return t('timeGreetingMorning', '上午好');
    }
    if (hour >= 11 && hour < 13) {
      return t('timeGreetingNoon', '中午好');
    }
    if (hour >= 13 && hour < 17) {
      return t('timeGreetingAfternoon', '下午好');
    }
    if (hour >= 17 && hour < 19) {
      return t('timeGreetingEvening', '傍晚好');
    }
    if (hour >= 19 && hour < 23) {
      return t('timeGreetingNight', '晚上好');
    }
    return t('timeGreetingLateNight', '深夜好');
  }

  static String trainerGreeting(String trainerName, [DateTime? time]) {
    final greeting = timeGreeting(time ?? DateTime.now());
    return t('trainerGreeting', '$greeting，训练家 $trainerName', {
      'greeting': greeting,
      'trainerName': trainerName,
    });
  }

  static String trainerNameLine(String trainerName) {
    final name = trainerName.isNotEmpty ? trainerName : 'Tito';
    return t('trainerNameLine', '训练家 $name', {'trainerName': name});
  }

  static String get journeyCardTitle => t('journeyCardTitle', '旅程');
  static String get journeyOpenDetail => t('journeyOpenDetail', '查看旅程详情');
  static String get journeyAssistantTitle => t('journeyAssistantTitle', '存档助手');
  static String get journeyAssistantMeta => t('journeyAssistantMeta', '助手');
  static String get journeyAssistantLoading =>
      t('journeyAssistantLoading', '整理中');
  static String get journeyAssistantLoadFailed =>
      t('journeyAssistantLoadFailed', '存档助手暂时无法读取地点或图鉴资料。');
  static String get journeyAssistantNearbyTitle =>
      t('journeyAssistantNearbyTitle', '附近未捕获');
  static String get journeyAssistantNearbyComplete =>
      t('journeyAssistantNearbyComplete', '当前地点的宝可梦已经捕获齐全。');
  static String get journeyAssistantLocationUnknown =>
      t('journeyAssistantLocationUnknown', '存档地点暂时无法和地点图鉴匹配；可以进入地点图鉴手动查找。');
  static String get journeyAssistantLocationDex =>
      t('journeyAssistantLocationDex', '打开地点图鉴');
  static String get journeyAssistantPartyTitle =>
      t('journeyAssistantPartyTitle', '队伍与进化');
  static String get journeyAssistantPartyComplete =>
      t('journeyAssistantPartyComplete', '当前队伍没有可识别的下一阶段进化提醒。');
  static String get journeyAssistantVersionTitle =>
      t('journeyAssistantVersionTitle', '版本补全');
  static String get journeyAssistantPickVersion =>
      t('journeyAssistantPickVersion', '选择一个精确版本后，可区分配对版本的直接遭遇缺口。');
  static String journeyAssistantNearbyCount(int count) =>
      t('journeyAssistantNearbyCount', '附近还有 $count 种未捕获', {'count': count});
  static String journeyAssistantEncounterGap(
    String version,
    String paired,
    int count,
  ) => t(
    'journeyAssistantEncounterGap',
    '$version 中无直接遭遇、但 $paired 可直接遇到的未捕获宝可梦：$count 种',
    {'version': version, 'paired': paired, 'count': count},
  );
  static String journeyAssistantEvolutionGap(int count) => t(
    'journeyAssistantEvolutionGap',
    '当前版本另有 $count 种未捕获宝可梦需要进化、生蛋或交换取得',
    {'count': count},
  );
  static String journeyAssistantEvolutionRoute(
    String from,
    String to,
    String trigger,
  ) => t('journeyAssistantEvolutionRoute', '$from → $to · $trigger', {
    'from': from,
    'to': to,
    'trigger': trigger,
  });
  static String get askTitoDexEntry => t('askTitoDexEntry', '卡住了？问 TitoDex');
  static String get askTitoDexEntryHint =>
      t('askTitoDexEntryHint', '按当前版本、地点和可靠存档进度查找下一步');
  static String get askTitoDexTitle => t('askTitoDexTitle', '问 TitoDex');
  static String get askTitoDexSubtitle =>
      t('askTitoDexSubtitle', '旅程与通用问答 · 可选扩展资料');
  static String get askTitoDexContextTitle =>
      t('askTitoDexContextTitle', '发送前检查上下文');
  static String get askTitoDexContextHint =>
      t('askTitoDexContextHint', '游戏版本始终保留；地点和徽章可点 × 移除。');
  static String get askTitoDexLocationNotSent =>
      t('askTitoDexLocationNotSent', '当前地点无法可靠匹配，因此不会发送。');
  static String get askTitoDexGameUnknown =>
      t('askTitoDexGameUnknown', '版本未确认');
  static String askTitoDexBadgeContext(int count) =>
      t('askTitoDexBadgeContext', '已确认 $count 枚徽章', {'count': count});
  static String get askTitoDexQuestionLabel =>
      t('askTitoDexQuestionLabel', '你被什么挡住了？');
  static String get askTitoDexQuestionHint =>
      t('askTitoDexQuestionHint', '例如：36号道路这棵树怎么过去？');
  static String get askTitoDexSubmit => t('askTitoDexSubmit', '查找下一步');
  static String get askTitoDexLoading => t('askTitoDexLoading', '正在核对资料…');
  static String get askTitoDexLocalAnswerLabel =>
      t('askTitoDexLocalAnswerLabel', '结构化资料 · 本地回答');
  static String get askTitoDexOnlineAnswerLabel =>
      t('askTitoDexOnlineAnswerLabel', '结构化资料 + AI 组织');
  static String get askTitoDexWorkerChecking =>
      t('askTitoDexWorkerChecking', '正在检查在线链路');
  static String get askTitoDexWorkerOnline =>
      t('askTitoDexWorkerOnline', 'Journey Assistant 已连接');
  static String get askTitoDexWorkerDisabled =>
      t('askTitoDexWorkerDisabled', '在线 AI 已关闭');
  static String get askTitoDexWorkerUnavailable =>
      t('askTitoDexWorkerUnavailable', '当前仅可使用本地资料');
  static String get askTitoDexWorkerRefresh =>
      t('askTitoDexWorkerRefresh', '重新检查连接');
  static String get askTitoDexQwenConfigured =>
      t('askTitoDexQwenConfigured', 'Qwen 已配置');
  static String get askTitoDexAiSearchEnabled =>
      t('askTitoDexAiSearchEnabled', 'AI Search 已开启');
  static String get askTitoDexCuratedSourcesEnabled =>
      t('askTitoDexCuratedSourcesEnabled', '限定来源已开启');
  static String get askTitoDexBraveNotConnected =>
      t('askTitoDexBraveNotConnected', '未接入 Brave Search');
  static String get askTitoDexStatusDisabledHint =>
      t('askTitoDexStatusDisabledHint', '可在设置中开启“在线 AI 回答”。');
  static String get askTitoDexStatusUnavailableHint =>
      t('askTitoDexStatusUnavailableHint', 'Worker 未连接或暂时不可达，回答会安全回退到本地。');
  static String get askTitoDexStatusOnlineHint => t(
    'askTitoDexStatusOnlineHint',
    '百科与攻略来源已合并显示；完整允许名单和许可说明见设置里的“数据来源与许可”。连接状态只表示已配置，本次实际命中来源仍会显示在答案上。',
  );
  static String get askTitoDexRouteLocal =>
      t('askTitoDexRouteLocal', '审核资料 · 本地回答');
  static String get askTitoDexRouteAuditedOnline =>
      t('askTitoDexRouteAuditedOnline', '审核资料 · Qwen 在线匹配');
  static String get askTitoDexRouteAiSearch =>
      t('askTitoDexRouteAiSearch', 'R2 AI Search · Qwen 匹配');
  static String get askTitoDexRouteCuratedDeterministic =>
      t('askTitoDexRouteCuratedDeterministic', '限定来源 · 确定性提取');
  static String get askTitoDexRouteCuratedQwen =>
      t('askTitoDexRouteCuratedQwen', '限定来源 · Qwen 整理');
  static String get askTitoDexTraceNoModel =>
      t('askTitoDexTraceNoModel', '本次未调用 Qwen');
  static String get askTitoDexTraceModel =>
      t('askTitoDexTraceModel', 'Qwen 已参与');
  static String get askTitoDexTraceAiSearch =>
      t('askTitoDexTraceAiSearch', 'AI Search 已命中');
  static String askTitoDexTraceSearchRoutes(int count) =>
      t('askTitoDexTraceSearchRoutes', '检索 $count 路', {'count': count});
  static String get askTitoDexOnlineFallback =>
      t('askTitoDexOnlineFallback', '在线链路失败，本次已回退到本地资料。');
  static String get askTitoDexOnlineTimeoutFallback =>
      t('askTitoDexOnlineTimeoutFallback', '在线整理超时，本次已回退到本地资料。');
  static String get askTitoDexOnlineSearchedNoMatch =>
      t('askTitoDexOnlineSearchedNoMatch', '在线助手已查找，但没有足够可靠的答案。');
  static String get askTitoDexUnknownWarning =>
      t('askTitoDexUnknownWarning', '部分信息或版本适用性仍需确认，请留意答案中的范围说明。');
  static String get askTitoDexSources => t('askTitoDexSources', '参考来源');
  static String askTitoDexSourceSummary(int count) =>
      t('askTitoDexSourceSummary', '参考 $count 个来源', {'count': count});
  static String askTitoDexEvidenceVerified(int count) =>
      t('askTitoDexEvidenceVerified', '已核验 · 参考 $count 个来源', {'count': count});
  static String askTitoDexEvidenceLowConfidence(int count) => t(
    'askTitoDexEvidenceLowConfidence',
    '低置信度 · 参考 $count 个来源',
    {'count': count},
  );
  static String get askTitoDexEvidenceLocalVerified =>
      t('askTitoDexEvidenceLocalVerified', '本地资料已核验');
  static String get askTitoDexStructuredGame =>
      t('askTitoDexStructuredGame', '本地资料 · 当前版本');
  static String get askTitoDexStructuredGeneral =>
      t('askTitoDexStructuredGeneral', '本地资料 · 通用范围');
  static String get askTitoDexStructuredPartial =>
      t('askTitoDexStructuredPartial', '本地资料 · 部分信息待确认');
  static String askTitoDexSourcesAvailable(int count) => t(
    'askTitoDexSourcesAvailable',
    '参考 $count 个来源 · 未逐项核验',
    {'count': count},
  );
  static String get askTitoDexEvidenceUnverified =>
      t('askTitoDexEvidenceUnverified', '尚未逐项核验 · 暂无引用');
  static String get askTitoDexSourceSheetTitle =>
      t('askTitoDexSourceSheetTitle', '回答引用');
  static String get askTitoDexSourceSheetHint =>
      t('askTitoDexSourceSheetHint', '这些页面用于生成或核验本条回答，点击即可打开原始链接。');
  static String get askTitoDexSourceLinkUnavailable =>
      t('askTitoDexSourceLinkUnavailable', '这个引用链接暂时无法打开。');
  static String get askTitoDexSourceLinkInvalid =>
      t('askTitoDexSourceLinkInvalid', '链接不可用');
  static String get askTitoDexNeedsClarification =>
      t('askTitoDexNeedsClarification', '请补充游戏版本或具体地点。');
  static String get askTitoDexTimeout =>
      t('askTitoDexTimeout', '在线整理超时了。旅程和存档没有受到影响，可以重试。');
  static String get askTitoDexNetworkFailed =>
      t('askTitoDexNetworkFailed', '在线服务暂时不可用。旅程仍可离线使用，请稍后重试。');
  static String get askTitoDexNoticeTitle =>
      t('askTitoDexNoticeTitle', '开启问 TitoDex？');
  static String get askTitoDexNoticeBody => t(
    'askTitoDexNoticeBody',
    '这个助手默认关闭。确认开启后，TitoDex 仍会优先使用 App 内的本地资料；本地不足时才会连接 Journey Worker，并可能使用 AI Search、Workers AI（Qwen）、限定来源联网检索与 DeepSeek 来整理答案。请求只包含你确认后的游戏版本、可靠的地点/徽章/里程碑 ID、语言、解析器版本、本次问题，以及同一游戏最近最多 6 组问答用于理解追问。最近 50 组问答只保存在本机，超出会自动删除最早一组。不会上传原始存档、训练家姓名、ID、金钱、队伍或个体数据。你之后可单独关闭在线回答，或关闭整个助手并隐藏所有入口。',
  );
  static String get askTitoDexNoticeAccept =>
      t('askTitoDexNoticeAccept', '确认开启');
  static String get settingsAskTitoDex =>
      t('settingsAskTitoDex', '允许在线 AI 与检索');
  static String get settingsAskTitoDexHint => t(
    'settingsAskTitoDexHint',
    '本地资料无法回答时才连接 Journey Worker；关闭后助手仍可使用内建离线答案。',
  );
  static String get extensionJourneyTitle => t('extensionJourneyTitle', '旅程助手');
  static String get extensionBuiltIn => t('extensionBuiltIn', '主 App 内建');
  static String get extensionBuiltInHint => t(
    'extensionBuiltInHint',
    '默认关闭；确认后才启用。关闭时 Journey 与 Search 不显示入口，也不预留位置。',
  );
  static String get extensionNotInstalled => t('extensionNotInstalled', '未安装');
  static String get extensionInstallHint =>
      t('extensionInstallHint', '按需从 TitoDex 扩展目录下载；Android 会显示系统安装确认。');
  static String get extensionInstall => t('extensionInstall', '下载并安装');
  static String get extensionInstalling => t('extensionInstalling', '正在准备扩展…');
  static String get extensionCheckUpdate =>
      t('extensionCheckUpdate', '检查并安装扩展更新');
  static String get extensionUpToDate => t('extensionUpToDate', '旅程助手扩展已是最新版本');
  static String get extensionCatalogUnavailable =>
      t('extensionCatalogUnavailable', '此版本未配置扩展下载目录，可继续使用现有离线功能。');
  static String get extensionInstallStarted =>
      t('extensionInstallStarted', '已交给 Android，请在系统页面确认安装');
  static String get extensionInstallFailed =>
      t('extensionInstallFailed', '扩展安装未能开始，请稍后再试');
  static String get extensionInstalled => t('extensionInstalled', '已安装');
  static String get extensionEnabled => t('extensionEnabled', '启用问 TitoDex 助手');
  static String get extensionUninstall => t('extensionUninstall', '卸载扩展');
  static String get extensionUninstallHint =>
      t('extensionUninstallHint', '将打开 Android 系统卸载确认页面。');
  static String get extensionOnlineTitle =>
      t('extensionOnlineTitle', '旅程助手与在线功能');
  static String get extensionSearchDisplay =>
      t('extensionSearchDisplay', '在搜索页显示');
  static String get extensionSearchProminent =>
      t('extensionSearchProminent', '重点显示');
  static String get extensionSearchCompact =>
      t('extensionSearchCompact', '紧凑显示');
  static String get extensionSearchHidden => t('extensionSearchHidden', '不显示');
  static String get extensionSearchAsk => t('extensionSearchAsk', '通用问答');
  static String get extensionSearchAskHint =>
      t('extensionSearchAskHint', '不读取原始存档；可按当前选择的游戏版本查询扩展资料。');
  static String get emulatorContinueHint => t('emulatorContinueHint', '从模拟器继续');
  static String get partySaveDiffBanner =>
      t('partySaveDiffBanner', '与最新存档不同 · 点击同步');
  static String get partySaveDiffDismiss =>
      t('partySaveDiffDismiss', '不再提示本次差异');
  static String get partySaveSyncConfirm =>
      t('partySaveSyncConfirm', '用存档队伍覆盖当前编辑？');
  static String get settingsChangeAvatar => t('settingsChangeAvatar', '更换头像');
  static String get settingsJourneyReadOnly =>
      t('settingsJourneyReadOnly', '旅程信息（来自存档）');
  static String get settingsTrainerId => t('settingsTrainerId', '训练家 ID');
  static String get settingsTrainerSecretId =>
      t('settingsTrainerSecretId', '隐藏 ID');
  static String get settingsTrainerGender =>
      t('settingsTrainerGender', '训练家性别');
  static String get settingsSaveLanguage => t('settingsSaveLanguage', '存档语言');
  static String get settingsSaveMoney => t('settingsSaveMoney', '随身资金');
  static String get settingsMotherMoney => t('settingsMotherMoney', '妈妈保管');
  static String get settingsStarter => t('settingsStarter', '最初的伙伴');
  static String get settingsMapCoordinates =>
      t('settingsMapCoordinates', '地图坐标');
  static String get settingsJourneyStarted =>
      t('settingsJourneyStarted', '旅程开始');
  static String get settingsLeagueChampion =>
      t('settingsLeagueChampion', '首次通关');
  static String get settingsDexProgress => t('settingsDexProgress', '图鉴进度');
  static String get teamSummaryTitle => t('teamSummaryTitle', '队伍概览');
  static String get teamCollapseDetails => t('teamCollapseDetails', '收回详情');
  static String get teamCommonWeaknesses => t('teamCommonWeaknesses', '常见弱点');
  static String get teamSharedWeaknesses =>
      t('teamSharedWeaknesses', '共同弱点（≥2 只）');
  static String get teamAverageLevel => t('teamAverageLevel', '平均等级');
  static String get teamBaseStatTotal => t('teamBaseStatTotal', '种族值合计');
  static String get teamTypeCoverage => t('teamTypeCoverage', '属性覆盖');
  static String journeyRemainingDex(int count) =>
      t('journeyRemainingDex', '图鉴查看其他待补全 · $count 种', {'count': count});
  static String get sleepToolsTitle => t('sleepToolsTitle', 'Pokémon Sleep 工具');
  static String get sleepToolsTierAHint =>
      t('sleepToolsTierAHint', '内置离线试算，并保留 Neroli’s Lab 资料入口');
  static String get sleepToolsOpen => t('sleepToolsOpen', '打开睡眠与料理试算');
  static String get sleepToolsOpenHint =>
      t('sleepToolsOpenHint', '睡眠分数 · 食材基础能量 · 食谱等级加成');
  static String get sleepToolsSubtitle =>
      t('sleepToolsSubtitle', '离线小工具 · 不读取 Pokémon Sleep 账号或记录');
  static String get sleepScoreTitle => t('sleepScoreTitle', '睡眠分数');
  static String get sleepScoreHint =>
      t('sleepScoreHint', '按入睡与起床时间估算；8 小时 30 分达到 100 分。');
  static String get sleepBedtime => t('sleepBedtime', '入睡时间');
  static String get sleepWakeup => t('sleepWakeup', '起床时间');
  static String sleepDurationResult(int hours, int minutes) => t(
    'sleepDurationResult',
    '睡眠时长 $hours 小时 $minutes 分钟',
    {'hours': hours, 'minutes': minutes},
  );
  static String get sleepRecipeTitle => t('sleepRecipeTitle', '料理能量试算（基础）');
  static String get sleepRecipeHint =>
      t('sleepRecipeHint', '添加本次食材并设置食谱等级；这是透明的基础公式，不包含完整食谱、锅容量或队伍生产模拟。');
  static String get sleepIngredientAdd =>
      t('sleepIngredientAdd', '点击添加食材（名称 · 单个基础能量）');
  static String get sleepIngredientEmpty =>
      t('sleepIngredientEmpty', '尚未添加食材。');
  static String get sleepIngredientDecrease =>
      t('sleepIngredientDecrease', '减少一个');
  static String get sleepIngredientIncrease =>
      t('sleepIngredientIncrease', '增加一个');
  static String sleepRecipeLevel(int level) =>
      t('sleepRecipeLevel', '食谱等级 · Lv $level', {'level': level});
  static String get sleepRecipeBonus => t('sleepRecipeBonus', '食谱固有加成（%）');
  static String sleepRecipeEnergy(int value) =>
      t('sleepRecipeEnergy', '通常料理能量 · $value', {'value': value});
  static String sleepRecipeBreakdown(int base, double level, int bonus) => t(
    'sleepRecipeBreakdown',
    '食材 $base × 等级 ${level.toStringAsFixed(2)} × 固有加成 ${100 + bonus}%',
    {
      'base': base,
      'level': level.toStringAsFixed(2),
      'bonus': '${100 + bonus}',
    },
  );
  static String sleepRecipeCrit(int weekday, int sunday) => t(
    'sleepRecipeCrit',
    '大成功参考：平日 2 倍 $weekday · 周日 3 倍 $sunday',
    {'weekday': weekday, 'sunday': sunday},
  );
  static String get sleepSourceTitle => t('sleepSourceTitle', '公式与范围');
  static String get sleepSourceBody => t(
    'sleepSourceBody',
    '睡眠分数、19 种食材基础能量、1–70 级食谱倍率与料理公式移植自 Neroli’s Lab 固定提交 cb533f2，依 Apache-2.0 使用并在 App 许可证页完整署名。中文食材名参考神奇宝贝百科。完整配队、食材生产与长期模拟仍请使用 Neroli’s Lab。',
  );
  static String get dexManualMarkSeen => t('dexManualMarkSeen', '已标记为见过');
  static String get dexManualMarkCaught => t('dexManualMarkCaught', '已标记为捕获');
  static String get dexManualMarkClear => t('dexManualMarkClear', '已清除标记');

  static String get continueJourney => t('continueJourney', '继续旅程');
  static String get cityView => t('cityView', '★  城景  ★');
  static String get continueButton => t('continueButton', '继续');

  static String get labelGame => t('labelGame', '游戏');
  static String get labelPlayTime => t('labelPlayTime', '游戏时间');
  static String get labelBadges => t('labelBadges', '徽章');

  static String get party => t('party', '队伍');
  static String get currentParty => t('currentParty', '当前队伍');
  static String partySlot(int index) =>
      t('partySlot', '#$index', {'index': index});
  static String get level => t('level', 'Lv');

  static String get journeySince2026 => t('journeySince2026', '旅程始于 2026');
  static String get widgetContinue => t('widgetContinue', '继续');
  static String companionMessage(String location) =>
      t('companionMessage', '$location 今天也很热闹！', {'location': location});

  static String get dexScopeNote =>
      t('dexScopeNote', '全国图鉴 1–1025，中文名与属性来自在线图鉴；已捕获/已见过状态来自存档与同行队伍。');
  static String get dexCaught => t('dexCaught', '已捕获');
  static String get dexSeen => t('dexSeen', '已见过');
  static String get dexUnknown => t('dexUnknown', '未见过');
  static String get dexFilterAll => t('dexFilterAll', '全部');
  static String get dexFilterCaught => t('dexFilterCaught', '已捕获');
  static String get dexFilterSeen => t('dexFilterSeen', '已见过');
  static String get dexFilterUnseen => t('dexFilterUnseen', '未见过');
  static String dexScopeProgress(
    int caught,
    int seen,
    int total, {
    int? evolutionOrTrade,
  }) {
    if (AppLocale.instance.isEnglish) {
      final extra = evolutionOrTrade == null
          ? ''
          : ' · Trade/evolve $evolutionOrTrade';
      return 'Caught $caught · Seen $seen$extra / $total';
    }
    return '捕获 $caught · 见过 $seen'
        '${evolutionOrTrade == null ? '' : ' · 交换/进化 $evolutionOrTrade'} / $total';
  }

  static String get dexTabNational => t('dexTabNational', '全国图鉴');
  static String dexRegionalDexTitle(String regionLabel) =>
      t('dexRegionalDexTitle', '$regionLabel图鉴', {'regionLabel': regionLabel});
  static String get dexPickRegionalPokedex =>
      t('dexPickRegionalPokedex', '选择地区图鉴');
  static String get dexPickBrowseScope => t('dexPickBrowseScope', '选择图鉴范围');
  static String get dexBrowseByRegion => t('dexBrowseByRegion', '按地区');
  static String get dexBrowseByRegionHint =>
      t('dexBrowseByRegionHint', '全国、关东、城都及其他地区图鉴');
  static String get dexBrowseByGeneration => t('dexBrowseByGeneration', '按世代');
  static String get dexBrowseByGenerationHint =>
      t('dexBrowseByGenerationHint', '按首次登场世代筛选 G1–G9');
  static String get dexGenerationDebutHint =>
      t('dexGenerationDebutHint', '按首次登场世代统计');
  static String get dexTabJourney => t('dexTabJourney', '旅程同行');
  static String get dexFilterEmpty => t('dexFilterEmpty', '当前筛选条件下暂无图鉴条目。');
  static String dexRegionProgress(
    int startId,
    int endId,
    int seen,
    int caught,
    int total,
  ) => t(
    'dexRegionProgress',
    '#$startId–$endId · 已见 $seen / 已捕 $caught / 共 $total',
    {
      'startId': startId,
      'endId': endId,
      'seen': seen,
      'caught': caught,
      'total': total,
    },
  );
  static String get dexRegionNational => t('dexRegionNational', '全国');
  static String get dexRegionJohto => t('dexRegionJohto', '城都');
  static String get dexRegionKanto => t('dexRegionKanto', '关东');
  static String get dexJourneyEmpty =>
      t('dexJourneyEmpty', '当前旅程同行里还没有载入图鉴条目，试试全国图鉴。');
  static String get dexCaughtEmpty =>
      t('dexCaughtEmpty', '还没有已捕获的图鉴条目，同行宝可梦会自动标记为已捕获。');
  static String get dexSeenEmpty => t('dexSeenEmpty', '还没有已见过的图鉴条目。');
  static String dexLoadingProgress(int loaded, int total) => t(
    'dexLoadingProgress',
    '正在加载图鉴 $loaded / $total…',
    {'loaded': loaded, 'total': total},
  );
  static String get dexLoadingDetail =>
      t('dexLoadingDetail', '正在从 PokeAPI 拉取详情…');
  static String get dexLoadFailed => t('dexLoadFailed', '图鉴数据加载失败');
  static String dexLoadFailedDetail(int statusCode) => t(
    'dexLoadFailedDetail',
    'PokeAPI 请求失败（HTTP $statusCode）。请检查网络，或在设置中下载离线资料包后重试。',
    {'statusCode': statusCode},
  );
  static String get errorGeneric => t('errorGeneric', '加载失败，请稍后重试。');
  static String get errorFormatDetail =>
      t('errorFormatDetail', '数据格式异常，请检查网络后重试，或下载离线资料包。');
  static String get dexRetry => t('dexRetry', '重试');
  static String get dexHeight => t('dexHeight', '身高');
  static String get dexWeight => t('dexWeight', '体重');
  static String get dexWeaknesses => t('dexWeaknesses', '弱点（受到 ×2）');
  static String get dexResistances => t('dexResistances', '抗性（受到 ×0.5）');
  static String get dexImmunities => t('dexImmunities', '免疫（受到 ×0）');
  static String get dexStabEffective => t('dexStabEffective', '本系克制（打出 ×2）');
  static String get dexEvolution => t('dexEvolution', '进化链');
  static String get dexObtainLocations => t('dexObtainLocations', '出现地点');
  static String get dexObtainEmpty =>
      t('dexObtainEmpty', '当前版本未收录该宝可梦的野外遭遇数据（可能需进化、交换、赠送，或不可野生捕获）。');
  static String get dexFlavorEnglishNote =>
      t('dexFlavorEnglishNote', '该世代暂无官方中文描述，以下为英文原文。');
  static String get dexFlavorZhFallbackNote =>
      t('dexFlavorZhFallbackNote', '心金/魂银世代无中文图鉴文案，以下为近世代中文译名供参考。');
  static String get dexNone => t('dexNone', '无');
  static String get dexApiNote =>
      t('dexApiNote', '数据主要来自 PokeAPI；属性、招式与获取方式会随所选游戏版本切换，仅供资料查询。');
  static String get dexFormStatusMega => t('dexFormStatusMega', '超级进化');
  static String get dexFormStatusBattleOnly =>
      t('dexFormStatusBattleOnly', '对战限定');
  static String get dexFormStatusNotObtainable =>
      t('dexFormStatusNotObtainable', '不可常驻');
  static String get dexFormStatusCosmetic => t('dexFormStatusCosmetic', '外观');
  static String get dexFormStatusPartial => t('dexFormStatusPartial', '资料不完整');
  static String get dexFormStatusUnavailableHere =>
      t('dexFormStatusUnavailableHere', '当前版本不可用');
  static String get dexFormStatusNotObtainableHere =>
      t('dexFormStatusNotObtainableHere', '当前版本不可常驻获得');
  static String get dexFormStatusEventOnly =>
      t('dexFormStatusEventOnly', '活动限定');
  static String get dexFormStatusDeprecated =>
      t('dexFormStatusDeprecated', '历史形态');
  static String dexFormIntroducedIn(String game) =>
      t('dexFormIntroducedIn', '初次登场：$game', {'game': game});

  static String get settingsAttributionTitle =>
      t('settingsAttributionTitle', '关于 TitoDex · 数据来源与许可');
  static String get settingsAttributionHint =>
      t('settingsAttributionHint', '非官方学习工具 · 查看完整 Credits 与权利说明');
  static String get settingsOpenSourceLicenses =>
      t('settingsOpenSourceLicenses', '查看开源许可证');
  static String get settingsUnofficialNotice => t(
    'settingsUnofficialNotice',
    '非官方学习工具：与 Nintendo、Creatures、GAME FREAK、The Pokémon Company 无隶属、授权、赞助或认可关系。',
  );
  static String get settingsAttributionBody => t(
    'settingsAttributionBody',
    'TitoDex 是非官方、非商业、仅面向学习与个人游玩辅助的工具，与 Nintendo Co., Ltd.、Creatures Inc.、GAME FREAK inc.、The Pokémon Company 及其关联公司不存在隶属、授权、赞助或认可关系。Pokémon、宝可梦、角色、游戏名称、图像、音频与商标归各自权利人所有；本工具不提供 ROM、密钥、付费内容或存档修改。\n\n'
        '资料与文字：PokéAPI（物种、形态、招式、特性、道具、版本与基础地点；数据／代码仓库 BSD-3-Clause）、52Poké Wiki／神奇宝贝百科（部分中文说明、携带道具、地点与体形；百科原创内容 CC BY-NC-SA 3.0）、Bulbapedia（道具分组与少量地点语言链接；CC BY-NC-SA 2.5）、PKHeX（固定提交导出的现代遭遇覆盖；GPL-3.0-or-later，App 不嵌入或执行）、Project Pokémon（HGSS 存档／PKM 结构与地图编号技术参考）。\n\n'
        '问 TitoDex 的限定联网来源：中文检索优先 52Poké Wiki；没有足够可靠的结果时，才回退到 Pokémon 官方网站、Bulbapedia、StrategyWiki、Serebii、PokéAPI、Wikidata、Pokémon Database、Smogon、Marriland、GameFAQs、Game8、IGN、Nintendo Life 与 Eurogamer。联网摘要只用于当次回答与引用核验，不会自动写入 R2、AI Search、APK 或本地图鉴包；各站内容仍适用其自身条款与权利说明。Tavily 与 DeepSeek 是检索／生成服务，不是百科内容权利人。\n\n'
        '媒体：PokéAPI/sprites、Pokémon Showdown／Smogon 社区创作者、PokéSprite 类型图标（MIT）、SteamGridDB 社区来源页、Pokémon HOME 与各代游戏的官方图像／音频；Nunito 字体依 SIL OFL 1.1 随包分发。百科开放许可不自动覆盖其中的官方游戏媒体，各素材仍按记录级来源与原权利状态处理。\n\n'
        '外部工具：Pokémon Sleep 二级页的睡眠分数、19 种食材数值、食谱等级倍率与料理能量公式移植自 Neroli’s Lab 固定提交 cb533f2，依 Apache-2.0 使用并随 App 提供许可证与 NOTICE；完整配队和长期模拟仍保留为外部入口。\n\n'
        '来源入口：pokemon.com · wiki.52poke.com · bulbapedia.bulbagarden.net · strategywiki.org · serebii.net · pokeapi.co · wikidata.org · pokemondb.net · smogon.com · marriland.com · gamefaqs.gamespot.com · game8.co · ign.com · nintendolife.com · eurogamer.net · github.com/PokeAPI/sprites · github.com/msikma/pokesprite · github.com/kwsch/PKHeX · projectpokemon.org · pokemonshowdown.com · steamgriddb.com · nerolislab.com。固定提交、逐文件来源和构建批次说明见项目根目录 CREDITS.md、THIRD_PARTY_NOTICES.md 及数据包随附 attribution 文件。',
  );
  static String get dexMoves => t('dexMoves', '升级招式');
  static String dexMovesMore(int count) =>
      t('dexMovesMore', '另有 $count 个招式已缓存', {'count': count});
  static String get dexTabIntro => t('dexTabIntro', '简介');
  static String get dexTabBasic => t('dexTabBasic', '基本信息');
  static String get dexTabObtain => t('dexTabObtain', '获取');
  static String get dexTabMoves => t('dexTabMoves', '招式');
  static String get dexFlavorTitle => t('dexFlavorTitle', '图鉴描述');
  static String get dexFlavorEmpty =>
      t('dexFlavorEmpty', '暂无可用图鉴描述（PokeAPI 未提供该版本中文文案时会显示英文）。');
  static String get dexAbilities => t('dexAbilities', '特性');
  static String get dexAbilityHidden => t('dexAbilityHidden', '隐藏特性');
  static String get dexAbilityAllVersions => t('dexAbilityAllVersions', '全版本');
  static String get dexAbilitySinceGen5 => t('dexAbilitySinceGen5', '第五世代起');
  static String get dexAbilityFilter => t('dexAbilityFilter', '特性筛选');
  static String get dexAbilityUnknownName => t('dexAbilityUnknownName', '待收录');
  static String get dexAbilityPlaceholder =>
      t('dexAbilityPlaceholder', '特性资料整理中，将随后续离线资料包更新。');
  static String get dexAbilityEmptyPending =>
      t('dexAbilityEmptyPending', '暂无特性数据。');
  static String get dexBaseHappiness => t('dexBaseHappiness', '初始亲密度');
  static String get dexCaptureRate => t('dexCaptureRate', '捕获率');
  static String get dexEvYield => t('dexEvYield', '基础点数 (EV)');
  static String get dexObtainEmptyVersion =>
      t('dexObtainEmptyVersion', '暂无野外出现地点（可能为进化、赠送或不可野生捕获）。');
  static String get dexObtainExactVersion => t('dexObtainExactVersion', '精确版本');
  static String get dexObtainCombinedVersions =>
      t('dexObtainCombinedVersions', '版本合并');
  static String get dexWildHeldItems => t('dexWildHeldItems', '野生携带道具');
  static String get dexWildHeldItemsHint =>
      t('dexWildHeldItemsHint', '概率按当前选择的版本分别显示。');
  static String get dexChainPlanningTitle =>
      t('dexChainPlanningTitle', '当前版本集齐规划');
  static String get dexChainPlanningPickVersion =>
      t('dexChainPlanningPickVersion', '选择一个精确版本后，可判断这条进化链能否单版本集齐。');
  static String get dexChainPlanningLoading =>
      t('dexChainPlanningLoading', '正在整理这条进化链的获得方式…');
  static String get dexChainPlanningUnavailable =>
      t('dexChainPlanningUnavailable', '暂时无法读取这条进化链的版本资料。');
  static String dexChainSelfContained(String version) =>
      t('dexChainSelfContained', '$version可独立集齐这条进化链', {'version': version});
  static String get dexChainTradeRequired =>
      t('dexChainTradeRequired', '需要通讯交换才能集齐这条进化链');
  static String dexChainUnavailable(String version) =>
      t('dexChainUnavailable', '$version无法独立集齐这条进化链', {'version': version});
  static String get dexChainMethodCatch => t('dexChainMethodCatch', '直接捕获');
  static String get dexChainMethodEvolve => t('dexChainMethodEvolve', '进化获得');
  static String get dexChainMethodTrade => t('dexChainMethodTrade', '需要通讯交换');
  static String get dexChainMethodBreed => t('dexChainMethodBreed', '生蛋获得');
  static String get dexChainMethodUnavailable =>
      t('dexChainMethodUnavailable', '当前版本无获得路径');
  static String get dexVersionBoth => t('dexVersionBoth', '版本限定：配对版本均可直接遇到');
  static String dexVersionOnlyThis(String version) =>
      t('dexVersionOnlyThis', '版本限定：仅$version可直接遇到', {'version': version});
  static String dexVersionOnlyOther(String version) =>
      t('dexVersionOnlyOther', '版本限定：可在$version捕获后交换', {'version': version});
  static String get dexVersionNeither =>
      t('dexVersionNeither', '配对版本均无直接遭遇，通常需要进化、赠送或活动获得');
  static String get dexFilterEvolutionOrTrade =>
      t('dexFilterEvolutionOrTrade', '待进化');
  static String get dexFilterCalculating => t('dexFilterCalculating', '整理中');
  static String get dexEvolutionOrTradeLoading =>
      t('dexEvolutionOrTradeLoading', '正在整理交换/进化缺口…');
  static String dexObtainForGame(String gameLabel) =>
      t('dexObtainForGame', '$gameLabel 出现地点', {'gameLabel': gameLabel});
  static String dexObtainScope(String gameLabel) =>
      t('dexObtainScope', '以下出现地点：$gameLabel', {'gameLabel': gameLabel});
  static String get dexFlavorNoEdition => t('dexFlavorNoEdition', '当前版本暂无图鉴描述');
  static String get dexFlavorPickEdition =>
      t('dexFlavorPickEdition', '选择其他版本查看');
  static String get dexMoveFilterAll => t('dexMoveFilterAll', '全部');
  static String get dexMoveFilterLevel => t('dexMoveFilterLevel', '等级');
  static String get dexMoveFilterMachine => t('dexMoveFilterMachine', '学习器');
  static String get dexMoveFilterEgg => t('dexMoveFilterEgg', '蛋');
  static String get dexMoveFilterTutor => t('dexMoveFilterTutor', '教学');
  static String get dexBaseStats => t('dexBaseStats', '种族值');
  static String get dexBaseStatTotal => t('dexBaseStatTotal', '种族值合计');
  static String get dexTypeGridTitle => t('dexTypeGridTitle', '当受到以下属性攻击时');
  static String get dexGenderRatio => t('dexGenderRatio', '性别比例');
  static String dexGenderFemale(double percent) => t(
    'dexGenderFemale',
    '雌性 ${percent.toStringAsFixed(1)}%',
    {'percent': percent.toStringAsFixed(1)},
  );
  static String get dexEggGroups => t('dexEggGroups', '生蛋分组');
  static String get dexGrowthRate => t('dexGrowthRate', '经验组');
  static String get dexBaseExperience => t('dexBaseExperience', '基础经验值');
  static String get dexHabitat => t('dexHabitat', '栖息地');
  static String get dexGenderDifferences => t('dexGenderDifferences', '性别外观差异');
  static String get dexGenderDifferencesYes =>
      t('dexGenderDifferencesYes', '有');
  static String get dexSpeciesAxes => t('dexSpeciesAxes', '体形 · 颜色 · 大小');
  static String dexShapeBeforeGen6(String label) =>
      t('dexShapeBeforeGen6', '$label（六代前）', {'label': label});
  static String get dexHatchSteps => t('dexHatchSteps', '孵化步数');
  static String get dexNoEvolution => t('dexNoEvolution', '没有进化链记录。');
  static String get dexMovesHgssScope =>
      t('dexMovesHgssScope', '以下招式范围：心金 / 魂银');
  static String dexMovesScope(String gameLabel) =>
      t('dexMovesScope', '以下招式范围：$gameLabel', {'gameLabel': gameLabel});
  static String dexDataFallbackNote(String gameLabel) => t(
    'dexDataFallbackNote',
    '当前游戏暂无此数据，以下来自：$gameLabel',
    {'gameLabel': gameLabel},
  );
  static String get dexFormDataInherited =>
      t('dexFormDataInherited', '该形态暂无独立资料，以下数据沿用默认形态。');
  static String get dexFormDataPartial =>
      t('dexFormDataPartial', '该形态资料不完整，部分战斗数据缺失或沿用默认形态。');
  static String get dexBaseStatsRadar => t('dexBaseStatsRadar', '能力雷达');
  static String get dexBaseStatsBars => t('dexBaseStatsBars', '种族值条');
  static String get dexReferenceTitle => t('dexReferenceTitle', '常用资料');
  static String get dexReferenceMoves => t('dexReferenceMoves', '招式图鉴');
  static String get dexReferenceAbilities => t('dexReferenceAbilities', '特性图鉴');
  static String get dexReferenceSearchHint =>
      t('dexReferenceSearchHint', '搜索名称或编号…');
  static String get dexReferenceEmpty => t('dexReferenceEmpty', '没有匹配的资料条目。');
  static String get dexReferenceDataMissing =>
      t('dexReferenceDataMissing', '当前数据包中没有这条资料，请更新资料后重试。');
  static String get dexReferenceUnavailableInGame =>
      t('dexReferenceUnavailableInGame', '当前版本不可用');
  static String get dexReferenceScopeUnknown =>
      t('dexReferenceScopeUnknown', '当前版本的资料范围尚未确认');
  static String get dexReferenceNoDescription =>
      t('dexReferenceNoDescription', '暂无特性说明。');
  static String get dexReferenceFindPokemon =>
      t('dexReferenceFindPokemon', '搜索拥有此资料的宝可梦');
  static String dexReferenceMoveMeta(
    String category,
    int? power,
    int? accuracy,
    int? pp,
  ) {
    final parts = <String>[category];
    if (power != null) {
      parts.add(t('dexReferenceMovePowerPart', '威力 $power', {'power': power}));
    }
    if (accuracy != null) {
      parts.add(
        t('dexReferenceMoveAccuracyPart', '命中 $accuracy', {
          'accuracy': accuracy,
        }),
      );
    }
    if (pp != null) {
      parts.add(t('dexReferenceMovePpPart', 'PP $pp', {'pp': pp}));
    }
    return parts.join(' · ');
  }

  static String get dexReferenceNatureStats =>
      t('dexReferenceNatureStats', '能力变化');
  static String get dexReferenceNatureFlavors =>
      t('dexReferenceNatureFlavors', '口味偏好');
  static String get dexReferenceNatureNeutral =>
      t('dexReferenceNatureNeutral', '无能力变化（中性性格）');
  static String dexReferenceLikesFlavor(String flavor) =>
      t('dexReferenceLikesFlavor', '喜好 $flavor 味', {'flavor': flavor});
  static String dexReferenceHatesFlavor(String flavor) =>
      t('dexReferenceHatesFlavor', '厌恶 $flavor 味', {'flavor': flavor});
  static String get dexReferenceViewEggGroupPokemon =>
      t('dexReferenceViewEggGroupPokemon', '查看蛋群宝可梦');
  static String get dexReferenceViewMoveLearners =>
      t('dexReferenceViewMoveLearners', '会此招式的宝可梦');
  static String get dexReferenceViewAbilityPokemon =>
      t('dexReferenceViewAbilityPokemon', '拥有此特性的宝可梦');
  static String get dexReferenceItemEffect => t('dexReferenceItemEffect', '效果');
  static String get dexReferenceNoEffect => t('dexReferenceNoEffect', '暂无说明');
  static String dexReferenceItemCost(String cost) =>
      t('dexReferenceItemCost', '参考价格 ₽$cost', {'cost': cost});
  static String get dexReferenceTypeModifiers =>
      t('dexReferenceTypeModifiers', '属性倍率变化');
  static String get dexReferenceMovePowerSymbol =>
      t('dexReferenceMovePowerSymbol', '⚔');
  static String get dexReferenceMoveAccuracySymbol =>
      t('dexReferenceMoveAccuracySymbol', '🎯');
  static String get dexReferenceMovePpSymbol =>
      t('dexReferenceMovePpSymbol', 'PP');
  static String dexReferencePokemonCount(int count) =>
      t('dexReferencePokemonCount', '共 $count 只宝可梦', {'count': count});
  static String dexFilterByEggGroup(String name) =>
      t('dexFilterByEggGroup', '蛋群：$name', {'name': name});
  static String get dexFilterClear => t('dexFilterClear', '清除筛选');
  static String get dexFilterActive => t('dexFilterActive', '已启用图鉴筛选');
  static String get dexSpeciesFilterOpen => t('dexSpeciesFilterOpen', '体形筛选');
  static String get dexSpeciesFilterTitle =>
      t('dexSpeciesFilterTitle', '按体形 · 颜色 · 大小筛选');
  static String get dexSpeciesFilterShape => t('dexSpeciesFilterShape', '体形');
  static String get dexSpeciesFilterShapeHint =>
      t('dexSpeciesFilterShapeHint', '图标对应游戏内图鉴 / Pokémon HOME 的体形检索');
  static String get dexSpeciesFilterColor => t('dexSpeciesFilterColor', '颜色');
  static String get dexSpeciesFilterColorHint =>
      t('dexSpeciesFilterColorHint', '可多选：图鉴配色没有橙色，橙色系请同时选「棕」和「红」');
  static String get dexSpeciesFilterSize => t('dexSpeciesFilterSize', '大小');
  static String get dexSpeciesFilterSizeHint =>
      t('dexSpeciesFilterSizeHint', '按身高分档，与图鉴检索里的大小轴一致');
  static String get dexSpeciesFilterReset => t('dexSpeciesFilterReset', '重置');
  static String get dexSpeciesFilterApply => t('dexSpeciesFilterApply', '查看结果');
  static String dexFilterByMove(String name) =>
      t('dexFilterByMove', '招式 · $name', {'name': name});
  static String dexFilterByAbility(String name) =>
      t('dexFilterByAbility', '特性 · $name', {'name': name});
  static String dexFilterMoveLabel(String name) => dexFilterByMove(name);
  static String dexFilterAbilityLabel(String name) => dexFilterByAbility(name);
  static String get dexGameVersionHgss => t('dexGameVersionHgss', '心金·魂银');
  static String get dexGameVersionSv => t('dexGameVersionSv', '朱紫');
  static String get dexGameVersionSwsh => t('dexGameVersionSwsh', '剑盾');

  static String get settingsDexOffline => t('settingsDexOffline', '离线资料包');
  static String get settingsDexOfflineHint => t(
    'settingsDexOfflineHint',
    '完整离线资料包可一次安装全国图鉴与形态、进化链、招式、特性、道具等资料，以及中文对照、地图、图片和应用配置。',
  );
  static String get settingsDexAdvancedOptions =>
      t('settingsDexAdvancedOptions', '高级选项');
  static String get settingsDexOfflineUnset =>
      t('settingsDexOfflineUnset', '尚未下载离线资料包');
  static String settingsDexOfflinePartial(int pokemonCount) => t(
    'settingsDexOfflinePartial',
    '部分缓存 $pokemonCount / $titodexMaxNationalDexId，可点「继续下载」补全',
    {'pokemonCount': pokemonCount},
  );
  static String get settingsDexVerify => t('settingsDexVerify', '校验离线数据');
  static String get settingsDexVerifyRunning =>
      t('settingsDexVerifyRunning', '正在校验…');
  static String get settingsDexVerifyNoData =>
      t('settingsDexVerifyNoData', '尚未安装离线资料包，无需校验。');
  static String settingsDexVerifyOk(int pokemonCount) => t(
    'settingsDexVerifyOk',
    '校验通过：$pokemonCount 只宝可梦的离线资料完整。',
    {'pokemonCount': pokemonCount},
  );
  static String settingsDexVerifyProblems(int missingDetails) => t(
    'settingsDexVerifyProblems',
    '发现问题：缺失 $missingDetails 份详情资料，建议重新下载数据包。',
    {'missingDetails': missingDetails},
  );
  static String get settingsDexVerifyIncomplete =>
      t('settingsDexVerifyIncomplete', '离线数据不完整（下载未完成或索引缺失），建议继续或重新下载数据包。');
  static String settingsDexVerifySpriteNote(int missingSprites) => t(
    'settingsDexVerifySpriteNote',
    '另有 $missingSprites 张图片缺失（在线时会自动回退加载）。',
    {'missingSprites': missingSprites},
  );
  static String settingsDexOfflineReady(
    int pokemonCount,
    int moveCount,
    String size,
    String downloadedAt,
  ) => t(
    'settingsDexOfflineReady',
    '已安装 $pokemonCount 只 · $moveCount 招式 · 含完整资料库与图片 · $size · $downloadedAt',
    {
      'pokemonCount': pokemonCount,
      'moveCount': moveCount,
      'size': size,
      'downloadedAt': downloadedAt,
    },
  );
  static String get settingsDexOfflineDownload =>
      t('settingsDexOfflineDownload', '下载离线资料包');
  static String get settingsDexOfflineResume =>
      t('settingsDexOfflineResume', '继续下载离线资料包');
  static String get settingsDexOfflineClear =>
      t('settingsDexOfflineClear', '清除离线缓存');
  static String get settingsDexOfflinePrefer =>
      t('settingsDexOfflinePrefer', '优先使用离线缓存');
  static String settingsDexOfflineProgress(
    String phase,
    int current,
    int total,
  ) {
    final phaseLabel = switch (phase) {
      'types' => t('settingsDexPhaseTypes', '属性'),
      'pokemon' => t('settingsDexPhasePokemon', '宝可梦'),
      'cdn_manifest' => t('settingsDexPhaseCdnManifest', '获取数据包清单'),
      'cdn_download' => t('settingsDexPhaseCdnDownload', '下载数据包'),
      'cdn_verify' => t('settingsDexPhaseCdnVerify', '校验数据包'),
      'cdn_decompress' => t('settingsDexPhaseCdnDecompress', '解压数据包'),
      'cdn_extract' => t('settingsDexPhaseCdnExtract', '写入离线数据'),
      'cdn_index' => t('settingsDexPhaseCdnIndex', '准备筛选索引'),
      'apk_seed_manifest' => t('settingsDexPhaseApkManifest', '准备清单'),
      'apk_seed_read' => t('settingsDexPhaseApkRead', '读取内置数据包'),
      'apk_seed_verify' => t('settingsDexPhaseApkVerify', '校验内置数据包'),
      'apk_seed_decompress' => t('settingsDexPhaseApkDecompress', '解压'),
      'apk_seed_extract' => t('settingsDexPhaseApkExtract', '写入'),
      'apk_seed_index' => t('settingsDexPhaseApkIndex', '准备筛选索引'),
      'index' => t('settingsDexPhaseIndex', '准备筛选索引'),
      'l10n_download' => t('settingsDexPhaseL10n', '中文对照'),
      'done' => t('settingsDexPhaseDone', '完成'),
      'partial' => t('settingsDexPhasePartial', '部分完成'),
      _ => phase,
    };
    final isBundlePhase =
        phase.startsWith('cdn_') || phase.startsWith('apk_seed_');
    final verb = isBundlePhase
        ? t('settingsDexProgressVerbBundle', '正在')
        : t('settingsDexProgressVerbCache', '正在缓存');
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
    if (AppLocale.instance.isEnglish) {
      return showCount
          ? '$verb$phaseLabel $current / $total'
          : '$verb$phaseLabel';
    }
    return '$verb$phaseLabel${showCount ? ' $current / $total' : ''}';
  }

  static String get offlineSeedProgressTitle =>
      t('offlineSeedProgressTitle', '正在准备离线资料包');

  static String get settingsDexCdnDownload =>
      t('settingsDexCdnDownload', '下载完整离线资料包');
  static String get settingsDexCdnDownloadHint => t(
    'settingsDexCdnDownloadHint',
    '推荐：一次性下载完整离线资料包，包含全国图鉴与形态、进化链、招式、特性、道具等资料，以及中文对照、地图、图片和应用配置；下载完成后可离线使用。',
  );
  static String get settingsDexBackgroundDownload =>
      t('settingsDexBackgroundDownload', '后台下载');
  static String get settingsDexCancelDownload =>
      t('settingsDexCancelDownload', '取消下载');
  static String get snackDexBackgroundDownload =>
      t('snackDexBackgroundDownload', '已转到后台，可从通知栏查看进度');
  static String get snackDexBackgroundDownloadNoNotification =>
      t('snackDexBackgroundDownloadNoNotification', '已转到后台；通知权限未开启，可返回设置查看进度');
  static String get snackDexBackgroundDownloadFailed =>
      t('snackDexBackgroundDownloadFailed', '无法启动后台下载，请保持 TitoDex 在前台');
  static String get dexDownloadNotificationTitle =>
      t('dexDownloadNotificationTitle', '正在准备离线资料包');
  static String get dexDownloadNotificationDoneTitle =>
      t('dexDownloadNotificationDoneTitle', '离线资料包已准备完成');
  static String get dexDownloadNotificationDoneBody =>
      t('dexDownloadNotificationDoneBody', '现在可以离线使用完整图鉴与资料库');
  static String get dexDownloadNotificationPartialTitle =>
      t('dexDownloadNotificationPartialTitle', '离线资料包已部分完成');
  static String get dexDownloadNotificationPartialBody =>
      t('dexDownloadNotificationPartialBody', '返回 TitoDex 可继续补全剩余资料');
  static String get dexDownloadNotificationFailedTitle =>
      t('dexDownloadNotificationFailedTitle', '离线资料包准备失败');
  static String get dexDownloadNotificationFailedBody =>
      t('dexDownloadNotificationFailedBody', '返回 TitoDex 后可重新下载');
  static String get settingsDexOfflineDownloadPokeApi =>
      t('settingsDexOfflineDownloadPokeApi', '从 PokeAPI 下载（备用）');
  static String get settingsDexDefaultGameVersion =>
      t('settingsDexDefaultGameVersion', '默认图鉴游戏版本');
  static String get settingsDexDefaultGameVersionHint => t(
    'settingsDexDefaultGameVersionHint',
    '浏览图鉴详情与招式时使用的心金 / 朱紫 / 剑盾等版本组；列表小图默认展示该版本对应世代的游戏内像素图。',
  );
  static String get snackDexCdnDone => t('snackDexCdnDone', '完整离线资料包已安装完成');
  static String get snackDexCdnFailed => t('snackDexCdnFailed', '完整离线资料包下载失败');

  static String get offlinePromptTitle => t('offlinePromptTitle', '下载完整离线资料包');
  static String get offlinePromptBody => t(
    'offlinePromptBody',
    '建议下载完整离线资料包，包含全国图鉴与形态、进化链、招式、特性、道具等资料，以及中文对照、地图、图片和应用配置。',
  );
  static String get offlinePromptLater => t('offlinePromptLater', '稍后');
  static String get offlinePromptGoSettings =>
      t('offlinePromptGoSettings', '去设置');

  static String get updateAvailableTitle =>
      t('updateAvailableTitle', '离线资料有更新');
  static String get updateAvailableBody =>
      t('updateAvailableBody', '有较新的完整离线资料包，可在设置中下载更新。');
  static String get updateAvailableLater => t('updateAvailableLater', '稍后');
  static String get updateAvailableGoSettings =>
      t('updateAvailableGoSettings', '去设置');

  static String get snackDexOfflineDone =>
      t('snackDexOfflineDone', '离线资料包已下载完成');
  static String snackDexOfflinePartial(int count) => t(
    'snackDexOfflinePartial',
    '已缓存 $count / $titodexMaxNationalDexId 只宝可梦，可再次点击继续下载补全',
    {'count': count},
  );
  static String get snackDexOfflineCleared =>
      t('snackDexOfflineCleared', '已清除离线资料包缓存');
  static String get snackDexOfflineFailed =>
      t('snackDexOfflineFailed', '离线资料包下载失败');

  static String get searchPlaceholder =>
      t('searchPlaceholder', '搜索全国图鉴：中文名、英文名、编号或属性…');
  static String get searchPrompt => t('searchPrompt', '搜索宝可梦');
  static String get searchEmptyHint => t(
    'searchEmptyHint',
    '可搜索 1–1025 号宝可梦的中文名、英文名、编号、分类或属性。空格分隔可叠加条件，如「四足 棕」。',
  );
  static String get searchSuggestionTitle => t('searchSuggestionTitle', '试试这些');
  static String get searchRecent => t('searchRecent', '最近搜索');
  static String get searchRecentClear => t('searchRecentClear', '清空');
  static String get settingsSwitchGame => t('settingsSwitchGame', '更换');
  static String dexFlavorZhReference(String source) =>
      t('dexFlavorZhReference', '中文参考 · 来自$source：', {'source': source});
  static String get searchTrending => t('searchTrending', '热门搜索');
  static String get searchNoResults => t('searchNoResults', '没有找到匹配的宝可梦。');
  static String get searchHubReference => t('searchHubReference', '常用资料');
  static String get searchHubBattle => t('searchHubBattle', '对战资料');
  static String get searchHubDataTitle => t('searchHubDataTitle', '资料列表');
  static String get searchHubRegionalDex => t('searchHubRegionalDex', '地区图鉴');
  static String get searchHubReferenceHint =>
      t('searchHubReferenceHint', '招式、道具、特性与 Sleep');
  static String get searchHubBattleHint =>
      t('searchHubBattleHint', '属性、能力、伤害估算');
  static String get battleCalcTitle => t('battleCalcTitle', '对战计算');
  static String get battleCalcModeMatchup => t('battleCalcModeMatchup', '克制');
  static String get battleCalcModeStats => t('battleCalcModeStats', '能力');
  static String get battleCalcModeDamage => t('battleCalcModeDamage', '伤害');
  static String get battleCalcModeBlind => t('battleCalcModeBlind', '盲点');
  static String get searchRefNatures => t('searchRefNatures', '性格');
  static String get searchRefEggGroups => t('searchRefEggGroups', '生蛋分组');
  static String get searchRefItems => t('searchRefItems', '道具');
  static String get searchRefWeather => t('searchRefWeather', '天气');
  static String get searchRefTerrains => t('searchRefTerrains', '场地');
  static String get searchRefStatus => t('searchRefStatus', '状态异常');
  static String get locationDexTitle => t('locationDexTitle', '地点图鉴');
  static String get locationDexHint =>
      t('locationDexHint', '按当前游戏版本查看每个地点会遇到的宝可梦；展开地点即可核对捕获完成度。');
  static String get locationDexSearchHint =>
      t('locationDexSearchHint', '搜索地点或宝可梦');
  static String get locationDexLoadFailed =>
      t('locationDexLoadFailed', '地点资料暂时无法载入，请检查离线资料包或网络。');
  static String get locationDexEmpty => t('locationDexEmpty', '当前版本没有匹配的地点资料。');
  static String locationDexCompletion(int caught, int total) => t(
    'locationDexCompletion',
    '已捕获 $caught / $total',
    {'caught': caught, 'total': total},
  );
  static String get searchRefPlaceholder =>
      t('searchRefPlaceholder', '资料加载中，请先下载完整离线资料包或检查网络。');
  static String get searchBattleTypeMatchup =>
      t('searchBattleTypeMatchup', '属性克制');
  static String get searchBattleStatCalc => t('searchBattleStatCalc', '能力值计算');
  static String get searchBattleQuickDamage =>
      t('searchBattleQuickDamage', '伤害速算');
  static String get searchOnlineShowdown =>
      t('searchOnlineShowdown', 'Showdown 网页版');
  static String get searchOnlineUsage => t('searchOnlineUsage', '使用率排行');

  static String get companionStandbyLabel =>
      t('companionStandbyLabel', '同行宝可梦');
  static String get companionPickerTitle =>
      t('companionPickerTitle', '选择同行宝可梦');
  static String get companionPickerHint =>
      t('companionPickerHint', '选中后会按需下载它的动图，不占安装包体积。');
  static String get companionPickerSearchHint =>
      t('companionPickerSearchHint', '搜索中文名、英文名或编号…');
  static String companionPicked(String name) =>
      t('companionPicked', '$name 加入同行！', {'name': name});
  static String companionFriendship(String name) =>
      t('companionFriendship', '$name 的好感度爆棚了！❤', {'name': name});
  static String get companionSettingsTitle =>
      t('companionSettingsTitle', '同行宝可梦');
  static String get companionSettingsHint =>
      t('companionSettingsHint', '它会以动图形式待在主页右下角，点它有惊喜。');
  static String get companionSettingsToggle =>
      t('companionSettingsToggle', '在主页显示同行宝可梦');
  static String get companionSettingsSize => t('companionSettingsSize', '同行大小');
  static String companionMediaTitle(String name) =>
      t('companionMediaTitle', '准备 $name 中…', {'name': name});
  static String get companionMediaGif => t('companionMediaGif', '载入动图');
  static String get companionMediaCry => t('companionMediaCry', '载入叫声');
  static String get companionMediaFailedHint =>
      t('companionMediaFailedHint', '部分资源载入失败，将使用静态图或稍后重试。');
  static String get settingsGroupAdvancedHint =>
      t('settingsGroupAdvancedHint', '内置存档导入、旅程 JSON 导入/导出与重置');
  static String get settingsCategoryProfile =>
      t('settingsCategoryProfile', '游戏与训练家');
  static String get settingsCategoryProfileHint =>
      t('settingsCategoryProfileHint', '游戏版本、头像、显示名称与旅程状态');
  static String get settingsCategoryAssistant =>
      t('settingsCategoryAssistant', '助手与扩展');
  static String get settingsCategoryAssistantHint =>
      t('settingsCategoryAssistantHint', '旅程助手、在线问答与搜索展示');
  static String get settingsCategoryCompanion =>
      t('settingsCategoryCompanion', '同行宝可梦');
  static String get settingsCategoryCompanionHint =>
      t('settingsCategoryCompanionHint', '显示、大小、位置与媒体资源');
  static String get settingsCategoryAppearance =>
      t('settingsCategoryAppearance', '界面与快捷方式');
  static String get settingsCategoryAppearanceHint =>
      t('settingsCategoryAppearanceHint', '应用主题、表面层次、动画与桌面入口');
  static String get settingsCategoryData => t('settingsCategoryData', '数据与存储');
  static String get settingsCategoryDataHint =>
      t('settingsCategoryDataHint', '离线资料、存档同步与模拟器');
  static String get settingsCategoryAbout =>
      t('settingsCategoryAbout', '关于与高级');
  static String get settingsCategoryAboutHint =>
      t('settingsCategoryAboutHint', '数据来源、许可、导入导出与重置');
  static String get settingsGroupInterface =>
      t('settingsGroupInterface', '界面风格');
  static String get settingsVisualTheme => t('settingsVisualTheme', '应用主题');
  static String get settingsVisualThemeHint =>
      t('settingsVisualThemeHint', '主题会全局应用并自动保存，不影响资料与功能。');
  static String get settingsRetroStyle => t('settingsRetroStyle', '卡片层次');
  static String get settingsRetroStyleHint =>
      t('settingsRetroStyleHint', '开启后卡片带有高度或阴影；关闭后使用更平的描边表面。');
  static String get settingsListAnimations =>
      t('settingsListAnimations', '列表渐入动画');
  static String get settingsListAnimationsHint =>
      t('settingsListAnimationsHint', '图鉴、搜索、常用资料等列表的渐入小动画；关闭后内容会立即显示。');
  static String get settingsAppShortcuts => t('settingsAppShortcuts', '桌面快捷入口');
  static String get settingsAppShortcutsHint =>
      t('settingsAppShortcutsHint', '默认显示图鉴和搜索；可替换或补充下方任意资料与工具，最多三个。');
  static String get settingsAppShortcutsLimit =>
      t('settingsAppShortcutsLimit', '最多只能选择三个快捷入口。');
  static String get settingsAppShortcutsCustomize =>
      t('settingsAppShortcutsCustomize', '自定义快捷入口');
  static String get settingsAppShortcutsReset =>
      t('settingsAppShortcutsReset', '恢复默认');
  static String get settingsAppShortcutsNone =>
      t('settingsAppShortcutsNone', '当前不显示快捷入口');
  static String get companionSettingsPick => t('companionSettingsPick', '更换同伴');
  static String get companionSettingsReset =>
      t('companionSettingsReset', '恢复默认（随存档御三家）');
  static String get companionSettingsPosition =>
      t('companionSettingsPosition', '调整位置');
  static String get companionPositionTitle =>
      t('companionPositionTitle', '调整同行位置');
  static String get companionPositionHint =>
      t('companionPositionHint', '拖拽下方预览里的图标到你想让同行宝可梦停留的位置。');
  static String get companionPositionReset =>
      t('companionPositionReset', '恢复默认位置');
  static String shinyPartyFound(String name) =>
      t('shinyPartyFound', '✨ 你的 $name 今天在闪光！', {'name': name});
  static String get quizTitle => t('quizTitle', '猜猜我是谁');
  static String get quizEntryHint => t('quizEntryHint', '剪影问答');
  static String get quizPrompt => t('quizPrompt', '这只宝可梦是谁？');
  static String get quizNext => t('quizNext', '下一题');
  static String get quizCorrect => t('quizCorrect', '答对了！');
  static String quizWrong(String name) =>
      t('quizWrong', '是 $name 才对！', {'name': name});
  static String quizScore(int correct, int total) => t(
    'quizScore',
    '战绩 $correct / $total',
    {'correct': correct, 'total': total},
  );
  static String quizStreak(int streak) =>
      t('quizStreak', '连对 $streak', {'streak': streak});
  static String quizBestStreak(int streak) =>
      t('quizBestStreak', '最佳连对 $streak', {'streak': streak});
  static String get quizAdoptCompanion => t('quizAdoptCompanion', '设为同行');
  static String quizAdopted(String name) =>
      t('quizAdopted', '$name 现在陪你同行啦！', {'name': name});

  static String get companionToolTypeMatchup =>
      t('companionToolTypeMatchup', '属性克制速查');
  static String get companionToolStatCalc =>
      t('companionToolStatCalc', '能力值计算');
  static String get companionToolQuickDamage =>
      t('companionToolQuickDamage', '伤害速算');
  static String get companionPokemonSearchHint =>
      t('companionPokemonSearchHint', '搜索宝可梦…');
  static String get companionLinkedTypes => t('companionLinkedTypes', '属性');
  static String get companionTypeDefenderTitle =>
      t('companionTypeDefenderTitle', '防守方');
  static String get companionTypeManualPick =>
      t('companionTypeManualPick', '手动选择属性（最多 2 个）');
  static String get companionTypeSummaryTitle =>
      t('companionTypeSummaryTitle', '克制摘要');
  static String get companionTypeAttackerTitle =>
      t('companionTypeAttackerTitle', '进攻方（可选）');
  static String get companionTypeAttackerPick =>
      t('companionTypeAttackerPick', '攻击方属性（本系克制参考）');
  static String get companionDefenderAbilityPick =>
      t('companionDefenderAbilityPick', '防守方特性（影响属性抗性）');
  static String get companionAttackerAbilityPick =>
      t('companionAttackerAbilityPick', '进攻方特性（破免疫 / 皮肤 / 大力士等）');
  static String get companionManualAbilityPick =>
      t('companionManualAbilityPick', '手动选特性（未搜宝可梦时）');
  static String get companionWeatherPick => t('companionWeatherPick', '天气');
  static String get companionTerrainPick => t('companionTerrainPick', '场地');
  static String get companionTerastalToggle =>
      t('companionTerastalToggle', '太晶化');
  static String get companionTerastalType => t('companionTerastalType', '太晶属性');
  static String get companionDefenderTerastal =>
      t('companionDefenderTerastal', '防守方太晶化');
  static String get companionAttackerTerastal =>
      t('companionAttackerTerastal', '进攻方太晶化');
  static String get companionHeldItemPick => t('companionHeldItemPick', '携带道具');
  static String get companionTypeBoostItemType =>
      t('companionTypeBoostItemType', '属性强化道具类型');
  static String get companionStatusPick =>
      t('companionStatusPick', '异常状态（攻击方）');
  static String get companionContactMove =>
      t('companionContactMove', '接触类招式（毛茸茸等）');
  static String get companionToolBlindSpot =>
      t('companionToolBlindSpot', '打击 / 联防盲点');
  static String get companionOffensiveBlindSpots =>
      t('companionOffensiveBlindSpots', '打击盲点');
  static String get companionDefensiveBlindSpots =>
      t('companionDefensiveBlindSpots', '联防盲点');
  static String get companionGenerationTypeNote =>
      t('companionGenerationTypeNote', '属性按当前游戏世代修正（Gen 4/5 无妖精）');
  static String companionDamageExtra(String extra) =>
      t('companionDamageExtra', '环境/特性修正 ×$extra', {'extra': extra});
  static String get companionCriticalHit => t('companionCriticalHit', '击中要害');
  static String get companionDefenderScreen =>
      t('companionDefenderScreen', '对方有光墙/反射壁');
  static String get companionSpreadMove => t('companionSpreadMove', '双打·多目标招式');
  static String get companionStatApplyAttack =>
      t('companionStatApplyAttack', '带入伤害计算（攻击侧）');
  static String get companionStatApplyDefense =>
      t('companionStatApplyDefense', '带入伤害计算（防御侧）');
  static String get companionStatApplyHp =>
      t('companionStatApplyHp', '带入伤害计算（对方 HP）');
  static String get companionDamageAssumptions => t(
    'companionDamageAssumptions',
    '计算假设：默认单打；勾选「双打·多目标招式」后按命中多个目标 ×0.75 计算；'
        '伤害含 85%–100% 随机浮动；'
        '击中要害按世代倍率（第六世代起 ×1.5，此前 ×2）并无视光墙/反射壁；'
        '按一次命中的固定威力招式估算，不处理固定伤害、连续攻击、动态威力或招式专属效果；'
        '未收录的特性、道具与场地细节不计入，结果仅供旅途参考。',
  );
  static String get companionStatInputsTitle =>
      t('companionStatInputsTitle', '输入');
  static String companionStatFacilityNote(String facility) => t(
    'companionStatFacilityNote',
    '默认等级按 $facility 常见配置（Lv.50）',
    {'facility': facility},
  );
  static String get companionStatBase => t('companionStatBase', '种族值');
  static String get companionStatLevel => t('companionStatLevel', '等级');
  static String get companionStatIv => t('companionStatIv', '个体值');
  static String get companionStatEv => t('companionStatEv', '努力值');
  static String get companionStatResultTitle =>
      t('companionStatResultTitle', '计算结果');
  static String get companionStatResultHint =>
      t('companionStatResultHint', '此为理论值；对战设施对手的实际数值可能含道具或强化。');
  static String get companionDamageInputsTitle =>
      t('companionDamageInputsTitle', '对战双方');
  static String companionDamageFacility(String facility) =>
      t('companionDamageFacility', '场景：$facility', {'facility': facility});
  static String get companionAttackerSearchHint =>
      t('companionAttackerSearchHint', '搜索进攻方宝可梦…');
  static String get companionDefenderSearchHint =>
      t('companionDefenderSearchHint', '搜索防守方宝可梦…');
  static String get companionMoveType => t('companionMoveType', '招式属性');
  static String get companionMovePower => t('companionMovePower', '招式威力');
  static String get companionAttackStat => t('companionAttackStat', '攻击');
  static String get companionSpAttackStat => t('companionSpAttackStat', '特攻');
  static String get companionDefenseStat => t('companionDefenseStat', '防御');
  static String get companionSpDefenseStat => t('companionSpDefenseStat', '特防');
  static String get companionDefenderHp => t('companionDefenderHp', '防守方 HP');
  static String get companionDamageResultTitle =>
      t('companionDamageResultTitle', '估算结果');
  static String companionDamageRange(int min, int max) =>
      t('companionDamageRange', '伤害 $min ~ $max', {'min': min, 'max': max});
  static String companionDamagePercent(double min, double max) => t(
    'companionDamagePercent',
    '约占 HP ${min.toStringAsFixed(1)}% ~ ${max.toStringAsFixed(1)}%',
    {'min': min.toStringAsFixed(1), 'max': max.toStringAsFixed(1)},
  );
  static String get companionDamageOffense => t('companionDamageOffense', '进攻');
  static String get companionDamageDefense => t('companionDamageDefense', '防守');
  static String companionDamageModifiers(String type, String stab) => t(
    'companionDamageModifiers',
    '属性倍率 ×$type · 本系 ×$stab · 随机 85%–100%',
    {'type': type, 'stab': stab},
  );

  static String get recentTimeline => t('recentTimeline', '最近动态');
  static String get nextPrefix => t('nextPrefix', '下一步：');
  static String get journeyTimelineEmpty =>
      t('journeyTimelineEmpty', '还没有旅程记录');

  static String get teamNote => t('teamNote', '队伍数据来自当前存档或演示旅程。后续可在这里编辑同行宝可梦。');
  static String get teamEmptySlot => t('teamEmptySlot', '空位');
  static String teamSubtitle(int count) =>
      t('teamSubtitle', '同行 $count 只', {'count': count});
  static String teamSummaryAvgLevel(double avg) => t(
    'teamSummaryAvgLevel',
    '平均 Lv ${avg.toStringAsFixed(1)}',
    {'avg': avg.toStringAsFixed(1)},
  );
  static String teamSummaryBstSum(int sum) =>
      t('teamSummaryBstSum', '种族值合计 $sum', {'sum': sum});
  static String teamSummaryTypeCoverage(int count) =>
      t('teamSummaryTypeCoverage', '属性覆盖 $count/18', {'count': count});
  static String teamSummaryWeaknesses(String types) =>
      t('teamSummaryWeaknesses', '常见弱点：$types', {'types': types});
  static String teamSummarySharedWeaknesses(String types) =>
      t('teamSummarySharedWeaknesses', '共同弱点（≥2 只）：$types', {'types': types});
  static String get teamEditTitle => t('teamEditTitle', '编辑同行');
  static String get teamEditLevel => t('teamEditLevel', '等级');
  static String get teamEditNickname => t('teamEditNickname', '昵称');
  static String get teamEditTypes => t('teamEditTypes', '属性');
  static String get teamEditAbility => t('teamEditAbility', '特性');
  static String get teamEditDelete => t('teamEditDelete', '移出队伍');
  static String get teamEditSwapPrev => t('teamEditSwapPrev', '与前一位交换');
  static String get teamEditSwapNext => t('teamEditSwapNext', '与后一位交换');
  static String get teamAddTitle => t('teamAddTitle', '添加宝可梦');
  static String get teamAddInvalidId => t('teamAddInvalidId', '无效编号');
  static String get confirm => t('confirm', '确定');
  static String get cancel => t('cancel', '取消');
  static String get retry => t('retry', '重试');
  static String get sleepToolsMain => t('sleepToolsMain', 'Neroli\'s Lab 主页');
  static String get sleepToolsGuides => t('sleepToolsGuides', '攻略指南');
  static String get sleepToolsDocs => t('sleepToolsDocs', '开发文档');
  static String get sleepLinkCopied => t('sleepLinkCopied', '链接已复制到剪贴板');

  static String get settingsGroupTrainer => t('settingsGroupTrainer', '训练家');
  static String get settingsGroupSaveSync => t('settingsGroupSaveSync', '存档同步');
  static String get settingsGroupAdvanced => t('settingsGroupAdvanced', '高级');
  static String get settingsDisplayName => t('settingsDisplayName', '显示名称');
  static String get settingsDisplayNameHint =>
      t('settingsDisplayNameHint', 'Tito');
  static String get settingsSaveTrainerName =>
      t('settingsSaveTrainerName', '保存名称');
  static String get settingsSaveTrainerHint =>
      t('settingsSaveTrainerHint', '民间汉化版的显示名可能与存档字节解码不同。');
  static String settingsSaveDecodeHint(String saveName) => t(
    'settingsSaveDecodeHint',
    '存档标准解码：$saveName（汉化版可能显示不同）',
    {'saveName': saveName},
  );

  static String get settingsCurrentGame => t('settingsCurrentGame', '当前游戏');
  static String get settingsLocation => t('settingsLocation', '当前地点');
  static String get settingsPlayTime => t('settingsPlayTime', '游戏时间');
  static String get settingsBadges => t('settingsBadges', '徽章');

  static String get settingsJourneyData => t('settingsJourneyData', '旅程数据');
  static String get settingsImportSave =>
      t('settingsImportSave', '导入内置 PKMSS.sav');
  static String get settingsResetMock => t('settingsResetMock', '恢复演示数据');
  static String get settingsExportJourney =>
      t('settingsExportJourney', '复制旅程 JSON');
  static String get settingsImportJourney =>
      t('settingsImportJourney', '从 JSON 导入旅程');

  static String get settingsEmulator => t('settingsEmulator', '模拟器');
  static String get settingsEmulatorHint =>
      t('settingsEmulatorHint', '第一次点「继续」时也可以选择要启动的应用。');
  static String get settingsEmulatorUnset =>
      t('settingsEmulatorUnset', '未选择模拟器');
  static String get settingsPickEmulator => t('settingsPickEmulator', '选择模拟器');
  static String get settingsClearEmulator => t('settingsClearEmulator', '清除选择');
  static String settingsEmulatorSelected(String name) =>
      t('settingsEmulatorSelected', '已选择：$name', {'name': name});

  static String get settingsSaveFileHint => t(
    'settingsSaveFileHint',
    '选择一个具体的 .sav 存档文件。TitoDex 只会保存并重读这个文件，不会扫描任何文件夹。',
  );
  static String get settingsSaveFileUnset =>
      t('settingsSaveFileUnset', '尚未选择存档文件');
  static String get settingsPickSaveFile =>
      t('settingsPickSaveFile', '选择 .sav 存档文件');
  static String settingsSelectedSaveFile(String name) =>
      t('settingsSelectedSaveFile', '已选择文件：$name', {'name': name});
  static String get settingsClearSaveFile =>
      t('settingsClearSaveFile', '清除所选存档文件');
  static String get settingsAutoLoadOnStartup =>
      t('settingsAutoLoadOnStartup', '启动时自动重读所选存档');
  static String get settingsSyncNow => t('settingsSyncNow', '立即同步');
  static String settingsLastSynced(String fileName) =>
      t('settingsLastSynced', '上次同步：$fileName', {'fileName': fileName});
  static String get settingsLastSyncedNone =>
      t('settingsLastSyncedNone', '尚未读取所选存档');

  static String get snackSaveFileSet => t('snackSaveFileSet', '存档文件已选择并解析');
  static String get snackSaveFileCleared =>
      t('snackSaveFileCleared', '已清除所选存档文件');
  static String get snackSaveSyncUnchanged =>
      t('snackSaveSyncUnchanged', '存档未变化，无需更新');
  static String get snackSaveSyncNoFile =>
      t('snackSaveSyncNoFile', '请先在设置中选择一个 .sav 存档文件');
  static String get snackSaveFileUnavailable =>
      t('snackSaveFileUnavailable', '无法再次读取所选存档，请重新选择文件');
  static String get snackSaveSyncUnsupported =>
      t('snackSaveSyncUnsupported', '找到的存档格式不受支持');
  static String snackSaveSyncLoaded(String fileName) =>
      t('snackSaveSyncLoaded', '已从 $fileName 同步存档', {'fileName': fileName});

  static String get snackTrainerSaved => t('snackTrainerSaved', '训练家名称已保存');
  static String get snackJourneySaved => t('snackJourneySaved', '旅程信息已保存');
  static String get snackJourneyExported =>
      t('snackJourneyExported', '旅程 JSON 已复制到剪贴板');
  static String get snackJourneyImported =>
      t('snackJourneyImported', '已从 JSON 导入旅程');
  static String snackSaveLoaded(String name, int partyCount) => t(
    'snackSaveLoaded',
    '已加载 $name 的存档 · 队伍 $partyCount 只',
    {'name': name, 'partyCount': partyCount},
  );
  static String snackSaveLoadedWarnings(int count) =>
      t('snackSaveLoadedWarnings', '已加载存档（$count 条解析提示）', {'count': count});
  static String get snackMockRestored => t('snackMockRestored', '已恢复演示旅程');

  static String get continueSheetTitle => t('continueSheetTitle', '继续旅程');
  static String get continueSheetPickEmulator =>
      t('continueSheetPickEmulator', '选择要启动的应用');
  static String get continueSheetLaunch => t('continueSheetLaunch', '启动');
  static String get continueSheetChange => t('continueSheetChange', '换一个');
  static String get continueSheetNoEmulators =>
      t('continueSheetNoEmulators', '未找到可启动的应用');
  static String get continueSheetSearchHint =>
      t('continueSheetSearchHint', '搜索应用名称或包名');
  static String get continueSheetRecommended =>
      t('continueSheetRecommended', '推荐模拟器');
  static String get continueSheetOtherApps =>
      t('continueSheetOtherApps', '其他应用');
  static String get continueSheetSearchResults =>
      t('continueSheetSearchResults', '搜索结果');
  static String get continueSheetNoSearchResults =>
      t('continueSheetNoSearchResults', '没有匹配的应用');
  static String get continueSheetEmulatorLoadFailed =>
      t('continueSheetEmulatorLoadFailed', '读取已安装应用失败，请稍后重试');
  static String get continueSheetDesktopHint =>
      t('continueSheetDesktopHint', '模拟器启动目前仅支持 Android');
  static String continueSheetLaunching(String name) =>
      t('continueSheetLaunching', '正在打开 $name…', {'name': name});
  static String get snackEmulatorSaved => t('snackEmulatorSaved', '已记住模拟器选择');
  static String get snackEmulatorCleared =>
      t('snackEmulatorCleared', '已清除模拟器选择');
  static String get snackEmulatorLaunchFailed =>
      t('snackEmulatorLaunchFailed', '无法启动该应用');

  static String get snackAvatarConfirmAgain =>
      t('snackAvatarConfirmAgain', '再次点击修改头像');
  static String get snackAvatarUpdated => t('snackAvatarUpdated', '头像已更新');
  static String get snackAvatarFailed => t('snackAvatarFailed', '头像更换失败，请重试');
  static String get avatarPickGallery => t('avatarPickGallery', '从相册选择');
  static String snackGameSwitched(String gameTitle) =>
      t('snackGameSwitched', '已切换至 $gameTitle', {'gameTitle': gameTitle});

  static String placeholderScreen(String title) =>
      t('placeholderScreen', '$title 页面开发中', {'title': title});

  static String get journeyPackTitle => t('journeyPackTitle', 'Journey 资料包');
  static String get journeyPackSubtitle =>
      t('journeyPackSubtitle', '按游戏安装，需要时再下载');
  static String get journeyPackSwitchGame =>
      t('journeyPackSwitchGame', '切换游戏版本');
  static String get journeyPackPickExactGame =>
      t('journeyPackPickExactGame', '请先选择成对版本中的具体一款，再匹配对应资料包。');
  static String get journeyPackPrivacyNote => t(
    'journeyPackPrivacyNote',
    '资料包只扩展问 TitoDex 的攻略上下文，保存在 App 私有目录。不会上传存档，也不会替换图鉴数据。',
  );
  static String get journeyPackAvailable => t('journeyPackAvailable', '可用资料包');
  static String get journeyPackRefresh => t('journeyPackRefresh', '刷新');
  static String get journeyPackWorkerUnconfigured => t(
    'journeyPackWorkerUnconfigured',
    'Journey Assistant Worker 尚未配置，已安装的旧资料仍可继续使用。',
  );
  static String get journeyPackCatalogEmpty =>
      t('journeyPackCatalogEmpty', '暂时没有可下载的资料包。');
  static String get journeyPackCatalogUnavailable =>
      t('journeyPackCatalogUnavailable', '目录暂时无法读取，已安装的旧资料不会受影响。');
  static String journeyPackMeta(int entryCount, String kb, String version) => t(
    'journeyPackMeta',
    '$entryCount 条 · $kb KB · v$version',
    {'entryCount': entryCount, 'kb': kb, 'version': version},
  );
  static String get journeyPackUpdate => t('journeyPackUpdate', '更新');
  static String get journeyPackInstall => t('journeyPackInstall', '安装');
  static String get journeyPackDelete => t('journeyPackDelete', '删除');
  static String get journeyPackIncompatible =>
      t('journeyPackIncompatible', '需要新版图鉴包');
  static String get journeyPackCorrupt =>
      t('journeyPackCorrupt', '本地文件损坏，请重新安装');
  static String get journeyPackLegacyInstalled =>
      t('journeyPackLegacyInstalled', '已安装；当前目录未列出此版本，仍可安全使用。');
  static String get journeyPackInstalled =>
      t('journeyPackInstalled', '资料包已安装，可以用于问 TitoDex。');
  static String get journeyPackDeleted => t('journeyPackDeleted', '资料包已删除。');
  static String get journeyPackDeleteTitle =>
      t('journeyPackDeleteTitle', '删除这份资料包？');
  static String get journeyPackDeleteBody =>
      t('journeyPackDeleteBody', '只会删除下载的问答资料，不会删除存档或问答记录。');
  static String get journeyPackErrorWorkerNotConfigured => t(
    'journeyPackErrorWorkerNotConfigured',
    'Journey Assistant Worker 尚未配置。',
  );
  static String get journeyPackErrorTimeout =>
      t('journeyPackErrorTimeout', '连接超时，请稍后再试。');
  static String get journeyPackErrorInvalid =>
      t('journeyPackErrorInvalid', '资料包校验失败，原有资料没有被替换。');
  static String get journeyPackErrorBundleIncompatible =>
      t('journeyPackErrorBundleIncompatible', '需要先更新图鉴资料版本。');
  static String get journeyPackErrorDisabled =>
      t('journeyPackErrorDisabled', '请先在设置中启用问 TitoDex 助手。');
  static String get journeyPackErrorGeneric =>
      t('journeyPackErrorGeneric', '操作没有完成，请稍后重试。');

  static String get mediaResourceTitle => t('mediaResourceTitle', '媒体资源管理');
  static String get mediaResourceCachedTitle =>
      t('mediaResourceCachedTitle', '已缓存媒体');
  static String get mediaResourceCachedEmpty =>
      t('mediaResourceCachedEmpty', '暂无缓存');
  static String mediaResourceCachedSummary(int count, String size) => t(
    'mediaResourceCachedSummary',
    '共 $count 个文件 · $size',
    {'count': count, 'size': size},
  );
  static String get mediaResourceClearAll => t('mediaResourceClearAll', '全部清理');
  static String get mediaResourceDownloadTitle =>
      t('mediaResourceDownloadTitle', '按宝可梦下载');
  static String get mediaResourceCatalogUnavailable =>
      t('mediaResourceCatalogUnavailable', '媒体目录暂时不可用。请确认数据包已安装，或重新读取资源。');
  static String get mediaResourceLoadFailed =>
      t('mediaResourceLoadFailed', '媒体缓存读取失败，请重新读取');
  static String get mediaResourceReload => t('mediaResourceReload', '重新读取');
  static String get mediaResourceSearchHint =>
      t('mediaResourceSearchHint', '搜索宝可梦名称或编号');
  static String get mediaResourceNoMatch =>
      t('mediaResourceNoMatch', '未找到匹配的宝可梦');
  static String mediaResourceEntryMeta(int cries, int forms) => t(
    'mediaResourceEntryMeta',
    '$cries 条叫声 · $forms 张形态图',
    {'cries': cries, 'forms': forms},
  );
  static String get mediaResourceCry => t('mediaResourceCry', '叫声');
  static String get mediaResourceGif => t('mediaResourceGif', '动图');
  static String get mediaResourceCryFailed =>
      t('mediaResourceCryFailed', '叫声下载失败');
  static String get mediaResourceGifFailed =>
      t('mediaResourceGifFailed', '动图下载失败');
  static String mediaResourceCryCached(String name) =>
      t('mediaResourceCryCached', '已缓存 $name 的叫声', {'name': name});
  static String mediaResourceGifCached(String name) =>
      t('mediaResourceGifCached', '已缓存 $name 的动图', {'name': name});

  static String get anniversaryPickLogo =>
      t('anniversaryPickLogo', '选择周年 Logo');
  static String anniversaryCurrentLabel(
    String label, {
    bool formMismatch = false,
  }) {
    final mismatch = formMismatch
        ? t('anniversaryFormMismatch', '未自动匹配当前形态；')
        : '';
    return t('anniversaryCurrentLabel', '$mismatch当前展示：$label', {
      'formMismatch': mismatch,
      'label': label,
    });
  }

  static String anniversaryImageSemantics(int nationalId, String label) => t(
    'anniversaryImageSemantics',
    '全国图鉴 $nationalId · $label · 30周年 Logo',
    {'nationalId': nationalId, 'label': label},
  );
  static String get anniversaryImageLoadFailed =>
      t('anniversaryImageLoadFailed', '周年图片暂时无法加载');
  static String get anniversaryDisplayOnlyNote =>
      t('anniversaryDisplayOnlyNote', 'Logo 选择仅用于展示，不改变当前形态、闪光或图鉴数据。');
  static String get anniversaryCopyrightNote =>
      t('anniversaryCopyrightNote', '需联网加载 · 图片版权归原权利人所有');
  static String get anniversarySourceLink =>
      t('anniversarySourceLink', '官方来源与使用条款');
  static String get anniversarySourceOpenFailed =>
      t('anniversarySourceOpenFailed', '暂时无法打开官方页面，请稍后重试。');

  static String get dexDetailFormField => t('dexDetailFormField', '形态');
  static String get dexDetailVersionField => t('dexDetailVersionField', '资料版本');
  static String get dexDetailBaseForm => t('dexDetailBaseForm', '基础形态');
  static String get dexDetailExpansionScopeHint =>
      t('dexDetailExpansionScopeHint', '按已拥有的扩展内容选择；扩展范围包含同版本的本篇及此前扩展内容。');

  static String get close => t('close', '关闭');
  static String get dexSearchSheetTitle => t('dexSearchSheetTitle', '搜索与筛选');
  static String get dexSearchSheetHint =>
      t('dexSearchSheetHint', '名字、编号，或输入：火 飞行');
  static String get dexSearchClearQuery => t('dexSearchClearQuery', '清空搜索');
  static String get dexSearchScopeField => t('dexSearchScopeField', '浏览对象');
  static String get dexSearchAllPokemon => t('dexSearchAllPokemon', '全部宝可梦');
  static String get dexSearchGenerationField =>
      t('dexSearchGenerationField', '世代');
  static String get dexSearchAllGenerations =>
      t('dexSearchAllGenerations', '全部世代');
  static String get dexSearchTagField => t('dexSearchTagField', '分类');
  static String get dexSearchTagLegendary =>
      t('dexSearchTagLegendary', '传说的宝可梦');
  static String get dexSearchTagMythical => t('dexSearchTagMythical', '幻之宝可梦');
  static String get dexSearchTagPseudoLegendary =>
      t('dexSearchTagPseudoLegendary', '准神');
  static String get dexSearchTagBaby => t('dexSearchTagBaby', '幼年宝可梦');
  static String get dexSearchFormField => t('dexSearchFormField', '形态展示');
  static String get dexFormDisplayAll => t('dexFormDisplayAll', '全部形态');
  static String get dexFormDisplayAlternate =>
      t('dexFormDisplayAlternate', '其他形态');
  static String get dexSearchTypesField =>
      t('dexSearchTypesField', '属性 · 同时满足');
  static String get dexSearchSpeciesAxesTitle =>
      t('dexSearchSpeciesAxesTitle', '体型、颜色与大小');
  static String get dexSearchShapeField => t('dexSearchShapeField', '体型');
  static String get dexSearchColorField =>
      t('dexSearchColorField', '颜色 · 满足任一');
  static String get dexSearchReferenceTitle =>
      t('dexSearchReferenceTitle', '特性、招式与蛋群');
  static String get dexSearchReferenceRetry =>
      t('dexSearchReferenceRetry', '资料未加载，点击重试');
  static String get dexSearchEggGroupField => t('dexSearchEggGroupField', '蛋群');
  static String get dexSearchAllEggGroups => t('dexSearchAllEggGroups', '全部蛋群');
  static String get dexSearchReferenceNote =>
      t('dexSearchReferenceNote', '特性、招式与蛋群按物种的跨版本资料取交集。');
  static String get dexSearchEncounterField =>
      t('dexSearchEncounterField', '收集状态');
  static String get dexEncounterSeen => t('dexEncounterSeen', '已遇见');
  static String get dexEncounterUnseen => t('dexEncounterUnseen', '未遇见');
  static String get dexEncounterEvolutionOrTrade =>
      t('dexEncounterEvolutionOrTrade', '进化 / 交换补全');
  static String get dexSearchReset => t('dexSearchReset', '清空条件');
  static String get dexSearchReferenceHint =>
      t('dexSearchReferenceHint', '名称或编号');
  static String get dexSearchReferenceHelper =>
      t('dexSearchReferenceHelper', '输入完整名称，或从候选项选择');
  static String dexSearchClearField(String label) =>
      t('dexSearchClearField', '清除$label', {'label': label});
  static String dexSearchAbilityLabel(String name) =>
      t('dexSearchAbilityLabel', '特性：$name', {'name': name});
  static String dexSearchMoveLabel(String name) =>
      t('dexSearchMoveLabel', '招式：$name', {'name': name});
  static String dexGenerationProgress(
    int generation,
    int seen,
    int caught,
    int total,
  ) => t(
    'dexGenerationProgress',
    'G$generation · 已见 $seen / 已捕 $caught / 共 $total',
    {'generation': generation, 'seen': seen, 'caught': caught, 'total': total},
  );
  static String get dexScrollToTop => t('dexScrollToTop', '回到图鉴顶部');
  static String get dexFilterAction => t('dexFilterAction', '筛选');

  static String get companionPickerFormAppearance =>
      t('companionPickerFormAppearance', '选择形态与外观');
  static String get companionPickerShiny => t('companionPickerShiny', '闪光');
  static String get companionPickerNoForms =>
      t('companionPickerNoForms', '该宝可梦没有其他形态');
  static String get companionPickerGifSource =>
      t('companionPickerGifSource', '动图来源（按世代）');
  static String get companionPickerGifAuto =>
      t('companionPickerGifAuto', '自动选择');
  static String get companionPickerCrySource =>
      t('companionPickerCrySource', '叫声版本 / 形态');
  static String get companionPickerCryAuto =>
      t('companionPickerCryAuto', '自动匹配形态');
  static String get companionPickerPreviewCry =>
      t('companionPickerPreviewCry', '试听叫声');
  static String get companionPickerCryLatest =>
      t('companionPickerCryLatest', '最新叫声');
  static String get companionPickerCryLegacy =>
      t('companionPickerCryLegacy', '旧版叫声');
  static String companionHiddenAbilityOption(String name) =>
      t('companionHiddenAbilityOption', '$name（隐藏）', {'name': name});
  static String get settingsAppShortcutsSectionPrimary =>
      t('settingsAppShortcutsSectionPrimary', '默认入口');
  static String get settingsAppShortcutsSectionReference =>
      t('settingsAppShortcutsSectionReference', '图鉴与资料');
  static String get settingsAppShortcutsSectionTool =>
      t('settingsAppShortcutsSectionTool', '对战工具');
  static String settingsDexSeenCaught(int seen, int caught) => t(
    'settingsDexSeenCaught',
    '已见 $seen · 已捕 $caught',
    {'seen': seen, 'caught': caught},
  );
  static String get abilityUsageExclusive => t('abilityUsageExclusive', '专属');
  static String get abilityUsageRare => t('abilityUsageRare', '少见');
  static String get abilityUsageCommon => t('abilityUsageCommon', '常见');

  static String get gotIt => t('gotIt', '知道了');
  static String get viewAction => t('viewAction', '查看');
  static String get noneSelected => t('noneSelected', '未选择');
  static String get natureLabel => t('natureLabel', '性格');
  static String get statLabel => t('statLabel', '能力');
  static String get shinyLabel => t('shinyLabel', '闪光');
  static String get eggLabel => t('eggLabel', '蛋');
  static String get artworkStill => t('artworkStill', '立绘');
  static String get artworkAnimated => t('artworkAnimated', '动图');
  static String get artworkAnniversaryLogo =>
      t('artworkAnniversaryLogo', '30周年 Logo');
  static String get artworkFlipFront => t('artworkFlipFront', '切回正面');
  static String get artworkFlipBack => t('artworkFlipBack', '翻到背面');
  static String get artworkCloseSemantics =>
      t('artworkCloseSemantics', '关闭宝可梦大图');
  static String get loadingSemantics => t('loadingSemantics', '正在加载');
  static String get pickGameEdition => t('pickGameEdition', '选择游戏版本');
  static String get clearGameEdition => t('clearGameEdition', '清除版本');
  static String get mergedGameEdition => t('mergedGameEdition', '合并版本');
  static String get manageJourneyPacks =>
      t('manageJourneyPacks', '管理 Journey 资料包');
  static String generationFilterLabel(int generation) =>
      t('generationFilterLabel', '第$generation世代', {'generation': generation});
  static String generationCorrection(String types) =>
      t('generationCorrection', '世代修正：$types', {'types': types});
  static String generationCorrectionTypes(String types) =>
      t('generationCorrectionTypes', '世代修正属性：$types', {'types': types});
  static String get importFromParty => t('importFromParty', '从当前队伍带入');
  static String get dexNoObtainData => t('dexNoObtainData', '暂无获取资料');
  static String get dexNoMoveData => t('dexNoMoveData', '暂无招式资料');
  static String get dexMovesCrossVersionNote =>
      t('dexMovesCrossVersionNote', '跨版本招式汇总；学习等级请查看具体资料版本。');
  static String get locationDexUncaughtOnly =>
      t('locationDexUncaughtOnly', '仅未捕获');
  static String get locationDexAllCaught =>
      t('locationDexAllCaught', '这里的宝可梦已经全部捕获');
  static String encounterWeight(Object value) =>
      t('encounterWeight', '权重 $value', {'value': value});
  static String get encounterFormAmbiguous =>
      t('encounterFormAmbiguous', '形态未区分');
  static String encounterTera(String type) =>
      t('encounterTera', '太晶：$type', {'type': type});
  static String get encounterAlpha => t('encounterAlpha', '头目');
  static String get encounterTitan => t('encounterTitan', '霸主');
  static String get encounterTotem => t('encounterTotem', '图腾');
  static String get encounterRaid => t('encounterRaid', '团体战');
  static String get encounterFixed => t('encounterFixed', '固定出现');
  static String encounterConditionsShow(int count) =>
      t('encounterConditionsShow', '出现条件 $count 项', {'count': count});
  static String get encounterConditionsHide =>
      t('encounterConditionsHide', '收起出现条件');
  static String dexReferenceLoadMore(int visible, int total) => t(
    'dexReferenceLoadMore',
    '继续显示 · $visible/$total',
    {'visible': visible, 'total': total},
  );
  static String get itemCatPokeballs => t('itemCatPokeballs', '精灵球');
  static String get itemCatHealing => t('itemCatHealing', '回复药品');
  static String get itemCatBerries => t('itemCatBerries', '树果');
  static String get itemCatHeld => t('itemCatHeld', '携带道具');
  static String get itemCatEvolution => t('itemCatEvolution', '进化道具');
  static String get itemCatStatBoost => t('itemCatStatBoost', '能力提升');
  static String get itemCatBattle => t('itemCatBattle', '战斗道具');
  static String get itemCatMachines => t('itemCatMachines', '招式学习器');
  static String get itemCatDynamax => t('itemCatDynamax', '极巨结晶');
  static String get itemCatTMsMaterial => t('itemCatTMsMaterial', '招式材料');
  static String get itemCatCandy => t('itemCatCandy', '宝可梦糖果');
  static String get itemCatCooking => t('itemCatCooking', '料理素材');
  static String get itemCatMail => t('itemCatMail', '邮件');
  static String get itemCatDataCards => t('itemCatDataCards', '数据卡');
  static String get itemCatKey => t('itemCatKey', '剧情道具');
  static String get itemCatAdventure => t('itemCatAdventure', '冒险道具');
  static String get itemCatOther => t('itemCatOther', '其他道具');
  static String get itemGeneric => t('itemGeneric', '道具');
  static String itemBrowseCategory(String? category) {
    if (category == null) {
      return dexMoveFilterAll;
    }
    return switch (category) {
      '精灵球' => itemCatPokeballs,
      '回复药品' => itemCatHealing,
      '树果' => itemCatBerries,
      '携带道具' => itemCatHeld,
      '进化道具' => itemCatEvolution,
      '能力提升' => itemCatStatBoost,
      '战斗道具' => itemCatBattle,
      '招式学习器' => itemCatMachines,
      '极巨结晶' => itemCatDynamax,
      '招式材料' => itemCatTMsMaterial,
      '宝可梦糖果' => itemCatCandy,
      '料理素材' => itemCatCooking,
      '邮件' => itemCatMail,
      '数据卡' => itemCatDataCards,
      '剧情道具' => itemCatKey,
      '冒险道具' => itemCatAdventure,
      '其他道具' => itemCatOther,
      _ => category,
    };
  }

  static String get natureCatNeutral => t('natureCatNeutral', '中性');
  static String natureCatStatUp(String stat) =>
      t('natureCatStatUp', '$stat↑', {'stat': stat});
  static String get eggCatRegular => t('eggCatRegular', '常规组');
  static String get eggCatWater => t('eggCatWater', '水中组');
  static String get eggCatSpecial => t('eggCatSpecial', '特殊组');
  static String get weatherCatRegular => t('weatherCatRegular', '常规天气');
  static String get weatherCatHarsh => t('weatherCatHarsh', '强天气');
  static String get statusCatMajor => t('statusCatMajor', '主要异常');
  static String get statusCatOther => t('statusCatOther', '其他状态');
  static String itemPriceBuy({required bool compact, required String amount}) =>
      t(
        compact ? 'itemPriceBuyCompact' : 'itemPriceBuy',
        compact ? '买 $amount' : '购买 $amount',
        {'amount': amount},
      );
  static String itemPriceSell({
    required bool compact,
    required String amount,
  }) => t(
    compact ? 'itemPriceSellCompact' : 'itemPriceSell',
    compact ? '卖 $amount' : '出售 $amount',
    {'amount': amount},
  );
  static String referenceAvailabilityPending(String game) =>
      t('referenceAvailabilityPending', '$game · 可用性与价格资料待补齐', {'game': game});
  static String referenceAvailableNotShop(String game) =>
      t('referenceAvailableNotShop', '$game · 可获得，非普通商店售价', {'game': game});
  static String get teamPickMovesTitle => t('teamPickMovesTitle', '选择招式');
  static String teamPickMovesCount(int count) =>
      t('teamPickMovesCount', '选择招式 · $count/4', {'count': count});
  static String get teamSearchMovesHint =>
      t('teamSearchMovesHint', '搜索招式名称或编号');
  static String teamSlotTitle(int slot) => t(
    'teamSlotTitle',
    '$teamEditTitle · 槽位 $slot',
    {'title': teamEditTitle, 'slot': slot},
  );
  static String get teamCurrentMoves => t('teamCurrentMoves', '当前招式（最多 4 个）');
  static String get teamAdjustMoves => t('teamAdjustMoves', '调整招式');
  static String get teamAssistTitle => t('teamAssistTitle', '队伍与进化');
  static String get teamAssistHint =>
      t('teamAssistHint', '存档可读取的特性与招式会自动带入；手动队伍可在上方点成员补充。');
  static String get teamAssistEmpty => t('teamAssistEmpty', '添加队伍成员后可查看辅助信息');
  static String get teamAssistTapToFill =>
      t('teamAssistTapToFill', '点击成员可补充招式与特性');
  static String get teamInspectorHint =>
      t('teamInspectorHint', '点选格子查看进化与招式，再点编辑补充资料');
  static String get teamEditAction => t('teamEditAction', '编辑');
  static String get teamToQuickDamage => t('teamToQuickDamage', '带入伤害速算');
  static String teamMovePpBoost(int count) =>
      t('teamMovePpBoost', '增强 $count', {'count': count});
  static String teamNatureFact(String nature) =>
      t('teamNatureFact', '$nature性格', {'nature': nature});
  static String teamFormIndex(int index) =>
      t('teamFormIndex', '形态索引 $index', {'index': index});
  static String teamExperience(int value) =>
      t('teamExperience', '经验 $value', {'value': value});
  static String teamFriendship(int value) =>
      t('teamFriendship', '亲密度 $value', {'value': value});
  static String teamHeldItem(String name) =>
      t('teamHeldItem', '携带 $name', {'name': name});
  static String teamItemNumber(int id) =>
      t('teamItemNumber', '道具 #$id', {'id': id});
  static String teamStatsLine(String stats) =>
      t('teamStatsLine', '能力 $stats', {'stats': stats});
  static String teamIvLine(String values) =>
      t('teamIvLine', 'IV（HP/攻/防/速/特攻/特防）$values', {'values': values});
  static String teamEvLine(String values) =>
      t('teamEvLine', 'EV（HP/攻/防/速/特攻/特防）$values', {'values': values});
  static String teamAbilityLine(String name) =>
      t('teamAbilityLine', '特性：$name', {'name': name});
  static String teamNatureLine(String nature) =>
      t('teamNatureLine', '性格：$nature', {'nature': nature});
  static String teamHeldLine(String name) =>
      t('teamHeldLine', '携带：$name', {'name': name});
  static String teamMovesCount(int count) =>
      t('teamMovesCount', '招式 $count/4', {'count': count});
  static String teamCanEvolve(String names) =>
      t('teamCanEvolve', '可进化：$names', {'names': names});
  static String get moveCategoryPhysical => t('moveCategoryPhysical', '物理');
  static String get moveCategorySpecial => t('moveCategorySpecial', '特殊');
  static String get moveCategoryStatus => t('moveCategoryStatus', '变化');
  static String moveCategory(String category) => switch (category) {
    'physical' => moveCategoryPhysical,
    'special' => moveCategorySpecial,
    'status' => moveCategoryStatus,
    _ => category,
  };
  static String get damageNone => t('damageNone', '无伤害');
  static String get damageGuaranteedKo => t('damageGuaranteedKo', '稳秒杀');
  static String get damagePossibleKo => t('damagePossibleKo', '可能秒杀');
  static String get damagePossible2hko => t('damagePossible2hko', '可能两招击杀');
  static String get damageLow => t('damageLow', '伤害偏低');
  static String get tankImmune => t('tankImmune', '完全免疫或无伤');
  static String get tankGuaranteedKo => t('tankGuaranteedKo', '扛不住（必倒）');
  static String get tankPossibleKo => t('tankPossibleKo', '有风险（可能被秒）');
  static String get tankPossible2hko => t('tankPossible2hko', '较危险（两招可能倒）');
  static String get tankLikelySurvives => t('tankLikelySurvives', '大概率能扛住');

  static String askTitoDexClarificationPrefix(String label) => t(
    'askTitoDexClarificationPrefix',
    '已确认对象是“$label”。原问题：',
    {'label': label},
  );
  static String get askTitoDexHistoryClearTitle =>
      t('askTitoDexHistoryClearTitle', '清除全部问答？');
  static String get askTitoDexHistoryCompactTitle =>
      t('askTitoDexHistoryCompactTitle', '压缩问答记录？');
  static String get askTitoDexHistoryClearBody =>
      t('askTitoDexHistoryClearBody', '这会删除当前设备上的全部问答记录，无法撤销。');
  static String get askTitoDexHistoryCompactBody =>
      t('askTitoDexHistoryCompactBody', '将只保留最近 10 条问答，较早记录会从当前设备删除。');
  static String get askTitoDexHistoryClearConfirm =>
      t('askTitoDexHistoryClearConfirm', '确认清除');
  static String get askTitoDexHistoryCompactConfirm =>
      t('askTitoDexHistoryCompactConfirm', '确认压缩');
  static String get askTitoDexStatusChecking =>
      t('askTitoDexStatusChecking', '检查 --');
  static String askTitoDexStatusOnlineCount(int enabled, int total) => t(
    'askTitoDexStatusOnlineCount',
    '在线 $enabled/$total',
    {'enabled': enabled, 'total': total},
  );
  static String get askTitoDexStatusClosed =>
      t('askTitoDexStatusClosed', '已关闭');
  static String get askTitoDexStatusLocalOnly =>
      t('askTitoDexStatusLocalOnly', '仅本地');
  static String askTitoDexConnectionSemantics(String status) =>
      t('askTitoDexConnectionSemantics', '连接状态：$status', {'status': status});
  static String askTitoDexHistoryCount(int count, int limit) => t(
    'askTitoDexHistoryCount',
    '问答 $count/$limit',
    {'count': count, 'limit': limit},
  );
  static String askTitoDexHistoryCountSemantics(int count, int limit) => t(
    'askTitoDexHistoryCountSemantics',
    '问答记录 $count/$limit，点击管理',
    {'count': count, 'limit': limit},
  );
  static String askTitoDexEditionSemantics(String edition) => t(
    'askTitoDexEditionSemantics',
    '当前游戏版本 $edition，点击切换',
    {'edition': edition},
  );
  static String askTitoDexSaveBadgeCount(int count) =>
      t('askTitoDexSaveBadgeCount', '存档徽章 $count 枚（仅计数）', {'count': count});
  static String askTitoDexConnectionDialogTitle(
    int enabled,
    int total,
    int history,
    int limit,
  ) => t(
    'askTitoDexConnectionDialogTitle',
    '连接状态 · $enabled/$total\n问答记录 · $history/$limit',
    {'enabled': enabled, 'total': total, 'history': history, 'limit': limit},
  );
  static String get askTitoDexBroadTrialHint => t(
    'askTitoDexBroadTrialHint',
    '当前为宽范围试用：仍只接受宝可梦主题和固定来源域名，但证据不足时会降为低置信度回答，不再直接丢弃。',
  );
  static String get askTitoDexCapQwen =>
      t('askTitoDexCapQwen', 'Qwen · 回答整理/核对');
  static String get askTitoDexCapAiSearch =>
      t('askTitoDexCapAiSearch', 'AI Search · R2 索引');
  static String get askTitoDexCapBundle =>
      t('askTitoDexCapBundle', 'TitoDex Bundle · 结构化校验');
  static String get askTitoDexCapEncyclopedia =>
      t('askTitoDexCapEncyclopedia', '百科资料 · 多个限定来源');
  static String askTitoDexCapWebSearch(String provider) =>
      t('askTitoDexCapWebSearch', '联网 · $provider', {'provider': provider});
  static String get askTitoDexCapWebSearchGeneric =>
      t('askTitoDexCapWebSearchGeneric', '联网搜索');
  static String get askTitoDexCapAvailable => t('askTitoDexCapAvailable', '可用');
  static String get askTitoDexCapDisconnected =>
      t('askTitoDexCapDisconnected', '未连接');
  static String askTitoDexHistorySheetTitle(int count, int limit) => t(
    'askTitoDexHistorySheetTitle',
    '问答记录 · $count/$limit',
    {'count': count, 'limit': limit},
  );
  static String askTitoDexHistorySheetHint(int limit) => t(
    'askTitoDexHistorySheetHint',
    '记录只保存在当前设备；连续追问只会带入当前游戏最近 $limit 条。',
    {'limit': limit},
  );
  static String get askTitoDexHistoryEmpty =>
      t('askTitoDexHistoryEmpty', '还没有问答记录');
  static String get askTitoDexHistoryCompactAction =>
      t('askTitoDexHistoryCompactAction', '压缩到 10 条');
  static String get askTitoDexHistoryClearAction =>
      t('askTitoDexHistoryClearAction', '清除全部');
  static String get askTitoDexAnswerPlaceholder =>
      t('askTitoDexAnswerPlaceholder', '回答会显示在这里');
  static String get askTitoDexIdlePrefix => t('askTitoDexIdlePrefix', '陪你');
  static String get askTitoDexIdleSuffix => t('askTitoDexIdleSuffix', '，继续旅程。');
  static String get askTitoDexIdlePrompt =>
      t('askTitoDexIdlePrompt', '从旅途中的一个小问题开始。');
  static List<String> get askTitoDexIdleTopics => [
    t('askIdlePokemon', '查宝可梦'),
    t('askIdleMoves', '查招式'),
    t('askIdleTypes', '查属性'),
    t('askIdleBerries', '查树果'),
    t('askIdleEvolution', '查进化'),
    t('askIdleLevel', '查升级'),
    t('askIdleItems', '查道具'),
    t('askIdleRoute', '查路线'),
    t('askIdleAbilities', '查特性'),
    t('askIdleBreeding', '查培育'),
    t('askIdleStats', '查能力值'),
    t('askIdleWeather', '查天气'),
    t('askIdleGeneral', '查资料'),
  ];
  static String get askMotionLocal => t('askMotionLocal', '正在翻阅本地记录');
  static String get askMotionResolve => t('askMotionResolve', '正在确认问题与版本');
  static String get askMotionVerify => t('askMotionVerify', '正在核对版本与来源');
  static String get askMotionOrganize => t('askMotionOrganize', '正在整理回答');
  static String get askMotionNoMatch => t('askMotionNoMatch', '暂未找到匹配答案');
  static String get askMotionClarify => t('askMotionClarify', '需要确认问题');
  static String get askMotionFailed => t('askMotionFailed', '暂时无法完成');
  static String askMotionLookup(String topic) => switch (topic) {
    'capture' => t('askMotionCapture', '正在查找宝可梦资料'),
    'moves' => t('askMotionMoves', '正在查阅招式记录'),
    'types' => t('askMotionTypes', '正在查看属性关系'),
    'berry' || 'berries' => t('askMotionBerries', '正在对照树果效果'),
    'evolution' => t('askMotionEvolution', '正在查看进化条件'),
    'level' => t('askMotionLevel', '正在查找升级方式'),
    'items' => t('askMotionItems', '正在查找道具资料'),
    'route' => t('askMotionRoute', '正在展开路线资料'),
    'abilities' => t('askMotionAbilities', '正在查看特性记录'),
    'breeding' => t('askMotionBreeding', '正在查阅培育资料'),
    'stats' => t('askMotionStats', '正在查阅能力数据'),
    'weather' => t('askMotionWeather', '正在查看天气效果'),
    _ => t('askMotionGeneral', '正在查找相关资料'),
  };
  static String get askTitoDexProgressCheckingLocal =>
      t('askTitoDexProgressCheckingLocal', '正在翻本地资料');
  static String get askTitoDexProgressContactingWorker =>
      t('askTitoDexProgressContactingWorker', '正在交叉核对资料与联网来源');
  static String get askTitoDexProgressRetrievingSources =>
      t('askTitoDexProgressRetrievingSources', '正在从资料库和联网来源找线索');
  static String get askTitoDexProgressResolvingQuestion =>
      t('askTitoDexProgressResolvingQuestion', '正在确认版本与问题里的对象');
  static String get askTitoDexProgressVerifyingAnswer =>
      t('askTitoDexProgressVerifyingAnswer', '正在交叉核对资料与联网来源');
  static String get askTitoDexProgressRevealingAnswer =>
      t('askTitoDexProgressRevealingAnswer', '正在写入已核验回答');
  static String get askTitoDexProgressDone =>
      t('askTitoDexProgressDone', '回答完成');
  static String get askTitoDexAnswerVerified =>
      t('askTitoDexAnswerVerified', '回答已核验');
  static String get askTitoDexClarificationPrompt =>
      t('askTitoDexClarificationPrompt', '请选择你明确指的是哪一个：');
  static String askTitoDexSourceAccessed(String host, String accessedAt) => t(
    'askTitoDexSourceAccessed',
    '$host · 查阅 $accessedAt',
    {'host': host, 'accessedAt': accessedAt},
  );
  static String get askTitoDexContinueInApp =>
      t('askTitoDexContinueInApp', '在 TitoDex 里继续查看');
  static String get askTitoDexEntityPokemon =>
      t('askTitoDexEntityPokemon', '图鉴');
  static String get askTitoDexEntityItem => t('askTitoDexEntityItem', '道具');
  static String get askTitoDexEntityMove => t('askTitoDexEntityMove', '招式');
  static String get askTitoDexEntityAbility =>
      t('askTitoDexEntityAbility', '特性');
  static String get askTitoDexRouteDeepseekNative =>
      t('askTitoDexRouteDeepseekNative', 'DeepSeek 原生联网回答');
  static String get askTitoDexRouteMultiSource =>
      t('askTitoDexRouteMultiSource', 'Qwen × DeepSeek 交叉核对');
  static String get askTitoDexSourceDeepseekWeb =>
      t('askTitoDexSourceDeepseekWeb', 'DeepSeek 联网');
  static String get askTitoDexSourceDeepseekNativeShort =>
      t('askTitoDexSourceDeepseekNativeShort', 'DeepSeek 原生');
  static String get askTitoDexLiveJoinComma =>
      t('askTitoDexLiveJoinComma', '，');
  static String get askTitoDexLiveJoinSemicolon =>
      t('askTitoDexLiveJoinSemicolon', '；');
  static String askTitoDexLiveStageBody(String stage, String body) => t(
    'askTitoDexLiveStageBody',
    '$stage，$body',
    {'stage': stage, 'body': body},
  );
  static String get askTitoDexStageCheckingLocal =>
      t('askTitoDexStageCheckingLocal', '先翻本地审核笔记');
  static String get askTitoDexStageContactingWorker =>
      t('askTitoDexStageContactingWorker', '正在连接 Journey Assistant');
  static String get askTitoDexStageRetrievingSources =>
      t('askTitoDexStageRetrievingSources', '正在汇集限定来源');
  static String get askTitoDexStageResolvingQuestion =>
      t('askTitoDexStageResolvingQuestion', '正在确认问题与版本');
  static String get askTitoDexStageVerifyingAnswer =>
      t('askTitoDexStageVerifyingAnswer', '正在交叉核验答案');
  static String get askTitoDexStageRevealingAnswer =>
      t('askTitoDexStageRevealingAnswer', '正在整理已核验回答');
  static String askTitoDexCompanionSearching(String name) =>
      t('askTitoDexCompanionSearching', '$name正在查找答案', {'name': name});
  static String askTitoDexCompanionReady(String name) =>
      t('askTitoDexCompanionReady', '$name已准备好', {'name': name});
  static String askTitoDexCompanionIdle(String name) =>
      t('askTitoDexCompanionIdle', '$name在这里陪你', {'name': name});
  static String get askTitoDexCompanionIdleHint =>
      t('askTitoDexCompanionIdleHint', '可以问路线、捕捉地点，也可以问刚开始玩什么最重要。');
  static List<String> askTitoDexLocalMessageTemplates(String name) => [
    t('askTitoDexLocalMsg1', '$name正在树果口袋里翻找线索…', {'name': name}),
    t('askTitoDexLocalMsg2', '$name沿着脚印追踪可靠答案…', {'name': name}),
    t('askTitoDexLocalMsg3', '$name正在核对版本，免得跑错地图…', {'name': name}),
    t('askTitoDexLocalMsg4', '$name把资料卡一张张摆整齐…', {'name': name}),
    t('askTitoDexLocalMsg5', '$name对资料页使用了「看破」…', {'name': name}),
  ];
  static List<String> askTitoDexWorkerMessageTemplates(String name) => [
    t('askTitoDexWorkerMsg1', '$name正在等洛托姆线路传回消息…', {'name': name}),
    t('askTitoDexWorkerMsg2', '$name在等索引或模型接手这道题…', {'name': name}),
    t('askTitoDexWorkerMsg3', '$name正在询问资料库与联网来源…', {'name': name}),
    t('askTitoDexWorkerMsg4', '$name正在确认答案真的适合当前版本…', {'name': name}),
  ];
  static List<String> askTitoDexResolvingMessageTemplates(String name) => [
    t('askTitoDexResolvingMsg1', '$name正在把你的问法对上游戏里的对象…', {'name': name}),
    t('askTitoDexResolvingMsg2', '$name正在确认版本，免得把不同世代混在一起…', {'name': name}),
  ];
  static List<String> askTitoDexVerifyingMessageTemplates(String name) => [
    t('askTitoDexVerifyingMsg1', '$name正在让结构化资料和百科彼此作证…', {'name': name}),
    t('askTitoDexVerifyingMsg2', '$name正在检查地点、数值和版本是否一致…', {'name': name}),
  ];
  static List<String> askTitoDexRevealingMessageTemplates(String name) => [
    t('askTitoDexRevealingMsg1', '$name正在把核验过的线索整理成好读的回答…', {'name': name}),
    t('askTitoDexRevealingMsg2', '$name正在收好引用，再把答案交给你…', {'name': name}),
  ];
  static String askTitoDexViewCitations(String label) =>
      t('askTitoDexViewCitations', '$label，查看详细引用', {'label': label});
}
