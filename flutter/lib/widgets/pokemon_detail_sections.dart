import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/dex/dex_game_scope.dart';
import '../features/dex/dex_models.dart';
import '../features/dex/dex_offline_service.dart';
import '../features/dex/type_chart.dart';
import '../l10n/app_zh.dart';
import '../theme/device_layout.dart';
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
          children: [
            Expanded(
              child: Text(
                '$dexLabel · ${summary.nameZh}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.tito.onDeepHeading.copyWith(
                  fontSize: square ? 13 : 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            DexSpriteImage(
              source: summary.displaySpritePath,
              width: square ? 50 : 58,
              height: square ? 50 : 58,
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
          Text(AppZh.dexFlavorTitle, style: context.tito.cardSectionTitle),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.entries.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, index) {
                final entry = widget.entries[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      flavorVersionLabelZh(entry.version),
                      style: context.tito.accentCoral,
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(entry.text, style: context.tito.cardBody),
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
}

class BaseStatsCard extends StatelessWidget {
  const BaseStatsCard({super.key, required this.stats});

  final PokemonBaseStats stats;

  @override
  Widget build(BuildContext context) {
    final maxStat = stats.entries
        .map((entry) => entry.value)
        .fold<int>(1, (a, b) => a > b ? a : b);

    return StickerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppZh.dexBaseStats, style: context.tito.cardSectionTitle),
          const SizedBox(height: 12),
          ...stats.entries.map((entry) {
            final label = statLabelsZh[entry.key] ?? entry.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 42,
                    child: Text(
                      label,
                      style: context.tito.cardLabel.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TitoProgressBar(
                      value: entry.value / maxStat,
                      height: 10,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${entry.value}',
                      textAlign: TextAlign.end,
                      style: context.tito.cardValue.copyWith(
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
                style: context.tito.cardLabel.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text('${stats.total}', style: context.tito.cardValueLarge),
            ],
          ),
        ],
      ),
    );
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
          Text(AppZh.dexTypeGridTitle, style: context.tito.cardSectionTitle),
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
                crossAxisSpacing: 8,
                childAspectRatio: 0.72,
                children: typeGridOrder.map((type) {
                  final multiplier = multipliers[type] ?? 1;
                  final label = formatTypeMultiplier(multiplier);
                  return Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _typeColor(type),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: TitoColors.ink, width: 2),
                        ),
                        child: Center(
                          child: DexSpriteImage(
                            source: icons[type],
                            width: 20,
                            height: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: context.tito.captionStrong.copyWith(
                          fontSize: 11,
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

  Color _typeColor(String type) => switch (type) {
    'normal' => const Color(0xFFD8D3C3),
    'fire' => const Color(0xFFF5A26F),
    'water' => const Color(0xFF7CB7FF),
    'electric' => const Color(0xFFF7D977),
    'grass' => const Color(0xFF8ED081),
    'ice' => const Color(0xFF9BE7E6),
    'fighting' => const Color(0xFFE07B62),
    'poison' => const Color(0xFFC68FD9),
    'ground' => const Color(0xFFE6C07A),
    'flying' => const Color(0xFFB8C8F0),
    'psychic' => const Color(0xFFFF8CB3),
    'bug' => const Color(0xFFB5D06A),
    'rock' => const Color(0xFFC9B48A),
    'ghost' => const Color(0xFF9F8AC8),
    'dragon' => const Color(0xFF7B8CFF),
    'dark' => const Color(0xFF9B8B7D),
    'steel' => const Color(0xFFB0C0CF),
    'fairy' => const Color(0xFFFFA9D6),
    _ => TitoColors.skyBlue,
  };

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
                child: Text(title, style: context.tito.cardSectionTitle),
              ),
              Text('${moves.length}', style: context.tito.accentCoral),
            ],
          ),
          if (moves.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(AppZh.dexNone, style: context.tito.cardMuted),
            )
          else
            ...moves.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    if (showLevel && entry.level != null)
                      SizedBox(
                        width: 42,
                        child: Text(
                          'Lv.${entry.level}',
                          style: context.tito.captionStrong,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        entry.move.nameZh,
                        style: context.tito.cardBodyStrong,
                      ),
                    ),
                    Text(
                      typeNameZh(entry.move.type),
                      style: context.tito.captionStrong,
                    ),
                  ],
                ),
              ),
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
