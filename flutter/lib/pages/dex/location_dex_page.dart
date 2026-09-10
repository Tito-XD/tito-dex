import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/dex/dex_encounter_labels.dart';
import '../../features/dex/dex_models.dart';
import '../../features/dex/dex_progress.dart';
import '../../features/dex/dex_repository.dart';
import '../../features/dex/location_index.dart';
import '../../features/dex/type_chart.dart';
import '../../features/game/game_edition_repository.dart';
import '../../l10n/app_zh.dart';
import '../../l10n/localized_names.dart';
import '../../models/journey.dart';
import '../../theme/app_visual_style.dart';
import '../../theme/secondary_typography.dart';
import '../../theme/tito_colors.dart';
import '../../theme/trainer_journal.dart';
import '../../widgets/dex_sprite_image.dart';
import '../../widgets/secondary_page_scaffold.dart';
import '../../widgets/sticker_card.dart';
import '../../widgets/sticker_pressable.dart';
import '../../widgets/tito_loading_panel.dart';

class LocationDexPage extends StatefulWidget {
  const LocationDexPage({super.key, required this.journey});

  final CurrentJourney journey;

  @override
  State<LocationDexPage> createState() => _LocationDexPageState();
}

class _LocationDexPageState extends State<LocationDexPage> {
  late Future<_LocationPageData> _future;
  final _queryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = _load();
    _queryController.addListener(_refresh);
  }

  @override
  void dispose() {
    _queryController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  Future<_LocationPageData> _load() async {
    final results = await Future.wait([
      locationIndexRepository.load(),
      dexRepository.getAllSummaries(),
    ]);
    final index = results[0] as LocationIndex;
    final summaries = results[1] as List<PokemonSummary>;
    return _LocationPageData(
      areas: index.areasForEdition(gameEditionRepository.edition),
      summaries: {for (final summary in summaries) summary.id: summary},
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = DexProgress.fromJourney(widget.journey);
    return SecondaryPageScaffold(
      title: AppZh.locationDexTitle,
      subtitle: gameEditionRepository.edition.label,
      slivers: [
        FutureBuilder<_LocationPageData>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData &&
                snapshot.connectionState != ConnectionState.done) {
              return SliverToBoxAdapter(
                child: TitoLoadingPanel(
                  message: AppZh.referenceLoading,
                  compact: true,
                ),
              );
            }
            if (snapshot.hasError || snapshot.data == null) {
              return SliverToBoxAdapter(
                child: StickerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppZh.locationDexLoadFailed),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () => setState(() => _future = _load()),
                        child: Text(AppZh.dexRetry),
                      ),
                    ],
                  ),
                ),
              );
            }
            final data = snapshot.data!;
            final query = _queryController.text.trim().toLowerCase();
            final areas = data.areas
                .where((area) {
                  if (query.isEmpty ||
                      area.labelZh.toLowerCase().contains(query)) {
                    return true;
                  }
                  return area.entries.any((entry) {
                    final summary = data.summaries[entry.speciesId];
                    return summary?.nameZh.contains(query) == true ||
                        summary?.nameEn.toLowerCase().contains(query) == true;
                  });
                })
                .toList(growable: false);
            if (areas.isEmpty) {
              return SliverToBoxAdapter(
                child: StickerCard(child: Text(AppZh.locationDexEmpty)),
              );
            }
            return SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisExtent: 66,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: areas.length,
              itemBuilder: (context, index) => _LocationAreaChip(
                area: areas[index],
                summaries: data.summaries,
                caughtIds: progress.caughtIds,
              ),
            );
          },
        ),
      ],
      children: [
        StickerCard(
          variant: StickerVariant.softYellow,
          child: Text(
            AppZh.locationDexHint,
            style: SecondaryTypography.onCard.small12.copyWith(
              color: TitoColors.mutedInk,
            ),
          ),
        ),
        const SizedBox(height: 12),
        StickerCard(
          child: TextField(
            controller: _queryController,
            // Field shape and stroke come from the theme's input decoration.
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: AppZh.locationDexSearchHint,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _LocationAreaChip extends StatelessWidget {
  const _LocationAreaChip({
    required this.area,
    required this.summaries,
    required this.caughtIds,
  });

  final LocationArea area;
  final Map<int, PokemonSummary> summaries;
  final Set<int> caughtIds;

  @override
  Widget build(BuildContext context) {
    final caught = area.caughtCount(caughtIds);
    final scheme = Theme.of(context).colorScheme;
    // Two-line area tile (name + completion + chevron) — too tall for a
    // Material chip, so it is drawn by hand with the element tokens: ink
    // stroke in Trainer's Journal, plastic hairline, no stroke in Flat.
    final Border? stroke = appVisualStyle.usesFlatUi
        ? null
        : appVisualStyle.usesSolidPlastic
        ? Border.all(
            color: Colors.white.withValues(alpha: 0.8),
            width: TitoBorders.glass,
          )
        : TrainerJournal.allElement();
    return Material(
      color: appVisualStyle.usesFlatUi
          ? scheme.surfaceContainerLow
          : TitoColors.card,
      borderRadius: BorderRadius.circular(TitoRadii.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(TitoRadii.sm),
        onTap: () => _showAreaSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TitoRadii.sm),
            border: stroke,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      area.labelZh,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SecondaryTypography.onCard.body14.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppZh.locationDexCompletion(caught, area.speciesCount),
                      style: SecondaryTypography.onCard.small12.copyWith(
                        color: TitoColors.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                caught == area.speciesCount
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                size: 20,
                color: caught == area.speciesCount
                    ? TitoColors.deepBlue
                    : TitoColors.mutedInk,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAreaSheet(BuildContext pageContext) {
    return showModalBottomSheet<void>(
      context: pageContext,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        var missingOnly = area.entries.any(
          (entry) => !caughtIds.contains(entry.speciesId),
        );
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final entries = area.entries
                .where(
                  (entry) =>
                      !missingOnly || !caughtIds.contains(entry.speciesId),
                )
                .toList(growable: false);
            // Sheet surface, handle and shape come from the theme; the
            // outer `useSafeArea` already keeps it clear of system bars.
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.94,
              builder: (context, controller) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                area.labelZh,
                                style: SecondaryTypography.onCard.h15,
                              ),
                              Text(
                                AppZh.locationDexCompletion(
                                  area.caughtCount(caughtIds),
                                  area.speciesCount,
                                ),
                                style: SecondaryTypography.onCard.small12,
                              ),
                            ],
                          ),
                        ),
                        FilterChip(
                          selected: missingOnly,
                          label: Text(AppZh.locationDexUncaughtOnly),
                          onSelected: (value) =>
                              setSheetState(() => missingOnly = value),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: entries.isEmpty
                        ? Center(
                            child: Text(
                              AppZh.locationDexAllCaught,
                              style: SecondaryTypography.onCard.body14,
                            ),
                          )
                        : ListView.separated(
                            controller: controller,
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                            itemCount: entries.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final entry = entries[index];
                              final caught = caughtIds.contains(
                                entry.speciesId,
                              );
                              final summary = summaries[entry.speciesId];
                              return _EncounterSheetRow(
                                name:
                                    summary?.displayName ??
                                    '#${entry.speciesId}',
                                spritePath: summary?.displaySpritePath,
                                details: _entryDetails(entry),
                                caught: caught,
                                onTap: () {
                                  Navigator.pop(context);
                                  final route = Uri(
                                    path: '/dex/${entry.speciesId}',
                                    queryParameters: entry.formKey == null
                                        ? null
                                        : {'form': entry.formKey!},
                                  ).toString();
                                  pageContext.push(route);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _entryDetails(LocationEncounterEntry entry) {
    final methods = entry.methods
        .map(encounterMethodLabelZh)
        .toSet()
        .join(' / ');
    final level = entry.minLevel == null
        ? ''
        : entry.minLevel == entry.maxLevel || entry.maxLevel == null
        ? 'Lv.${entry.minLevel}'
        : 'Lv.${entry.minLevel}–${entry.maxLevel}';
    final conditions = entry.conditions
        .map(encounterConditionLabelZh)
        .toSet()
        .join(' · ');
    final rate = entry.rateKind == 'weight'
        ? AppZh.encounterWeight(entry.rateValue ?? entry.maxChance)
        : entry.maxChance > 0
        ? '${entry.maxChance}%'
        : '';
    final tags = [
      if (entry.formAmbiguous) AppZh.encounterFormAmbiguous,
      if (entry.teraType != null)
        AppZh.encounterTera(typeNameZh(entry.teraType!)),
      if (entry.isAlpha) AppZh.encounterAlpha,
      if (entry.isTitan) AppZh.encounterTitan,
      if (entry.isTotem) AppZh.encounterTotem,
      if (entry.isRaid) AppZh.encounterRaid,
      if (entry.isFixedEncounter) AppZh.encounterFixed,
    ].join(' · ');
    return [
      methods,
      level,
      rate,
      tags,
      conditions,
    ].where((value) => value.isNotEmpty).join(' · ');
  }
}

class _EncounterSheetRow extends StatelessWidget {
  const _EncounterSheetRow({
    required this.name,
    required this.spritePath,
    required this.details,
    required this.caught,
    required this.onTap,
  });

  final String name;
  final String? spritePath;
  final String details;
  final bool caught;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(TitoRadii.md);
    return StickerPressable(
      borderRadius: radius,
      ownShadow: false,
      child: StickerCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Row(
            children: [
              DexSpriteImage(source: spritePath, height: 40, width: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SecondaryTypography.onCard.body14.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        details,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SecondaryTypography.onCard.small12.copyWith(
                          color: TitoColors.mutedInk,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                caught
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                size: 20,
                color: caught ? TitoColors.deepBlue : TitoColors.mutedInk,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationPageData {
  const _LocationPageData({required this.areas, required this.summaries});

  final List<LocationArea> areas;
  final Map<int, PokemonSummary> summaries;
}
