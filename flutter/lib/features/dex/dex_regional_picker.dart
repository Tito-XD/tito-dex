import 'package:flutter/material.dart';

import '../../l10n/app_zh.dart';
import '../../widgets/tito_animated_size_switcher.dart';
import 'dex_browse_scope.dart';
import 'dex_game_scope.dart';

Future<DexBrowseScope?> showDexBrowseScopePicker(
  BuildContext context, {
  required DexBrowseScope selected,
}) {
  return showModalBottomSheet<DexBrowseScope>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _DexBrowseScopePicker(selected: selected),
  );
}

enum _PickerLevel { root, region, generation }

class _DexBrowseScopePicker extends StatefulWidget {
  const _DexBrowseScopePicker({required this.selected});

  final DexBrowseScope selected;

  @override
  State<_DexBrowseScopePicker> createState() => _DexBrowseScopePickerState();
}

class _DexBrowseScopePickerState extends State<_DexBrowseScopePicker> {
  _PickerLevel _level = _PickerLevel.root;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.62,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  if (_level != _PickerLevel.root)
                    IconButton(
                      onPressed: () =>
                          setState(() => _level = _PickerLevel.root),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  Expanded(
                    child: TitoAnimatedSizeSwitcher(
                      switchKey: ValueKey<int>(_level.index),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        switch (_level) {
                          _PickerLevel.root => AppZh.dexPickBrowseScope,
                          _PickerLevel.region => AppZh.dexBrowseByRegion,
                          _PickerLevel.generation =>
                            AppZh.dexBrowseByGeneration,
                        },
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TitoAnimatedSizeSwitcher(
                switchKey: ValueKey<int>(_level.index),
                child: _body(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() => switch (_level) {
    _PickerLevel.root => ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.map_rounded),
          title: Text(AppZh.dexBrowseByRegion),
          subtitle: Text(AppZh.dexBrowseByRegionHint),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => setState(() => _level = _PickerLevel.region),
        ),
        ListTile(
          leading: const Icon(Icons.auto_awesome_rounded),
          title: Text(AppZh.dexBrowseByGeneration),
          subtitle: Text(AppZh.dexBrowseByGenerationHint),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => setState(() => _level = _PickerLevel.generation),
        ),
      ],
    ),
    _PickerLevel.region => ListView(
      children: [
        for (final region in DexRegionalPokedex.values)
          ListTile(
            leading: const Icon(Icons.map_rounded),
            title: Text('${region.labelZh}图鉴'),
            selected: widget.selected == DexBrowseScope.region(region),
            trailing: widget.selected == DexBrowseScope.region(region)
                ? const Icon(Icons.check_rounded)
                : null,
            onTap: () => Navigator.pop(context, DexBrowseScope.region(region)),
          ),
      ],
    ),
    _PickerLevel.generation => ListView(
      children: [
        for (var generation = 1; generation <= 9; generation++)
          ListTile(
            leading: CircleAvatar(child: Text('G$generation')),
            title: Text(generationLabelZh(generation)),
            subtitle: Text(AppZh.dexGenerationDebutHint),
            selected: widget.selected == DexBrowseScope.generation(generation),
            trailing: widget.selected == DexBrowseScope.generation(generation)
                ? const Icon(Icons.check_rounded)
                : null,
            onTap: () =>
                Navigator.pop(context, DexBrowseScope.generation(generation)),
          ),
      ],
    ),
  };
}
