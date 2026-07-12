import 'package:flutter/material.dart';

import '../features/dex/dex_models.dart';
import '../features/dex/dex_repository.dart';
import '../features/game/game_edition.dart';
import '../features/game/game_edition_controller.dart';
import '../features/dex/type_chart.dart';
import '../l10n/app_zh.dart';
import '../theme/device_layout.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../theme/error_text.dart';
import '../theme/tito_font_scale.dart';
import '../widgets/handheld_input.dart';
import '../widgets/pokemon_card.dart';
import '../widgets/pokemon_detail_sections.dart';
import '../widgets/secondary_page_scaffold.dart';
import '../widgets/sticker_card.dart';
import '../widgets/tito_skeleton.dart';
import '../widgets/tito_skeleton_gate.dart';

class PokemonDetailPage extends StatefulWidget {
  const PokemonDetailPage({super.key, required this.pokemonId});

  final int pokemonId;

  @override
  State<PokemonDetailPage> createState() => _PokemonDetailPageState();
}

class _PokemonDetailPageState extends State<PokemonDetailPage> {
  PokemonDetail? _detail;
  (String, String)? _errorCopy;
  bool _loading = true;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    gameEditionController.addListener(_onEditionChanged);
    _loadDetail();
  }

  @override
  void dispose() {
    gameEditionController.removeListener(_onEditionChanged);
    super.dispose();
  }

  void _onEditionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickOtherEdition() async {
    final edition = gameEditionController.edition;
    final picked = await showModalBottomSheet<GameEdition>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.55,
            minChildSize: 0.35,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return ListView(
                controller: scrollController,
                children: [
                  for (final group in gameEditionPickerGroups.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        group.key,
                        style: SecondaryTypography.onCard.team12.copyWith(
                          color: TitoColors.mutedInk,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    for (final item in group.value)
                      ListTile(
                        title: Text(item.labelZh),
                        trailing:
                            edition == item ? const Icon(Icons.check_rounded) : null,
                        selected: edition == item,
                        onTap: () => Navigator.pop(context, item),
                      ),
                  ],
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        );
      },
    );
    if (picked != null && mounted) {
      await gameEditionController.setEdition(picked);
    }
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _errorCopy = null;
    });
    try {
      final detail = await dexRepository.getDetail(widget.pokemonId);
      if (!mounted) {
        return;
      }
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorCopy = splitUserFacingError(error);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final errorCopy = _errorCopy;
    final padding = DeviceLayout.pagePadding(context);

    return TitoFontScale(
      multiplier: 1.0,
      child: Column(
        children: [
          Expanded(
          child: TitoSkeletonGate(
            loading: _loading,
            skeleton: ListView(
              padding: padding,
              children: const [
                TitoDetailHeaderSkeleton(),
                SizedBox(height: 12),
                TitoCardSkeleton(height: 140),
                SizedBox(height: 12),
                TitoCardSkeleton(height: 88),
              ],
            ),
            child: errorCopy != null
                ? _ErrorBody(
                    copy: errorCopy,
                    onRetry: _loadDetail,
                  )
                : detail == null
                    ? const SizedBox.shrink()
                    : ListView(
                        padding: padding.copyWith(bottom: 12),
                        children: [
                          // Same size as second-level page headers (Dex list).
                          const SecondaryPageAppBar(
                            title: AppZh.navDex,
                            showSettings: false,
                          ),
                          const SizedBox(height: 8),
                          PokemonDetailHeader(
                            detail: detail,
                            compact: true,
                            showSettingsAction: false,
                          ),
                          const SizedBox(height: 12),
                          ..._tabSections(detail, _currentTabIndex),
                          const SizedBox(height: 72),
                        ],
                      ),
          ),
        ),
        _DetailBottomTabs(
          currentIndex: _currentTabIndex,
          onSelected: (index) {
            if (_currentTabIndex != index) {
              setState(() => _currentTabIndex = index);
            }
          },
        ),
        ],
      ),
    );
  }

  List<Widget> _tabSections(PokemonDetail detail, int tabIndex) {
    return switch (tabIndex) {
      0 => _introSections(detail),
      1 => _basicSections(detail),
      2 => _obtainSections(detail),
      _ => _movesSections(detail),
    };
  }

  List<Widget> _introSections(PokemonDetail detail) {
    final edition = gameEditionController.edition;
    return [
      FlavorTextCarousel(
        entries: detail.flavorEntries,
        edition: edition,
        initialIndex: flavorEntryDefaultIndex(detail, edition),
        onPickOtherEdition: _pickOtherEdition,
      ),
      const SizedBox(height: 12),
      IntroMetaCard(detail: detail),
      const SizedBox(height: 12),
      AbilitiesCard(
        abilities: detail.abilities,
        onPickOtherEdition: _pickOtherEdition,
      ),
      const SizedBox(height: 12),
      StickerCard(
        child: Text(
          AppZh.dexApiNote,
          style: SecondaryTypography.onCard.small12.copyWith(
            color: TitoColors.mutedInk,
            height: 1.4,
          ),
        ),
      ),
    ];
  }

  List<Widget> _basicSections(PokemonDetail detail) {
    return [
      if (detail.baseStats != null) ...[
        BaseStatsSection(stats: detail.baseStats!),
        const SizedBox(height: 12),
      ],
      if (detail.typeMultipliers.isNotEmpty) ...[
        TypeEffectivenessGrid(multipliers: detail.typeMultipliers),
        const SizedBox(height: 12),
      ],
      StickerCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppZh.dexStabEffective,
              style: SecondaryTypography.onCard.h15,
            ),
            const SizedBox(height: 8),
            TypeChipRow(
              types: detail.stabSuperEffective,
              typeKeys: detail.stabSuperEffective
                  .map(typeEnForZh)
                  .whereType<String>()
                  .toList(),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _obtainSections(PokemonDetail detail) {
    final edition = gameEditionController.edition;
    // v0.4.0: filter by obtainLocationsByGame[edition.moveSetKey] with fallback.
    final locations = obtainLocationsForEdition(detail, edition);
    final obtainTitle = '${edition.labelZh} 出现地点';

    final sections = <Widget>[
      if (locations.isNotEmpty)
        ObtainLocationsCard(
          locations: locations,
          title: obtainTitle,
        )
      else
        StickerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                obtainTitle,
                style: SecondaryTypography.onCard.h15,
              ),
              const SizedBox(height: 8),
              Text(
                AppZh.dexObtainEmpty,
                style: SecondaryTypography.onCard.body14,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _pickOtherEdition,
                child: const Text('选择其他版本查看'),
              ),
            ],
          ),
        ),
    ];

    if (detail.evolutionChain != null) {
      sections.addAll([
        const SizedBox(height: 12),
        StickerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppZh.dexEvolution,
                style: SecondaryTypography.onCard.h15,
              ),
              const SizedBox(height: 12),
              EvolutionChainVerticalView(
                root: detail.evolutionChain!,
                highlightId: detail.summary.id,
              ),
            ],
          ),
        ),
      ]);
    }

    return sections;
  }

  List<Widget> _movesSections(PokemonDetail detail) {
    final edition = gameEditionController.edition;
    final moveSet = detail.moveSetForKey(edition.moveSetKey);

    return [
      CompactGameEditionPicker(
        edition: edition,
        onEditionChanged: (next) => gameEditionController.setEdition(next),
      ),
      const SizedBox(height: 12),
      MoveSetPanel(
        moveSet: moveSet,
        editionLabel: edition.labelZh,
      ),
    ];
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.copy, required this.onRetry});

  final (String, String) copy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: DeviceLayout.pagePadding(context),
      children: [
        StickerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                copy.$1,
                style: SecondaryTypography.onCard.body14.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                copy.$2,
                style: SecondaryTypography.onCard.small12.copyWith(
                  color: TitoColors.mutedInk,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onRetry,
                child: const Text(AppZh.dexRetry),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailBottomTabs extends StatelessWidget {
  const _DetailBottomTabs({
    required this.currentIndex,
    required this.onSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  static const _tabs = [
    AppZh.dexTabIntro,
    '基本',
    AppZh.dexTabObtain,
    AppZh.dexTabMoves,
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: TitoColors.deepBlue,
            borderRadius: BorderRadius.circular(TitoRadii.md),
            border: Border.all(color: TitoColors.ink, width: 2),
          ),
          child: Row(
            children: List.generate(_tabs.length, (index) {
              final selected = index == currentIndex;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: HandheldFocusDecorator(
                    onActivate: () => onSelected(index),
                    borderRadius: BorderRadius.circular(TitoRadii.sm),
                    child: Material(
                      color: selected
                          ? TitoColors.softYellow
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(TitoRadii.sm),
                      child: InkWell(
                        onTap: () => onSelected(index),
                        canRequestFocus: false,
                        borderRadius: BorderRadius.circular(TitoRadii.sm),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            _tabs[index],
                            textAlign: TextAlign.center,
                            style: SecondaryTypography.onCard.small12.copyWith(
                              fontWeight: FontWeight.w800,
                              color: selected
                                  ? TitoColors.deepBlue
                                  : TitoColors.card,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
