import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'appearance.dart';
import 'device_bridge.dart';
import 'models.dart';
import 'weather.dart';
import 'settings_page.dart';
import 'home_page.dart';
import 'layout_editor.dart';
import 'library_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Nunito',
    ], await rootBundle.loadString('assets/licenses/nunito-OFL.txt'));
  });
  runApp(const LauncherApp());
}

class LauncherApp extends StatefulWidget {
  const LauncherApp({super.key, this.bridge, this.weather});
  final DeviceBridge? bridge;
  final WeatherService? weather;
  @override
  State<LauncherApp> createState() => _LauncherAppState();
}

class _LauncherAppState extends State<LauncherApp> with WidgetsBindingObserver {
  late final DeviceBridge bridge = widget.bridge ?? DeviceBridge();
  late final WeatherService weatherService = widget.weather ?? WeatherService();
  final messenger = GlobalKey<ScaffoldMessengerState>();
  final navigator = GlobalKey<NavigatorState>();
  final titoFocus = FocusNode(debugLabel: "TitoDex entry");
  LauncherSettings settings = LauncherSettings();
  List<LaunchApp> apps = [];
  Map<dynamic, dynamic> status = {};
  WeatherReading? weather;
  String? weatherError, appsError;
  bool loading = true, refreshing = false, weatherBusy = false;
  int page = 0, weatherRequest = 0;
  Timer? timer;
  DateTime now = DateTime.now();
  DateTime? lastWeatherAttempt;
  bool searchOnOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DeviceBridge.channel.setMethodCallHandler((call) async {
      if (call.method == 'home' && mounted) {
        navigator.currentState?.popUntil((route) => route.isFirst);
        go(0);
      }
    });
    unawaited(initialize());
    startTicker();
  }

  void startTicker() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => now = DateTime.now());
      unawaited(refreshStatus());
      unawaited(refreshWeather());
    });
  }

  Future<void> initialize() async {
    try {
      settings = LauncherSettings.decode(await bridge.readSettings());
    } catch (_) {
      notify('设置读取失败，已使用默认外观');
    }
    if (!mounted) return;
    setState(() => loading = false);
    await Future.wait([refreshApps(), refreshStatus(), refreshWeather()]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      timer?.cancel();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      startTicker();
      setState(() => now = DateTime.now());
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
      );
      unawaited(refreshApps());
      unawaited(refreshStatus());
      unawaited(refreshWeather());
    }
  }

  Future<void> refreshApps() async {
    if (refreshing) return;
    refreshing = true;
    try {
      final result = await bridge.apps();
      if (mounted) {
        setState(() {
          apps = result;
          appsError = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => appsError = '应用库读取失败，点击重试');
    } finally {
      refreshing = false;
    }
  }

  Future<void> refreshStatus() async {
    try {
      final value = await bridge.status();
      if (mounted) setState(() => status = value);
    } catch (_) {
      /* Status is optional; keep home accessible. */
    }
  }

  Future<void> refreshWeather({bool force = false}) async {
    final city = settings.city;
    if (city == null || weatherBusy) return;
    if (!force &&
        lastWeatherAttempt != null &&
        DateTime.now().difference(lastWeatherAttempt!) <
            const Duration(minutes: 30)) {
      return;
    }
    final request = ++weatherRequest;
    lastWeatherAttempt = DateTime.now();
    weatherBusy = true;
    try {
      final value = await weatherService.current(city);
      if (mounted && request == weatherRequest) {
        setState(() {
          weather = value;
          weatherError = null;
        });
      }
    } catch (_) {
      if (mounted && request == weatherRequest) {
        setState(() => weatherError = '天气暂不可用');
      }
    } finally {
      if (request == weatherRequest) weatherBusy = false;
    }
  }

  void notify(String text) =>
      messenger.currentState?.showSnackBar(SnackBar(content: Text(text)));
  void changed() {
    setState(() {});
    unawaited(save());
  }

  Future<void> save() async {
    try {
      await bridge.save(settings);
    } catch (_) {
      notify('设置保存失败，请重试');
    }
  }

  void cityChanged(WeatherCity? city) {
    weatherRequest++;
    weatherBusy = false;
    lastWeatherAttempt = null;
    settings.city = city;
    weather = null;
    weatherError = null;
    changed();
    unawaited(refreshWeather(force: true));
  }

  Future<void> launch(String package, [String? activity]) async {
    try {
      if (await bridge.launch(package, activity)) {
        final app = apps
            .where(
              (a) =>
                  a.package == package &&
                  (activity == null || a.activity == activity),
            )
            .firstOrNull;
        if (app != null && mounted) {
          settings.recordLaunch(app.id);
          changed();
        }
      } else {
        notify(
          package == titoDexPackage
              ? '尚未安装 TitoDex，请先安装正式版 TitoDex App'
              : '应用无法打开，可能已停用或卸载',
        );
        unawaited(refreshApps());
      }
    } catch (_) {
      notify('应用未能打开，请稍后重试');
    }
  }

  Future<void> deviceAction(String name, [Map<String, dynamic>? args]) async {
    try {
      if (!await bridge.action(name, args)) notify('设备暂不支持此入口');
    } catch (_) {
      notify('系统入口暂时不可用');
    }
  }

  void favorite(LaunchApp app) {
    if (settings.favorites.contains(app.id)) {
      settings.favorites.remove(app.id);
    } else if (settings.favorites.length < 12) {
      settings.favorites.add(app.id);
    } else {
      notify('最多收藏 12 个应用，请先取消一个收藏');
      return;
    }
    changed();
  }

  void go(int target) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => page = target);
    if (target != 1) searchOnOpen = false;
    if (target == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && page == 0) titoFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    titoFocus.dispose();
    WidgetsBinding.instance.removeObserver(this);
    DeviceBridge.channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'TitoDex Launcher',
    scaffoldMessengerKey: messenger,
    navigatorKey: navigator,
    theme: launcherTheme(settings.style),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations:
            settings.reduceMotion || MediaQuery.disableAnimationsOf(context),
      ),
      child: child!,
    ),
    home: Builder(
      builder: (context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            if (page != 0) {
              go(0);
            } else {
              titoFocus.requestFocus();
            }
          }
        },
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          body: Stack(
            fit: StackFit.expand,
            children: [
              LauncherBackground(settings: settings),
              SafeArea(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : FocusTraversalGroup(
                        child: Column(
                          children: [
                            if (page != 1 ||
                                MediaQuery.viewInsetsOf(context).bottom == 0)
                              header(),
                            Expanded(
                              child: switch (page) {
                                1 => LibraryPage(
                                  settings: settings,
                                  apps: apps,
                                  searchOnOpen: searchOnOpen,
                                  keyboardVisible:
                                      MediaQuery.viewInsetsOf(context).bottom >
                                      0,
                                  error: appsError,
                                  onBack: () => go(0),
                                  onLaunch: (app) =>
                                      launch(app.package, app.activity),
                                  onOptions: (app) => appMenu(context, app),
                                  onRefresh: refreshApps,
                                  onManageFavorites: () => go(4),
                                ),
                                3 => LayoutEditor(
                                  settings: settings,
                                  onChanged: changed,
                                  onBack: () => go(0),
                                ),
                                4 => FavoritesEditor(
                                  settings: settings,
                                  apps: apps,
                                  onChanged: changed,
                                  onBack: () => go(1),
                                ),
                                2 => SettingsPage(
                                  settings: settings,
                                  bridge: bridge,
                                  weatherService: weatherService,
                                  isDefaultHome: status['defaultHome'] == true,
                                  onChanged: changed,
                                  onCityChanged: cityChanged,
                                  onAction: deviceAction,
                                  onMessage: notify,
                                  onBack: () => go(0),
                                  onCustomize: () => go(3),
                                  onManageFavorites: () => go(4),
                                ),
                                _ => HomePage(
                                  settings: settings,
                                  apps: apps,
                                  now: now,
                                  weather: weather,
                                  weatherError: weatherError,
                                  titoFocus: titoFocus,
                                  onTito: () => launch(titoDexPackage),
                                  onLibrary: () => go(1),
                                  onSearch: () {
                                    searchOnOpen = true;
                                    go(1);
                                  },
                                  onSettings: () => go(2),
                                  onCustomize: () => go(3),
                                  onApp: (app) =>
                                      launch(app.package, app.activity),
                                  onAppOptions: (app) => appMenu(context, app),
                                  onWeather: () => settings.city == null
                                      ? go(2)
                                      : showWeather(context),
                                ),
                              },
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget header() {
    final color = backgroundInk(settings);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
      child: SizedBox(
        height: 22,
        child: Row(
          children: [
            Text(
              'TitoDex',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: .2,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'HOME',
              style: TextStyle(
                color: color.withValues(alpha: .7),
                fontSize: 8,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            Semantics(
              label: status['online'] == true ? '网络已连接' : '网络离线',
              child: Icon(
                status['online'] == true
                    ? Icons.wifi_rounded
                    : Icons.wifi_off_rounded,
                size: 13,
                color: color,
              ),
            ),
            const SizedBox(width: 9),
            Text(
              status['battery'] is int && status['battery'] >= 0
                  ? '${status['charging'] == true ? '充电 · ' : ''}${status['battery']}%'
                  : '—',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void showWeather(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(settings.city!.name),
        content: Text(
          [
            if (weather != null)
              '${weather!.temperature.round()}°C · ${weather!.description}',
            if (weather != null)
              '上次更新 ${clockLabel(weather!.receivedAt, true)}',
            if (weatherError != null) weatherError!,
            '来源：Open-Meteo · 每 30 分钟刷新',
          ].join('\n'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              go(2);
            },
            child: const Text('更换城市'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              unawaited(refreshWeather(force: true));
            },
            child: const Text('刷新'),
          ),
        ],
      ),
    );
  }

  void appMenu(BuildContext context, LaunchApp app) {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .82,
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  app.label,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(app.package, style: const TextStyle(fontSize: 11)),
                ListTile(
                  leading: const Icon(Icons.open_in_new_rounded),
                  title: const Text('打开应用'),
                  onTap: () {
                    Navigator.pop(context);
                    launch(app.package, app.activity);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.star_rounded),
                  title: Text(
                    settings.favorites.contains(app.id) ? '取消收藏' : '收藏到桌面',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    favorite(app);
                  },
                ),
                if (settings.favorites.contains(app.id))
                  ListTile(
                    title: const Text('整理收藏顺序'),
                    onTap: () {
                      Navigator.pop(context);
                      go(4);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('应用信息'),
                  onTap: () {
                    Navigator.pop(context);
                    deviceAction('appInfo', {'package': app.package});
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
