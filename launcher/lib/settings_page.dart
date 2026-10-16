import 'package:flutter/material.dart';
import 'appearance.dart';
import 'device_bridge.dart';
import 'models.dart';
import 'weather.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.settings,
    required this.bridge,
    required this.weatherService,
    required this.isDefaultHome,
    required this.onChanged,
    required this.onCityChanged,
    required this.onAction,
    required this.onMessage,
    required this.onBack,
    required this.onCustomize,
    required this.onManageFavorites,
  });
  final LauncherSettings settings;
  final DeviceBridge bridge;
  final WeatherService weatherService;
  final bool isDefaultHome;
  final VoidCallback onChanged, onBack, onCustomize, onManageFavorites;
  final ValueChanged<WeatherCity?> onCityChanged;
  final Future<void> Function(String, [Map<String, dynamic>?]) onAction;
  final ValueChanged<String> onMessage;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final name = TextEditingController(text: widget.settings.name);
  late final motto = TextEditingController(text: widget.settings.motto);
  bool choosingImage = false;
  @override
  void dispose() {
    name.dispose();
    motto.dispose();
    super.dispose();
  }

  void change(VoidCallback apply) {
    apply();
    widget.onChanged();
  }

  Future<void> photo() async {
    if (choosingImage) return;
    setState(() => choosingImage = true);
    try {
      final path = await widget.bridge.pickWallpaper();
      if (path != null && mounted) {
        change(() {
          widget.settings.photo = path;
          widget.settings.wallpaper = Wallpaper.photo;
        });
      }
    } catch (_) {
      widget.onMessage('图片未能导入，请换一张图片重试');
    } finally {
      if (mounted) setState(() => choosingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                tooltip: '回到桌面',
                icon: Icon(Icons.arrow_back_rounded, color: backgroundInk(s)),
              ),
              Text(
                '桌面设置',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: backgroundInk(s),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            children: [
              section('桌面与布局', [
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: widget.onCustomize,
                      child: const Text('编排桌面'),
                    ),
                    OutlinedButton(
                      onPressed: widget.onManageFavorites,
                      child: const Text('整理收藏'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  '调整模块顺序、显示状态与宽度。长按桌面空白处也可进入。',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 14),
                Text(
                  '表面浓度 · ${(s.opacity * 100).round()}%',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Slider(
                  label: '${(s.opacity * 100).round()}%',
                  value: s.opacity,
                  min: .7,
                  max: 1,
                  divisions: 6,
                  onChanged: (v) => change(() => s.opacity = v),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('局部磨砂'),
                  subtitle: const Text(
                    '关闭可减少图形开销',
                    style: TextStyle(fontSize: 11),
                  ),
                  value: s.blurPanels,
                  onChanged: (v) => change(() => s.blurPanels = v),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('减少动态效果'),
                  value: s.reduceMotion,
                  onChanged: (v) => change(() => s.reduceMotion = v),
                ),
                const SizedBox(height: 8),
                const Text('应用库每行图标'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final columns in [3, 4, 5, 6])
                      ChoiceChip(
                        label: Text('$columns'),
                        selected: s.libraryColumns == columns,
                        onSelected: (_) =>
                            change(() => s.libraryColumns = columns),
                      ),
                  ],
                ),
              ]),
              section('你的掌机桌面', [
                Text(
                  widget.isDefaultHome
                      ? 'TitoDex Launcher 已是默认桌面'
                      : '将 TitoDex Launcher 设为默认桌面，按 Home 键即可回来。',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => widget.onAction('requestHome'),
                      icon: const Icon(Icons.home_rounded),
                      label: Text(widget.isDefaultHome ? '管理默认桌面' : '设为默认桌面'),
                    ),
                    TextButton(
                      onPressed: () => widget.onAction('homeSettings'),
                      child: const Text('切换其他桌面'),
                    ),
                  ],
                ),
              ]),
              section('Trainer Card', [
                TextField(
                  controller: name,
                  maxLength: 20,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: '训练家称呼',
                    counterText: '',
                  ),
                  onSubmitted: (_) => saveName(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: motto,
                  maxLength: 40,
                  decoration: const InputDecoration(labelText: '一句话签名（整行卡片显示）'),
                  onSubmitted: (_) => saveName(),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: saveName,
                    child: const Text('保存称呼'),
                  ),
                ),
                const Text('称呼保存在这台掌机上。', style: TextStyle(fontSize: 12)),
              ]),
              section('界面主题', [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: LauncherStyle.values
                      .map(
                        (v) => ChoiceChip(
                          label: Text(styleLabels[v.index]),
                          selected: s.style == v,
                          onSelected: (_) => change(() => s.style = v),
                        ),
                      )
                      .toList(),
                ),
              ]),
              section('壁纸与效果', [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: Wallpaper.values
                      .map(
                        (v) => ChoiceChip(
                          label: Text(wallpaperLabels[v.index]),
                          selected: s.wallpaper == v,
                          onSelected: (_) {
                            if (v == Wallpaper.photo && s.photo == null) {
                              photo();
                            } else {
                              change(() => s.wallpaper = v);
                            }
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: WallpaperEffect.values
                      .map(
                        (v) => ChoiceChip(
                          label: Text(effectLabels[v.index]),
                          selected: s.effect == v,
                          onSelected: (_) => change(() => s.effect = v),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: choosingImage ? null : photo,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(choosingImage ? '正在导入…' : '从设备选照片'),
                    ),
                    TextButton(
                      onPressed: () => change(s.resetWallpaper),
                      child: const Text('恢复默认背景'),
                    ),
                  ],
                ),
              ]),
              section('时间与天气', [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('24 小时制'),
                  value: s.use24Hour,
                  onChanged: (v) => change(() => s.use24Hour = v),
                ),
                Text(
                  s.city?.name ?? '尚未设置城市',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 7),
                const Text(
                  '选择城市后联网获取天气，无需定位权限。天气由 Open-Meteo 提供，每 30 分钟更新一次。',
                  style: TextStyle(fontSize: 12),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () async {
                        final city = await showDialog<WeatherCity>(
                          context: context,
                          builder: (_) =>
                              CityDialog(service: widget.weatherService),
                        );
                        if (city != null) widget.onCityChanged(city);
                      },
                      child: const Text('选择城市'),
                    ),
                    if (s.city != null)
                      TextButton(
                        onPressed: () => widget.onCityChanged(null),
                        child: const Text('关闭天气'),
                      ),
                  ],
                ),
              ]),
              section('设备与操作', [
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => widget.onAction('wifiSettings'),
                      icon: const Icon(Icons.wifi_rounded),
                      label: const Text('网络设置'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => widget.onAction('systemSettings'),
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('系统设置'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  '方向键 / 左摇杆：移动焦点\nA：确认 · B：返回桌面 · 长按空白：编排\n应用库长按或 X：收藏 / 应用信息\n屏幕边缘滑动：呼出 Android 系统栏',
                  style: TextStyle(fontSize: 12, height: 1.7),
                ),
              ]),
              section('TitoDex Launcher', [
                const Text(
                  '0.2.0 · 掌机预览版',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 7),
                const Text(
                  '轻量桌面，连接你的应用与 TitoDex。\n本地称呼与收藏独立保存。\n非官方个人项目，与 Nintendo、GAME FREAK、The Pokémon Company 无隶属或赞助关系。',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
                TextButton(
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: 'TitoDex Launcher',
                    applicationVersion: '0.2.0',
                    applicationLegalese:
                        'Weather data: Open-Meteo (CC BY 4.0).\nhttps://open-meteo.com/\nNunito: SIL Open Font License 1.1.',
                  ),
                  child: const Text('开源许可与来源'),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  void saveName() {
    change(() {
      widget.settings.name = name.text.trim().isEmpty
          ? '训练家'
          : name.text.trim();
      widget.settings.motto = motto.text.trim();
    });
    FocusManager.instance.primaryFocus?.unfocus();
    widget.onMessage('训练家称呼已保存');
  }

  Widget section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Surface(
      style: widget.settings.style,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}

class CityDialog extends StatefulWidget {
  const CityDialog({super.key, required this.service});
  final WeatherService service;
  @override
  State<CityDialog> createState() => _CityDialogState();
}

class _CityDialogState extends State<CityDialog> {
  final query = TextEditingController();
  List<WeatherCity> cities = [];
  String? message;
  bool loading = false;
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> search() async {
    if (loading || query.text.trim().length < 2) {
      if (!loading) setState(() => message = '请输入至少两个字，例如 上海 或 Shanghai');
      return;
    }
    setState(() {
      loading = true;
      message = null;
    });
    try {
      final value = await widget.service.search(query.text);
      if (mounted) {
        setState(() {
          cities = value;
          if (cities.isEmpty) message = '没有找到城市，可尝试拼音或英文名';
        });
      }
    } catch (_) {
      if (mounted) setState(() => message = '城市搜索暂时不可用，请检查网络后重试');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('选择天气城市'),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '搜索词会发送给 Open-Meteo 城市服务。选择结果后才会开启天气。',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: query,
              autofocus: false,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => search(),
              decoration: const InputDecoration(hintText: '城市名 / 拼音'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: loading ? null : search,
              child: Text(loading ? '正在搜索…' : '搜索城市'),
            ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(message!, style: const TextStyle(fontSize: 12)),
              ),
            ...cities.map(
              (city) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(city.name, style: const TextStyle(fontSize: 13)),
                onTap: () => Navigator.pop(context, city),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
    ],
  );
}
