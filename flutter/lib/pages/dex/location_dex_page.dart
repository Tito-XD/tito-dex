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
import '../../models/journey.dart';
import '../../theme/secondary_typography.dart';
import '../../theme/tito_colors.dart';
import '../../widgets/secondary_page_scaffold.dart';
import '../../widgets/sticker_card.dart';
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
      subtitle: gameEditionRepository.edition.labelZh,
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
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: AppZh.locationDexSearchHint,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<_LocationPageData>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData &&
                snapshot.connectionState != ConnectionState.done) {
              return const TitoLoadingPanel(
                message: AppZh.referenceLoading,
                compact: true,
              );
            }
            if (snapshot.hasError || snapshot.data == null) {
              return StickerCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(AppZh.locationDexLoadFailed),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => setState(() => _future = _load()),
                      child: const Text(AppZh.dexRetry),
                    ),
                  ],
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
              return const StickerCard(child: Text(AppZh.locationDexEmpty));
            }
            return Column(
              children: [
                for (final area in areas) ...[
                  _LocationAreaCard(
                    area: area,
                    summaries: data.summaries,
                    caughtIds: progress.caughtIds,
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LocationAreaCard extends StatelessWidget {
  const _LocationAreaCard({
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
    return StickerCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        title: Text(area.labelZh, style: SecondaryTypography.onCard.h15),
        subtitle: Text(
          AppZh.locationDexCompletion(caught, area.speciesCount),
          style: SecondaryTypography.onCard.small12.copyWith(
            color: TitoColors.mutedInk,
          ),
        ),
        children: [
          for (final entry in area.entries)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                caughtIds.contains(entry.speciesId)
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: caughtIds.contains(entry.speciesId)
                    ? TitoColors.deepBlue
                    : TitoColors.mutedInk,
              ),
              title: Text(
                summaries[entry.speciesId]?.nameZh ?? '#${entry.speciesId}',
                style: SecondaryTypography.onCard.body14,
              ),
              subtitle: Text(
                _entryDetails(entry),
                style: SecondaryTypography.onCard.small12.copyWith(
                  color: TitoColors.mutedInk,
                ),
              ),
              onTap: () {
                final route = Uri(
                  path: '/dex/${entry.speciesId}',
                  queryParameters: entry.formKey == null
                      ? null
                      : {'form': entry.formKey!},
                ).toString();
                context.push(route);
              },
            ),
        ],
      ),
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
        ? '权重 ${entry.rateValue ?? entry.maxChance}'
        : entry.maxChance > 0
        ? '${entry.maxChance}%'
        : '';
    final tags = [
      if (entry.formAmbiguous) '形态未区分',
      if (entry.teraType != null) '太晶：${typeNameZh(entry.teraType!)}',
      if (entry.isAlpha) '头目',
      if (entry.isTitan) '霸主',
      if (entry.isTotem) '图腾',
      if (entry.isRaid) '团体战',
      if (entry.isFixedEncounter) '固定出现',
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

class _LocationPageData {
  const _LocationPageData({required this.areas, required this.summaries});

  final List<LocationArea> areas;
  final Map<int, PokemonSummary> summaries;
}
