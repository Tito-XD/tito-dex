import 'package:flutter/material.dart';
import 'appearance.dart';
import 'models.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({
    super.key,
    required this.settings,
    required this.apps,
    required this.onBack,
    required this.onLaunch,
    required this.onOptions,
    required this.onRefresh,
    required this.onManageFavorites,
    this.searchOnOpen = false,
    this.keyboardVisible = false,
    this.error,
  });
  final LauncherSettings settings;
  final List<LaunchApp> apps;
  final VoidCallback onBack, onRefresh, onManageFavorites;
  final ValueChanged<LaunchApp> onLaunch, onOptions;
  final bool searchOnOpen, keyboardVisible;
  final String? error;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final search = TextEditingController();
  bool favoritesOnly = false;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filterApps(
      widget.apps,
      search.text,
      widget.settings.favorites,
      favoritesOnly,
    );
    final ink = backgroundInk(widget.settings);
    final keyboard = widget.keyboardVisible;
    return Column(
      children: [
        if (!keyboard)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 14, 5),
            child: Row(
              children: [
                IconButton(
                  tooltip: '回到桌面',
                  onPressed: widget.onBack,
                  icon: Icon(Icons.arrow_back_rounded, color: ink),
                ),
                Text(
                  '应用库',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '刷新应用',
                  onPressed: widget.onRefresh,
                  icon: Icon(Icons.refresh_rounded, color: ink),
                ),
              ],
            ),
          ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            decoration: BoxDecoration(
              color: cream.withValues(alpha: .92),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                TextField(
                  controller: search,
                  autofocus: widget.searchOnOpen,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '搜索应用或包名',
                    isDense: true,
                    prefixIcon: keyboard
                        ? IconButton(
                            tooltip: '回到桌面',
                            onPressed: widget.onBack,
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              size: 20,
                            ),
                          )
                        : const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清除搜索',
                            onPressed: () {
                              search.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded, size: 20),
                          ),
                  ),
                ),
                if (!keyboard)
                  Padding(
                    padding: const EdgeInsets.only(top: 7, bottom: 2),
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('全部'),
                          selected: !favoritesOnly,
                          onSelected: (_) =>
                              setState(() => favoritesOnly = false),
                        ),
                        const SizedBox(width: 7),
                        ChoiceChip(
                          label: const Text('收藏'),
                          selected: favoritesOnly,
                          onSelected: (_) =>
                              setState(() => favoritesOnly = true),
                        ),
                        const Spacer(),
                        if (favoritesOnly)
                          TextButton(
                            onPressed: widget.onManageFavorites,
                            child: const Text('整理'),
                          )
                        else
                          Text(
                            '${filtered.length} 个',
                            style: const TextStyle(fontSize: 11, color: navy),
                          ),
                      ],
                    ),
                  ),
                if (widget.error != null)
                  TextButton(
                    onPressed: widget.onRefresh,
                    child: Text(widget.error!),
                  ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            search.text.isNotEmpty
                                ? '没有匹配的应用'
                                : favoritesOnly
                                ? '还没有收藏\n长按应用或按 X 添加'
                                : '没有可启动的应用',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) => GridView.builder(
                            key: ValueKey('library-grid-$favoritesOnly'),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: filtered.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: widget.settings.libraryColumns
                                      .clamp(
                                        2,
                                        (constraints.maxWidth /
                                                (75 *
                                                    MediaQuery.textScalerOf(
                                                      context,
                                                    ).scale(1).clamp(1, 1.6)))
                                            .floor()
                                            .clamp(2, 8),
                                      ),
                                  mainAxisExtent:
                                      100 +
                                      (MediaQuery.textScalerOf(
                                                context,
                                              ).scale(24) -
                                              24)
                                          .clamp(0, 48),
                                  crossAxisSpacing: 4,
                                  mainAxisSpacing: 6,
                                ),
                            itemBuilder: (context, i) {
                              final app = filtered[i];
                              return DesktopButton(
                                key: ValueKey('app-${app.id}'),
                                autofocus:
                                    i == 0 &&
                                    !widget.searchOnOpen &&
                                    search.text.isEmpty,
                                label: app.label,
                                onPressed: () => widget.onLaunch(app),
                                onOptions: () => widget.onOptions(app),
                                radius: 16,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    3,
                                    9,
                                    3,
                                    3,
                                  ),
                                  child: Column(
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          appArtwork(app, 42),
                                          if (widget.settings.favorites
                                              .contains(app.id))
                                            Positioned(
                                              right: -3,
                                              bottom: -2,
                                              child: Container(
                                                width: 10,
                                                height: 10,
                                                decoration: BoxDecoration(
                                                  color: coral,
                                                  borderRadius:
                                                      BorderRadius.circular(5),
                                                  border: Border.all(
                                                    color: cream,
                                                    width: 2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 7),
                                      Text(
                                        app.label,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          height: 1.2,
                                          color: navy,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
                if (!keyboard)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 7),
                    child: Text(
                      '长按或 X 查看应用选项',
                      style: TextStyle(fontSize: 10, color: Color(0xff536273)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class FavoritesEditor extends StatelessWidget {
  const FavoritesEditor({
    super.key,
    required this.settings,
    required this.apps,
    required this.onChanged,
    required this.onBack,
  });
  final LauncherSettings settings;
  final List<LaunchApp> apps;
  final VoidCallback onChanged, onBack;
  @override
  Widget build(BuildContext context) {
    final ids = settings.favorites.toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 14, 6),
          child: Row(
            children: [
              IconButton(
                tooltip: '回到应用库',
                onPressed: onBack,
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: backgroundInk(settings),
                ),
              ),
              Text(
                '整理收藏',
                style: TextStyle(
                  fontSize: 22,
                  color: backgroundInk(settings),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            child: AirPanel(
              settings: settings,
              child: ids.isEmpty
                  ? const Center(child: Text('还没有收藏，去应用库挑几个吧。'))
                  : ReorderableListView.builder(
                      itemCount: ids.length,
                      buildDefaultDragHandles: false,
                      onReorderItem: (old, next) {
                        final id = ids.removeAt(old);
                        ids.insert(next, id);
                        settings.favorites = ids.toSet();
                        onChanged();
                      },
                      itemBuilder: (context, i) {
                        final id = ids[i];
                        final app = apps.where((a) => a.id == id).firstOrNull;
                        return Padding(
                          key: ValueKey(id),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  ReorderableDragStartListener(
                                    index: i,
                                    child: const Icon(
                                      Icons.drag_indicator_rounded,
                                      size: 19,
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  if (app != null) appArtwork(app, 32),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      app?.label ??
                                          '已卸载 · ${id.split('/').first}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '取消收藏 ${app?.label ?? id}',
                                    onPressed: () {
                                      settings.favorites.remove(id);
                                      onChanged();
                                    },
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: i == 0
                                        ? null
                                        : () {
                                            settings.moveFavorite(id, -1);
                                            onChanged();
                                          },
                                    child: const Text('前移'),
                                  ),
                                  TextButton(
                                    onPressed: i == ids.length - 1
                                        ? null
                                        : () {
                                            settings.moveFavorite(id, 1);
                                            onChanged();
                                          },
                                    child: const Text('后移'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
