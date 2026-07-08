/// Simplified Chinese UI copy for TitoDex.
abstract final class AppZh {
  static const appTitle = 'TitoDex';

  static const navHome = '首页';
  static const navTeam = '队伍';
  static const navJourney = '旅程';
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
  static String partySlot(int index) => '#$index';
  static const level = 'Lv';

  static const recentTimeline = '最近动态';
  static const nextPrefix = '下一步：';
  static const journeyTimelineEmpty = '还没有旅程记录';

  static const teamNote = '队伍数据来自当前存档或演示旅程。后续可在这里编辑同行宝可梦。';
  static String teamSubtitle(int count) => '同行 $count 只';

  static const settingsTrainerProfile = '训练家资料';
  static const settingsDisplayName = '显示名称';
  static const settingsDisplayNameHint = 'Tito';
  static const settingsSaveTrainerName = '保存名称';
  static const settingsSaveTrainerHint =
      '民间汉化版的显示名可能与存档字节解码不同。';
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
  static String snackSaveLoadedWarnings(int count) =>
      '已加载存档（$count 条解析提示）';
  static const snackMockRestored = '已恢复演示旅程';

  static const continueSheetTitle = '继续旅程';
  static const continueSheetPickEmulator = '选择要启动的模拟器';
  static const continueSheetLaunch = '启动';
  static const continueSheetChange = '换一个';
  static const continueSheetNoEmulators = '未找到已安装的模拟器应用';
  static const continueSheetDesktopHint = '模拟器启动目前仅支持 Android';
  static String continueSheetLaunching(String name) => '正在打开 $name…';
  static const snackEmulatorSaved = '已记住模拟器选择';
  static const snackEmulatorCleared = '已清除模拟器选择';
  static const snackEmulatorLaunchFailed = '无法启动该应用';

  static String placeholderScreen(String title) => '$title 页面开发中';
}
