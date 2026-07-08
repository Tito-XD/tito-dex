import 'package:flutter/material.dart';

import '../features/dex/dex_game_scope.dart';
import '../features/dex/dex_models.dart';
import '../features/dex/dex_offline_service.dart';
import '../features/dex/type_chart.dart';
import '../l10n/app_zh.dart';
import '../theme/tito_colors.dart';
import 'dex_sprite_image.dart';
import 'pokemon_card.dart';
import 'sticker_card.dart';

class PokemonDetailHeader extends StatelessWidget {
  const PokemonDetailHeader({super.key, required this.detail});

  final PokemonDetail detail;

  @override
  Widget build(BuildContext context) {
    final summary = detail.summary;
    return StickerCard(
      variant: StickerVariant.deep,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    if (detail.johtoDexLabel != null) detail.johtoDexLabel,
                    detail.nationalDexLabel,
                  ].join(' · '),
                  style: const TextStyle(
                    color: TitoColors.skyBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  summary.nameZh,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: TitoColors.card,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                if (detail.genusZh.isNotEmpty)
                  Text(
                    detail.genusZh,
                    style: const TextStyle(
                      color: TitoColors.skyBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 8),
                TypeChipRow(
                  types: summary.types.map(typeNameZh).toList(),
                  typeKeys: summary.types,
                ),
              ],
            ),
          ),
          DexSpriteImage(
            source: summary.displaySpritePath,
            width: 108,
            height: 108,
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
        child: Text(
          AppZh.dexFlavorEmpty,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }

    return StickerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppZh.dexFlavorTitle,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: TitoColors.coral,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        entry.text,
                        style: const TextStyle(
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
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
          Text(
            AppZh.dexBaseStats,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: TitoColors.mutedInk,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: entry.value / maxStat,
                        minHeight: 10,
                        backgroundColor: TitoColors.skyBlue,
                        color: TitoColors.coral,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${entry.value}',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w900),
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
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: TitoColors.mutedInk,
                ),
              ),
              Text(
                '${stats.total}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TypeEffectivenessGrid extends StatelessWidget {
  const TypeEffectivenessGrid({
    super.key,
    required this.multipliers,
  });

  final Map<String, double> multipliers;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppZh.dexTypeGridTitle,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
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
                        style: TextStyle(
                          fontSize: 11,
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
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '${moves.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
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
                style: const TextStyle(
                  color: TitoColors.mutedInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: TitoColors.mutedInk,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        entry.move.nameZh,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      typeNameZh(entry.move.type),
                      style: const TextStyle(
                        fontSize: 12,
                        color: TitoColors.mutedInk,
                        fontWeight: FontWeight.w700,
                      ),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: TitoColors.mutedInk,
                  ),
                ),
                const Spacer(),
                Text(
                  AppZh.dexGenderFemale(female),
                  style: const TextStyle(fontWeight: FontWeight.w900),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: TitoColors.mutedInk,
                  ),
                ),
                const Spacer(),
                Text(
                  detail.eggGroups.join(' / '),
                  style: const TextStyle(fontWeight: FontWeight.w900),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: TitoColors.mutedInk,
                  ),
                ),
                const Spacer(),
                Text(
                  '${detail.hatchCounter} (${detail.hatchSteps})',
                  style: const TextStyle(fontWeight: FontWeight.w900),
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
          style: const TextStyle(
            color: TitoColors.mutedInk,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ],
    );
  }
}
