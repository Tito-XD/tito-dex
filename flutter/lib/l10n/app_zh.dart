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
  static const level = 'Lv';

  static const recentTimeline = '最近动态';
  static const nextPrefix = '下一步：';

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

  static const settingsJourneyData = '旅程数据';
  static const settingsImportSave = '导入内置 PKMSS.sav';
  static const settingsResetMock = '恢复演示数据';

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
  static String snackSaveLoaded(String name, int partyCount) =>
      '已加载 $name 的存档 · 队伍 $partyCount 只';
  static String snackSaveLoadedWarnings(int count) =>
      '已加载存档（$count 条解析提示）';
  static const snackMockRestored = '已恢复演示旅程';

  static const continueSheetTitle = '继续旅程';
  static const continueSheetBody =
      '模拟器快捷启动将在下一阶段加入。现在「继续」用于确认当前旅程状态。';
  static const continueSheetOk = '知道了';

  static String placeholderScreen(String title) => '$title 页面开发中';
}
