import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'appearance.dart';
import 'models.dart';
import 'weather.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.settings,
    required this.apps,
    required this.now,
    required this.titoFocus,
    required this.onTito,
    required this.onLibrary,
    required this.onSearch,
    required this.onSettings,
    required this.onCustomize,
    required this.onApp,
    required this.onAppOptions,
    required this.onWeather,
    this.weather,
    this.weatherError,
  });
  final LauncherSettings settings;
  final List<LaunchApp> apps;
  final DateTime now;
  final FocusNode titoFocus;
  final VoidCallback onTito,
      onLibrary,
      onSearch,
      onSettings,
      onCustomize,
      onWeather;
  final ValueChanged<LaunchApp> onApp, onAppOptions;
  final WeatherReading? weather;
  final String? weatherError;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final width = math.min(bounds.maxWidth, 800.0);
      final small = bounds.maxHeight < 370;
      final topGap = switch (settings.layout) {
        HomeLayout.roam => (bounds.maxHeight * .13).clamp(18.0, 70.0),
        HomeLayout.dashboard => 12.0,
        HomeLayout.quiet => (bounds.maxHeight * .28).clamp(45.0, 125.0),
      };
      return Center(
        child: SizedBox(
          width: width,
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onLongPress: onCustomize,
                  child: ListView(
                    key: const PageStorageKey('home-scroll'),
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
                    children: [
                      _clock(small),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragEnd: (details) {
                          if ((details.primaryVelocity ?? 0) < -150) {
                            onLibrary();
                          }
                        },
                        child: SizedBox(
                          key: const ValueKey('wallpaper-window'),
                          height: topGap,
                        ),
                      ),
                      LayoutBuilder(
                        builder: (context, row) {
                          final gap = settings.style == LauncherStyle.flat
                              ? 12.0
                              : 14.0;
                          final single =
                              row.maxWidth < 300 ||
                              MediaQuery.textScalerOf(context).scale(1) > 1.5;
                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              for (final module in settings.modules.where(
                                (m) => m.visible,
                              ))
                                SizedBox(
                                  key: ValueKey('module-${module.module.name}'),
                                  width: module.wide || single
                                      ? row.maxWidth
                                      : (row.maxWidth - gap) / 2,
                                  child: _module(context, module),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                child: AirPanel(
                  settings: settings,
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DesktopButton(
                          label: '应用库',
                          onPressed: onLibrary,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Text(
                                '应用库',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 17,
                        color: const Color(0xff172638).withValues(alpha: .16),
                      ),
                      _dock('搜索', onSearch),
                      _dock('编排', onCustomize),
                      _dock('设置', onSettings),
                    ],
                  ),
                ),
              ),
              if (settings.showKeyHints)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'A 打开 · B 返回 · X 选项 · 长按空白处编排',
                    style: TextStyle(
                      color: backgroundInk(settings),
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
  Widget _dock(String label, VoidCallback action) => Expanded(
    child: DesktopButton(
      onPressed: action,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    ),
  );
  Widget _clock(bool small) {
    final color = backgroundInk(settings);
    final summary = settings.city == null
        ? '添加天气'
        : weatherError != null
        ? (weather == null
              ? '天气暂不可用'
              : '${weather!.temperature.round()}° · 上次更新')
        : weather == null
        ? '天气更新中'
        : '${weather!.temperature.round()}°  ${weather!.description}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  clockLabel(now, settings.use24Hour),
                  style: TextStyle(
                    fontSize: small ? 48 : 60,
                    height: 1.04,
                    letterSpacing: -2.4,
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                '${dateLabel(now)}${settings.use24Hour
                    ? ''
                    : now.hour < 12
                    ? ' · 上午'
                    : ' · 下午'}',
                style: TextStyle(fontSize: 12, color: color),
              ),
            ],
          ),
        ),
        if (settings.showWeather) ...[
          const SizedBox(width: 12),
          Flexible(
            flex: 2,
            child: DesktopButton(
              foreground: color,
              onPressed: onWeather,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (settings.city != null)
                      Text(
                        settings.city!.name.split(' · ').first,
                        style: TextStyle(color: color, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 3),
                    Text(
                      summary,
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _module(BuildContext context, ModuleConfig module) {
    switch (module.module) {
      case HomeModule.trainer:
        return AirPanel(
          settings: settings,
          padding: EdgeInsets.zero,
          child: DesktopButton(
            label: '编辑训练家称呼',
            onPressed: onSettings,
            onOptions: onCustomize,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        'TRAINER',
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w800,
                          color: Color(0xff687786),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: coral,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    settings.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      height: 1.1,
                      color: Color(0xff172638),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    greeting(now),
                    style: const TextStyle(
                      color: Color(0xff172638),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (module.wide) ...[
                    const SizedBox(height: 7),
                    Text(
                      settings.motto,
                      style: const TextStyle(
                        color: Color(0xff172638),
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      case HomeModule.titodex:
        return AirPanel(
          settings: settings,
          accent: true,
          padding: EdgeInsets.zero,
          child: DesktopButton(
            key: const ValueKey('launch-titodex'),
            label: '打开 TitoDex',
            onPressed: onTito,
            onOptions: onCustomize,
            focusNode: titoFocus,
            autofocus: true,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'POCKET COMPANION',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 8,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w800,
                      color: Color(0xff605b4a),
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'TitoDex',
                    style: TextStyle(
                      fontSize: 22,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: Color(0xff172638),
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          '继续小冒险',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xff172638),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      case HomeModule.favorites:
        return _appShelf(
          '常玩收藏',
          settings.orderedFavorites(apps),
          empty: '把喜欢的应用放在这里',
          compact: !module.wide,
        );
      case HomeModule.recent:
        return _appShelf(
          '最近打开',
          settings.recentApps(apps),
          empty: '从这里开启的应用，会留在这里',
          compact: !module.wide,
        );
    }
  }

  Widget _appShelf(
    String title,
    List<LaunchApp> items, {
    required String empty,
    required bool compact,
  }) => AirPanel(
    settings: settings,
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xff172638),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5,
                ),
              ),
            ),
            SizedBox(
              height: 27,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  minimumSize: const Size(36, 27),
                ),
                onPressed: onLibrary,
                child: Text(
                  items.isEmpty ? '添加' : '全部',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
          ],
        ),
        if (items.isEmpty)
          SizedBox(
            height: 31,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                empty,
                style: const TextStyle(fontSize: 11, color: Color(0xff536273)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
        else
          SizedBox(
            height: 66,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final app = items[i];
                return SizedBox(
                  width: compact ? 54 : 65,
                  child: DesktopButton(
                    label: app.label,
                    onPressed: () => onApp(app),
                    onOptions: () => onAppOptions(app),
                    radius: 12,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 3,
                        horizontal: 2,
                      ),
                      child: Column(
                        children: [
                          appArtwork(app, 34),
                          const SizedBox(height: 4),
                          Text(
                            app.label,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xff172638),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    ),
  );
}
