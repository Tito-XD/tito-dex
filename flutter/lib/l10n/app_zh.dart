/// Simplified Chinese UI copy for TitoDex.
abstract final class AppZh {
  static const appTitle = 'TitoDex';

  static const navHome = '首页';
  static const navTeam = '队伍';
  static const navJourney = '旅程';
  static const navDex = '图鉴';
  static const navSearch = '搜索';
  static const navSettings = '设置';

  static const trainerCard = '训练家卡片';
  static const companion = '同伴';

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

  static const dexScopeNote = '全国图鉴 1–493（魂银），中文名与属性来自 PokeAPI；同行宝可梦标记为已捕获。';
  static const dexCaught = '已捕获';
  static const dexSeen = '已见过';
  static const dexUnknown = '未捕获';
  static const dexTabNational = '全国图鉴';
  static const dexTabJourney = '旅程同行';
  static const dexJourneyEmpty = '当前旅程同行里还没有载入图鉴条目，试试全国图鉴。';
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

  static const settingsDexOffline = '离线图鉴缓存';
  static const settingsDexOfflineHint =
      '一次性下载全国图鉴 1–493：中文名、属性图标、克制关系、进化链、升级招式与压缩立绘。招式按 ID 去重复用，属性图标全局共用。';
  static const settingsDexOfflineUnset = '尚未下载离线图鉴';
  static String settingsDexOfflinePartial(int pokemonCount) =>
      '部分缓存 $pokemonCount / 493，可点「继续下载」补全';
  static String settingsDexOfflineReady(
    int pokemonCount,
    int moveCount,
    String size,
    String downloadedAt,
  ) => '已缓存 $pokemonCount 只 · $moveCount 个招式 · $size · $downloadedAt';
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
      'done' => '完成',
      'partial' => '部分完成',
      _ => phase,
    };
    return '正在缓存$phaseLabel $current / $total';
  }

  static const snackDexOfflineDone = '离线图鉴已下载完成';
  static String snackDexOfflinePartial(int count) =>
      '已缓存 $count / 493 只宝可梦，可再次点击继续下载补全';
  static const snackDexOfflineCleared = '已清除离线图鉴缓存';
  static const snackDexOfflineFailed = '离线图鉴下载失败';

  static const searchPlaceholder = '搜索全国图鉴：中文名、英文名、编号或属性…';
  static const searchPrompt = '搜索宝可梦';
  static const searchEmptyHint = '可搜索 1–493 号宝可梦的中文名、英文名、编号或属性。';
  static const searchRecent = '最近搜索';
  static const searchTrending = '热门搜索';
  static const searchNoResults = '没有找到匹配的宝可梦。';

  static const recentTimeline = '最近动态';
  static const nextPrefix = '下一步：';
  static const journeyTimelineEmpty = '还没有旅程记录';

  static const teamNote = '队伍数据来自当前存档或演示旅程。后续可在这里编辑同行宝可梦。';
  static String teamSubtitle(int count) => '同行 $count 只';

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

  static String placeholderScreen(String title) => '$title 页面开发中';
}
