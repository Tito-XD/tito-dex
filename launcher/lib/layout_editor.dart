import 'package:flutter/material.dart';
import 'appearance.dart';
import 'models.dart';

class LayoutEditor extends StatelessWidget {
  const LayoutEditor({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.onBack,
  });
  final LauncherSettings settings;
  final VoidCallback onChanged, onBack;
  void change(VoidCallback edit) {
    edit();
    onChanged();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 18, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: '回到桌面',
              onPressed: onBack,
              icon: Icon(
                Icons.arrow_back_rounded,
                color: backgroundInk(settings),
              ),
            ),
            Expanded(
              child: Text(
                '编排桌面',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: backgroundInk(settings),
                ),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: backgroundInk(settings),
              ),
              onPressed: onBack,
              child: const Text('完成'),
            ),
          ],
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            AirPanel(
              settings: settings,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '选一种节奏',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: HomeLayout.values
                        .map(
                          (v) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 5),
                              child: DesktopButton(
                                onPressed: () =>
                                    change(() => settings.applyLayout(v)),
                                child: Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: settings.layout == v
                                        ? navy.withValues(alpha: .13)
                                        : Colors.white.withValues(alpha: .25),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Column(
                                    children: [
                                      SizedBox(
                                        height: 42,
                                        child: CustomPaint(
                                          painter: _LayoutGlyph(v),
                                          child: const SizedBox.expand(),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        layoutLabels[v.index],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '预设会重排模块，保留你的称呼、收藏和壁纸。',
                    style: TextStyle(fontSize: 11, color: Color(0xff536273)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AirPanel(
              settings: settings,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '模块顺序与尺寸',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '拖动把手排序，也可用上下按钮。TitoDex 始终保留。',
                    style: TextStyle(fontSize: 11),
                  ),
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: settings.modules.length,
                    onReorderItem: (old, next) =>
                        change(() => settings.moveModule(old, next)),
                    itemBuilder: (context, index) {
                      final module = settings.modules[index];
                      return Padding(
                        key: ValueKey(module.module),
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                ReorderableDragStartListener(
                                  index: index,
                                  child: const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.drag_indicator_rounded,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    moduleLabels[module.module]!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (module.module != HomeModule.titodex)
                                  Switch(
                                    key: ValueKey(
                                      'visible-${module.module.name}',
                                    ),
                                    value: module.visible,
                                    onChanged: (v) =>
                                        change(() => module.visible = v),
                                  )
                                else
                                  const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: Text(
                                      '固定',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ),
                              ],
                            ),
                            Wrap(
                              spacing: 5,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                ChoiceChip(
                                  key: ValueKey('half-${module.module.name}'),
                                  label: const Text('半宽'),
                                  selected: !module.wide,
                                  onSelected: (_) =>
                                      change(() => module.wide = false),
                                ),
                                ChoiceChip(
                                  key: ValueKey('wide-${module.module.name}'),
                                  label: const Text('整行'),
                                  selected: module.wide,
                                  onSelected: (_) =>
                                      change(() => module.wide = true),
                                ),
                                IconButton(
                                  tooltip: '${moduleLabels[module.module]}上移',
                                  onPressed: index == 0
                                      ? null
                                      : () => change(
                                          () => settings.moveModule(
                                            index,
                                            index - 1,
                                          ),
                                        ),
                                  icon: const Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 18,
                                  ),
                                ),
                                IconButton(
                                  tooltip: '${moduleLabels[module.module]}下移',
                                  onPressed:
                                      index == settings.modules.length - 1
                                      ? null
                                      : () => change(
                                          () => settings.moveModule(
                                            index,
                                            index + 1,
                                          ),
                                        ),
                                  icon: const Icon(
                                    Icons.arrow_downward_rounded,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AirPanel(
              settings: settings,
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('显示天气'),
                    value: settings.showWeather,
                    onChanged: (v) => change(() => settings.showWeather = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('显示按键提示'),
                    value: settings.showKeyHints,
                    onChanged: (v) => change(() => settings.showKeyHints = v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _LayoutGlyph extends CustomPainter {
  _LayoutGlyph(this.layout);
  final HomeLayout layout;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = navy.withValues(alpha: .6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(3, 2, size.width * .4, 5),
        const Radius.circular(2),
      ),
      p,
    );
    final y = layout == HomeLayout.dashboard
        ? 14.0
        : layout == HomeLayout.quiet
        ? 29.0
        : 22.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(3, y, size.width * .43, 10),
        const Radius.circular(3),
      ),
      p,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .52, y, size.width * .43, 10),
        const Radius.circular(3),
      ),
      p,
    );
    if (layout == HomeLayout.dashboard) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(3, 29, size.width - 6, 10),
          const Radius.circular(3),
        ),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_LayoutGlyph old) => old.layout != layout;
}
