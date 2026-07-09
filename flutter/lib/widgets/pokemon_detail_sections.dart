import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/dex/dex_game_scope.dart';
import '../features/dex/dex_models.dart';
import '../features/dex/dex_offline_service.dart';
import '../features/dex/type_chart.dart';
import '../l10n/app_zh.dart';
import '../theme/device_layout.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_typography.dart';
import '../theme/tito_colors.dart';
import 'dex_sprite_image.dart';
import 'pokemon_card.dart';
import 'sticker_card.dart';
import 'tito_progress_bar.dart';

class PokemonDetailHeader extends StatelessWidget {
  const PokemonDetailHeader({
    super.key,
    required this.detail,
    this.compact = false,
    this.showSettingsAction = true,
  });

  final PokemonDetail detail;
  final bool compact;
  final bool showSettingsAction;

  @override
  Widget build(BuildContext context) {
    final summary = detail.summary;
    final compactLayout = compact || DeviceLayout.isCompact(context);
    final square = DeviceLayout.useSquareDashboard(context);
    final dexLabel = [
      if (detail.johtoDexLabel != null) detail.johtoDexLabel,
      detail.nationalDexLabel,
    ].join(' · ');

    if (compact) {
      return StickerCard(
        variant: StickerVariant.deep,
        padding: EdgeInsets.symmetric(
          horizontal: square ? 10 : 12,
          vertical: square ? 8 : 10,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dexLabel,
                    style: SecondaryTypography.onGradient.small12.copyWith(
                      color: TitoColors.skyBlue,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summary.nameZh,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SecondaryTypography.onGradient.h15.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (detail.genusZh.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail.genusZh,
                      style: SecondaryTypography.onGradient.small12,
                    ),
                  ],
                  const SizedBox(height: 6),
                  TypeChipRow(
                    types: summary.types.map(typeNameZh).toList(),
                    typeKeys: summary.types,
                    tone: TypeChipTone.neutral,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            DexSpriteImage(
              source: summary.displaySpritePath,
              width: square ? 56 : 64,
              height: square ? 56 : 64,
            ),
          ],
        ),
      );
    }

    return StickerCard(
      variant: StickerVariant.deep,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dexLabel, style: context.tito.onDeepSubtitle),
                Text(
                  summary.nameZh,
                  style: context.tito.onDeepHeading.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (detail.genusZh.isNotEmpty)
                  Text(detail.genusZh, style: context.tito.onDeepSubtitle),
                const SizedBox(height: 6),
                TypeChipRow(
                  types: summary.types.map(typeNameZh).toList(),
                  typeKeys: summary.types,
                ),
              ],
            ),
          ),
          Column(
            children: [
              if (compactLayout && showSettingsAction)
                IconButton(
                  onPressed: () => context.push('/settings'),
                  icon: const Icon(
                    Icons.settings_rounded,
                    color: TitoColors.card,
                  ),
                  tooltip: AppZh.navSettings,
                ),
              DexSpriteImage(
                source: summary.displaySpritePath,
                width: square ? 72 : (compactLayout ? 84 : 108),
                height: square ? 72 : (compactLayout ? 84 : 108),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FlavorTextCarousel extends StatefulWidget {
  const FlavorTextCarousel({super.key, required this.entries});

  final List<FlavorTextEntry> entries;

  @override
  State<FlavorTextCarousel> createState() => _FlavorTextCarouselState();
}

class _FlavorTextCarouselState extends State<FlavorTextCarousel> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return StickerCard(
        child: Text(AppZh.dexFlavorEmpty, style: context.tito.cardBodyStrong),
      );
    }

    return StickerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppZh.dexFlavorTitle,
            style: SecondaryTypography.onCard.h15,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 132,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.entries.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, index) {
                final entry = widget.entries[index];
                final isChinese = _looksChinese(entry.text);
                final note = entry.version == 'zh-reference'
                    ? AppZh.dexFlavorZhFallbackNote
                    : (!isChinese ? AppZh.dexFlavorEnglishNote : null);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      flavorVersionLabelZh(entry.version),
                      style: SecondaryTypography.onCard.meta14.copyWith(
                        color: TitoColors.coral,
                      ),
                    ),
                    if (note != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        note,
                        style: SecondaryTypography.onCard.small12.copyWith(
                          color: TitoColors.mutedInk,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        entry.text,
                        style: SecondaryTypography.onCard.body14,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.entries.length,
              (index) => Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index == _index
                      ? TitoColors.coral
                      : TitoColors.mutedInk.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _looksChinese(String text) {
    return RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
  }
}

class BaseStatsCard extends StatelessWidget {
  const BaseStatsCard({super.key, required this.stats});

  final PokemonBaseStats stats;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppZh.dexBaseStats,
            style: SecondaryTypography.onCard.h15,
          ),
          const SizedBox(height: 12),
          ...stats.entries.map((entry) {
            final label = statLabelsZh[entry.key] ?? entry.key;
            final ratio = (entry.value / maxBaseStatValue).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 42,
                    child: Text(
                      label,
                      style: SecondaryTypography.onCard.team12,
                    ),
                  ),
                  Expanded(
                    child: TitoProgressBar(
                      value: ratio,
                      height: 10,
                      fillColor: _statBarColor(entry.value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${entry.value}',
                      textAlign: TextAlign.end,
                      style: SecondaryTypography.onCard.meta14.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppZh.dexBaseStatTotal,
                style: SecondaryTypography.onCard.team12,
              ),
              Text(
                '${stats.total}',
                style: SecondaryTypography.onCard.h15,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statBarColor(int value) {
    if (value >= 100) {
      return TitoColors.coral;
    }
    if (value >= 70) {
      return TitoColors.softYellow;
    }
    if (value >= 50) {
      return TitoColors.hpGreen;
    }
    return TitoColors.skyBlue;
  }
}

class TypeEffectivenessGrid extends StatelessWidget {
  const TypeEffectivenessGrid({super.key, required this.multipliers});

  final Map<String, double> multipliers;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppZh.dexTypeGridTitle,
            style: SecondaryTypography.onCard.h15,
          ),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, String?>>(
            future: _iconPaths(),
            builder: (context, snapshot) {
              final icons = snapshot.data ?? const {};
              return GridView.count(
                crossAxisCount: 6,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 6,
                childAspectRatio: 0.68,
                children: typeGridOrder.map((type) {
                  final multiplier = multipliers[type] ?? 1;
                  final label = formatTypeMultiplier(multiplier);
                  return Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: typeTileColor(type),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: TitoColors.ink, width: 2),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: DexSpriteImage(
                          source: icons[type],
                          width: 28,
                          height: 28,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        typeNameZh(type),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SecondaryTypography.onCard.small12.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        label,
                        style: SecondaryTypography.onCard.small12.copyWith(
                          fontWeight: FontWeight.w900,
                          color: _multiplierColor(multiplier),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<Map<String, String?>> _iconPaths() async {
    final paths = <String, String?>{};
    for (final type in typeGridOrder) {
      paths[type] = await dexOfflineService.typeIconPath(type);
    }
    return paths;
  }

  Color _multiplierColor(double multiplier) {
    if (multiplier >= 2) {
      return const Color(0xFFD94848);
    }
    if (multiplier <= 0) {
      return TitoColors.mutedInk;
    }
    if (multiplier <= 0.5) {
      return const Color(0xFF4B7FD1);
    }
    return TitoColors.ink;
  }
}

class ObtainLocationsCard extends StatelessWidget {
  const ObtainLocationsCard({super.key, required this.locations});

  final List<ObtainLocationEntry> locations;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppZh.dexObtainHgss,
            style: SecondaryTypography.onCard.h15,
          ),
          const SizedBox(height: 10),
          ...locations.map(
            (entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.areaLabelZh,
                      style: SecondaryTypography.onCard.body14.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (entry.minLevel != null)
                    Text(
                      'Lv.${entry.minLevel}+',
                      style: SecondaryTypography.onCard.small12.copyWith(
                        color: TitoColors.mutedInk,
                      ),
                    ),
                  if (entry.maxChance > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${entry.maxChance}%',
                      style: SecondaryTypography.onCard.small12.copyWith(
                        fontWeight: FontWeight.w800,
                        color: TitoColors.coral,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MoveCategoryPanel extends StatelessWidget {
  const MoveCategoryPanel({
    super.key,
    required this.title,
    required this.moves,
    this.showLevel = false,
  });

  final String title;
  final List<PokemonMove> moves;
  final bool showLevel;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: SecondaryTypography.onCard.h15,
                ),
              ),
              Text(
                '${moves.length}',
                style: SecondaryTypography.onCard.meta14.copyWith(
                  color: TitoColors.coral,
                ),
              ),
            ],
          ),
          if (moves.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                AppZh.dexNone,
                style: SecondaryTypography.onCard.small12.copyWith(
                  color: TitoColors.mutedInk,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 420 ? 3 : 2;
                  final gap = 8.0;
                  final tileWidth =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: moves
                        .map(
                          (entry) => SizedBox(
                            width: tileWidth,
                            child: _MoveTile(
                              entry: entry,
                              showLevel: showLevel,
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _MoveTile extends StatelessWidget {
  const _MoveTile({required this.entry, required this.showLevel});

  final PokemonMove entry;
  final bool showLevel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: typeTileColor(entry.move.type).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(TitoRadii.sm),
        border: Border.all(color: TitoColors.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLevel && entry.level != null)
            Text(
              'Lv.${entry.level}',
              style: SecondaryTypography.onCard.small12.copyWith(
                color: TitoColors.mutedInk,
                fontWeight: FontWeight.w800,
              ),
            ),
          Text(
            entry.move.nameZh,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SecondaryTypography.onCard.small12.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          FutureBuilder<String?>(
            future: dexOfflineService.typeIconPath(entry.move.type),
            builder: (context, snapshot) {
              return Row(
                children: [
                  if (snapshot.data != null)
                    DexSpriteImage(
                      source: snapshot.data,
                      width: 14,
                      height: 14,
                    ),
                  if (snapshot.data != null) const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      typeNameZh(entry.move.type),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SecondaryTypography.onCard.small12.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class IntroMetaCard extends StatelessWidget {
  const IntroMetaCard({super.key, required this.detail});

  final PokemonDetail detail;

  @override
  Widget build(BuildContext context) {
    final heightM = detail.heightDm / 10;
    final weightKg = detail.weightHg / 10;
    final female = detail.genderFemalePercent;

    return StickerCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MetaTile(
                  label: AppZh.dexHeight,
                  value: '${heightM.toStringAsFixed(1)} m',
                ),
              ),
              Expanded(
                child: _MetaTile(
                  label: AppZh.dexWeight,
                  value: '${weightKg.toStringAsFixed(1)} kg',
                ),
              ),
            ],
          ),
          if (female != null) ...[
            const Divider(height: 20),
            Row(
              children: [
                Text(
                  AppZh.dexGenderRatio,
                  style: context.tito.cardLabel.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  AppZh.dexGenderFemale(female),
                  style: context.tito.cardValue,
                ),
              ],
            ),
          ],
          if (detail.eggGroups.isNotEmpty) ...[
            const Divider(height: 20),
            Row(
              children: [
                Text(
                  AppZh.dexEggGroups,
                  style: context.tito.cardLabel.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  detail.eggGroups.join(' / '),
                  style: context.tito.cardValue,
                ),
              ],
            ),
          ],
          if (detail.hatchCounter != null) ...[
            const Divider(height: 20),
            Row(
              children: [
                Text(
                  AppZh.dexHatchSteps,
                  style: context.tito.cardLabel.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  '${detail.hatchCounter} (${detail.hatchSteps})',
                  style: context.tito.cardValue,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaTile extends StatelessWidget {
  const _MetaTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.tito.cardLabel.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(value, style: context.tito.cardValueLarge),
      ],
    );
  }
}
