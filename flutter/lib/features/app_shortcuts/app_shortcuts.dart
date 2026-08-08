import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppShortcutOption {
  const AppShortcutOption({
    required this.id,
    required this.labelZh,
    required this.route,
    required this.section,
    this.referenceFilename,
  });

  final String id;
  final String labelZh;
  final String route;
  final AppShortcutSection section;
  final String? referenceFilename;

  static const dex = AppShortcutOption(
    id: 'dex',
    labelZh: '图鉴',
    route: '/dex',
    section: AppShortcutSection.primary,
  );
  static const search = AppShortcutOption(
    id: 'search',
    labelZh: '搜索',
    route: '/search',
    section: AppShortcutSection.primary,
  );
  static const moves = AppShortcutOption(
    id: 'moves',
    labelZh: '招式图鉴',
    route: '/dex/moves',
    section: AppShortcutSection.reference,
  );
  static const abilities = AppShortcutOption(
    id: 'abilities',
    labelZh: '特性图鉴',
    route: '/dex/abilities',
    section: AppShortcutSection.reference,
  );
  static const locations = AppShortcutOption(
    id: 'locations',
    labelZh: '地点图鉴',
    route: '/dex/locations',
    section: AppShortcutSection.reference,
  );
  static const items = AppShortcutOption(
    id: 'items',
    labelZh: '道具',
    route: '/search/reference/json?kind=items',
    section: AppShortcutSection.reference,
    referenceFilename: 'items.json',
  );
  static const natures = AppShortcutOption(
    id: 'natures',
    labelZh: '性格',
    route: '/search/reference/json?kind=natures',
    section: AppShortcutSection.reference,
    referenceFilename: 'natures.json',
  );
  static const eggGroups = AppShortcutOption(
    id: 'egg-groups',
    labelZh: '蛋组',
    route: '/search/reference/json?kind=egg-groups',
    section: AppShortcutSection.reference,
    referenceFilename: 'egg_groups.json',
  );
  static const weather = AppShortcutOption(
    id: 'weather',
    labelZh: '天气',
    route: '/search/reference/json?kind=weather',
    section: AppShortcutSection.reference,
    referenceFilename: 'weather.json',
  );
  static const terrains = AppShortcutOption(
    id: 'terrains',
    labelZh: '场地',
    route: '/search/reference/json?kind=terrains',
    section: AppShortcutSection.reference,
    referenceFilename: 'terrains.json',
  );
  static const status = AppShortcutOption(
    id: 'status',
    labelZh: '异常状态',
    route: '/search/reference/json?kind=status',
    section: AppShortcutSection.reference,
    referenceFilename: 'status_conditions.json',
  );
  static const quiz = AppShortcutOption(
    id: 'quiz',
    labelZh: '猜猜我是谁',
    route: '/dex/quiz',
    section: AppShortcutSection.reference,
  );
  static const typeMatchup = AppShortcutOption(
    id: 'type-matchup',
    labelZh: '属性克制',
    route: '/search/companion/type-matchup',
    section: AppShortcutSection.tool,
  );
  static const statCalc = AppShortcutOption(
    id: 'stat-calc',
    labelZh: '能力值计算',
    route: '/search/companion/stat-calc',
    section: AppShortcutSection.tool,
  );
  static const blindSpot = AppShortcutOption(
    id: 'blind-spot',
    labelZh: '打击/联防盲点',
    route: '/search/companion/blind-spot',
    section: AppShortcutSection.tool,
  );
  static const quickDamage = AppShortcutOption(
    id: 'quick-damage',
    labelZh: '伤害速算',
    route: '/search/companion/quick-damage',
    section: AppShortcutSection.tool,
  );

  static const all = [
    dex,
    search,
    moves,
    abilities,
    locations,
    items,
    natures,
    eggGroups,
    weather,
    terrains,
    status,
    quiz,
    typeMatchup,
    statCalc,
    blindSpot,
    quickDamage,
  ];
  static const defaults = [dex, search];

  static AppShortcutOption? fromId(String? id) {
    for (final option in all) {
      if (option.id == id) {
        return option;
      }
    }
    return null;
  }

  Map<String, String> toPlatformMap() => {
    'id': id,
    'label': labelZh,
    'route': route,
  };
}

enum AppShortcutSection {
  primary('默认入口'),
  reference('图鉴与资料'),
  tool('对战工具');

  const AppShortcutSection(this.labelZh);

  final String labelZh;
}

class AppShortcutsPlatform {
  AppShortcutsPlatform({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'com.tito.titodex/app_shortcuts';
  final MethodChannel _channel;

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  void setRouteHandler(ValueChanged<String>? onRoute) {
    if (!_supported) {
      return;
    }
    if (onRoute == null) {
      _channel.setMethodCallHandler(null);
      return;
    }
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shortcutOpened' && call.arguments is String) {
        onRoute(call.arguments as String);
      }
    });
  }

  Future<String?> consumeInitialRoute() async {
    if (!_supported) {
      return null;
    }
    try {
      return await _channel.invokeMethod<String>('getInitialRoute');
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> update(List<AppShortcutOption> shortcuts) async {
    if (!_supported) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('updateShortcuts', {
        'shortcuts': shortcuts.map((item) => item.toPlatformMap()).toList(),
      });
    } on MissingPluginException {
      // Unit tests and non-Android embedders intentionally have no channel.
    }
  }

  @visibleForTesting
  Future<List<String>> dynamicShortcutIds() async {
    if (!_supported) {
      return const [];
    }
    try {
      return await _channel.invokeListMethod<String>('getDynamicShortcutIds') ??
          const [];
    } on MissingPluginException {
      return const [];
    }
  }
}

class AppShortcutPreferences extends ChangeNotifier {
  AppShortcutPreferences({AppShortcutsPlatform? platform})
    : _platform = platform ?? AppShortcutsPlatform();

  static const maxSelected = 3;
  static const _preferenceKey = 'appShortcuts.selected';

  final AppShortcutsPlatform _platform;
  List<AppShortcutOption> _selected = AppShortcutOption.defaults;
  bool _loaded = false;

  List<AppShortcutOption> get selected => List.unmodifiable(_selected);

  bool isSelected(AppShortcutOption option) =>
      _selected.any((item) => item.id == option.id);

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_preferenceKey);
    _selected = _normalize(
      stored?.map(AppShortcutOption.fromId).whereType<AppShortcutOption>() ??
          AppShortcutOption.defaults,
    );
    _loaded = true;
    notifyListeners();
    await _platform.update(_selected);
  }

  Future<bool> toggle(AppShortcutOption option) async {
    final next = [..._selected];
    final index = next.indexWhere((item) => item.id == option.id);
    if (index >= 0) {
      next.removeAt(index);
    } else if (next.length < maxSelected) {
      next.add(option);
    } else {
      return false;
    }
    await setSelected(next);
    return true;
  }

  Future<void> setSelected(Iterable<AppShortcutOption> selected) async {
    _selected = _normalize(selected);
    _loaded = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _preferenceKey,
      _selected.map((item) => item.id).toList(),
    );
    await _platform.update(_selected);
  }

  List<AppShortcutOption> _normalize(Iterable<AppShortcutOption> shortcuts) {
    final selectedIds = shortcuts.map((shortcut) => shortcut.id).toSet();
    return AppShortcutOption.all
        .where((shortcut) => selectedIds.contains(shortcut.id))
        .take(maxSelected)
        .toList(growable: false);
  }
}

final appShortcutPreferences = AppShortcutPreferences();
