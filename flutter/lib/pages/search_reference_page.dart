import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/game/game_edition_repository.dart';
import '../features/journey/ask_titodex_settings.dart';
import '../l10n/app_zh.dart';
import '../pages/dex/dex_json_reference_page.dart';
import '../theme/app_visual_style.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_buttons.dart';
import '../theme/tito_colors.dart';
import '../widgets/handheld_input.dart';
import '../widgets/secondary_page_scaffold.dart';
import '../widgets/sleep_tools_section.dart';
import '../widgets/sticker_card.dart';
import '../widgets/sticker_pressable.dart';

class SearchReferencePage extends StatelessWidget {
  const SearchReferencePage({
    super.key,
    this.assistantDisplayMode,
    this.onAskTitoDex,
  });

  final SearchAssistantDisplayMode? assistantDisplayMode;
  final VoidCallback? onAskTitoDex;

  bool _showCompactAssistant() {
    final enabled = askTitoDexSettings.extensionEnabled;
    final selected =
        assistantDisplayMode ?? askTitoDexSettings.searchDisplayMode;
    return enabled && selected == SearchAssistantDisplayMode.compact;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([askTitoDexSettings, gameEditionRepository]),
      builder: (context, _) {
        return Material(
          type: MaterialType.transparency,
          child: SecondaryPageScaffold(
            title: AppZh.searchHubReference,
            subtitle: gameEditionRepository.edition.label,
            children: [
              if (_showCompactAssistant()) ...[
                _compactAssistantCard(),
                const SizedBox(height: 12),
              ],
              _ReferenceCatalogGrid(entries: _catalogEntries(context)),
              const SizedBox(height: 12),
              const SleepToolsSection(),
            ],
          ),
        );
      },
    );
  }

  Widget _compactAssistantCard() => StickerCard(
    key: const Key('search-assistant-compact'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(AppZh.extensionSearchAsk, style: SecondaryTypography.onCard.h15),
        const SizedBox(height: 8),
        TitoPrimaryButton(
          label: AppZh.askTitoDexEntry,
          onPressed: onAskTitoDex,
          expanded: true,
        ),
      ],
    ),
  );

  List<_ReferenceCatalogEntry> _catalogEntries(BuildContext context) {
    return [
      (
        icon: Icons.flash_on_rounded,
        label: AppZh.dexReferenceMoves,
        onTap: () => context.push('/dex/moves'),
      ),
      (
        icon: Icons.auto_awesome_rounded,
        label: AppZh.dexReferenceAbilities,
        onTap: () => context.push('/dex/abilities'),
      ),
      (
        icon: Icons.place_rounded,
        label: AppZh.locationDexTitle,
        onTap: () => context.push('/dex/locations'),
      ),
      (
        icon: Icons.mood_rounded,
        label: AppZh.searchRefNatures,
        onTap: () => openDexJsonReference(
          context,
          title: AppZh.searchRefNatures,
          cdnPath: '/v5/natures.json',
        ),
      ),
      (
        icon: Icons.egg_rounded,
        label: AppZh.searchRefEggGroups,
        onTap: () => openDexJsonReference(
          context,
          title: AppZh.searchRefEggGroups,
          cdnPath: '/v5/egg_groups.json',
        ),
      ),
      (
        icon: Icons.backpack_rounded,
        label: AppZh.searchRefItems,
        onTap: () => openDexJsonReference(
          context,
          title: AppZh.searchRefItems,
          cdnPath: '/v5/items.json',
        ),
      ),
      (
        icon: Icons.cloud_rounded,
        label: AppZh.searchRefWeather,
        onTap: () => openDexJsonReference(
          context,
          title: AppZh.searchRefWeather,
          cdnPath: '/v5/weather.json',
        ),
      ),
      (
        icon: Icons.landscape_rounded,
        label: AppZh.searchRefTerrains,
        onTap: () => openDexJsonReference(
          context,
          title: AppZh.searchRefTerrains,
          cdnPath: '/v5/terrains.json',
        ),
      ),
      (
        icon: Icons.healing_rounded,
        label: AppZh.searchRefStatus,
        onTap: () => openDexJsonReference(
          context,
          title: AppZh.searchRefStatus,
          cdnPath: '/v5/status_conditions.json',
        ),
      ),
      (
        icon: Icons.menu_book_rounded,
        label: AppZh.searchHubRegionalDex,
        onTap: () => context.push('/dex'),
      ),
      (
        icon: Icons.help_center_rounded,
        label: AppZh.quizTitle,
        onTap: () => context.push('/dex/quiz'),
      ),
    ];
  }
}

typedef _ReferenceCatalogEntry = ({
  IconData icon,
  String label,
  VoidCallback onTap,
});

class _ReferenceCatalogGrid extends StatelessWidget {
  const _ReferenceCatalogGrid({required this.entries});

  final List<_ReferenceCatalogEntry> entries;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 300 ? 2 : 3;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.92,
          ),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return _ReferenceGridCard(
              icon: entry.icon,
              label: entry.label,
              onTap: entry.onTap,
            );
          },
        );
      },
    );
  }
}

class _ReferenceGridCard extends StatelessWidget {
  const _ReferenceGridCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(TitoRadii.md);
    final iconColor = appVisualStyle.usesFlatUi
        ? scheme.primary
        : TitoColors.deepBlue;
    return HandheldFocusDecorator(
      onActivate: onTap,
      borderRadius: radius,
      child: StickerPressable(
        borderRadius: radius,
        ownShadow: false,
        child: StickerCard(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 26, color: iconColor),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SecondaryTypography.onCard.small12.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
