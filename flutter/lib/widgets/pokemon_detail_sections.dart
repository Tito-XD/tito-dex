import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/dex/dex_game_scope.dart';
import '../features/dex/dex_models.dart';
import '../features/companion/battle_tools_service.dart';
import '../features/dex/ability_type_modifiers.dart';
import '../features/dex/battle_effectiveness.dart';
import '../features/dex/generation_type_chart.dart';
import '../features/dex/type_chart.dart';
import '../widgets/companion_tool_fields.dart';
import '../features/game/game_edition.dart';
import '../l10n/app_zh.dart';
import '../theme/device_layout.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_typography.dart';
import '../theme/tito_colors.dart';
import 'dex_sprite_image.dart';
import 'pokemon_artwork_viewer.dart';
import 'pokemon_card.dart';
import 'sticker_card.dart';
import 'tito_progress_bar.dart';
import 'type_badge.dart';

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
            GestureDetector(
              onTap: () => showPokemonArtworkViewer(
                context,
                summary: summary,
              ),
              child: DexSpriteImage(
                source: summary.displaySpritePath,
                width: square ? 56 : 64,
                height: square ? 56 : 64,
              ),
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
              GestureDetector(
                onTap: () => showPokemonArtworkViewer(
                  context,
                  summary: summary,
                ),
                child: DexSpriteImage(
                  source: summary.displaySpritePath,
                  width: square ? 72 : (compactLayout ? 84 : 108),
                  height: square ? 72 : (compactLayout ? 84 : 108),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FlavorTextCarousel extends StatefulWidget {
  const FlavorTextCarousel({
    super.key,
    required this.entries,
    this.initialPage = 0,
    this.gameEdition,
    this.onPickEdition,
  });

  final List<FlavorTextEntry> entries;
  final int initialPage;
  final GameEdition? gameEdition;
  final VoidCallback? onPickEdition;

  @override
  State<FlavorTextCarousel> createState() => _FlavorTextCarouselState();
}

class _FlavorTextCarouselState extends State<FlavorTextCarousel> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    final page = widget.initialPage.clamp(0, widget.entries.length - 1);
    _index = page;
    _controller = PageController(initialPage: page);
  }

  @override
  void didUpdateWidget(covariant FlavorTextCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPage != widget.initialPage &&
        widget.entries.isNotEmpty) {
      final page = widget.initialPage.clamp(0, widget.entries.length - 1);
      if (_index != page) {
        _index = page;
        _controller.jumpToPage(page);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      final edition = widget.gameEdition;
      if (edition != null && !edition.hasPokeApiData) {
        return StickerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppZh.dexFlavorNoEdition,
                style: SecondaryTypography.onCard.body14,
              ),
              if (widget.onPickEdition != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: widget.onPickEdition,
                  child: const Text(AppZh.dexFlavorPickEdition),
                ),
              ],
            ],
          ),
        );
      }
      return StickerCard(
        child: Text(AppZh.dexFlavorEmpty, style: SecondaryTypography.onCard.body14),
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
                    Row(
                      children: [
                        if (entry.iconUrl != null) ...[
                          Image.network(
                            entry.iconUrl!,
                            width: 20,
                            height: 20,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox(width: 20, height: 20),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            entry.displayLabel,
                            style: SecondaryTypography.onCard.meta14.copyWith(
                              color: TitoColors.coral,
                            ),
                          ),
                        ),
                      ],
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
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: _index > 0
                    ? () => _controller.previousPage(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        )
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
                color: TitoColors.coral,
              ),
              Text(
                '${_index + 1}/${widget.entries.length}',
                style: SecondaryTypography.onCard.meta14.copyWith(
                  fontWeight: FontWeight.w800,
                  color: TitoColors.coral,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: _index < widget.entries.length - 1
                    ? () => _controller.nextPage(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        )
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
                color: TitoColors.coral,
              ),
            ],
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

/// Hexagonal radar chart for six base stats, normalized to [maxBaseStatValue].
class BaseStatsRadarChart extends StatelessWidget {
  const BaseStatsRadarChart({super.key, required this.stats});

  final PokemonBaseStats stats;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          const titleBlock = 44.0;
          final boundedHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight - titleBlock
              : constraints.maxWidth;
          final chartSize = math.min(constraints.maxWidth, boundedHeight);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppZh.dexBaseStatsRadar,
                style: SecondaryTypography.onCard.h15,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: chartSize,
                height: chartSize,
                child: CustomPaint(
                  painter: _BaseStatsRadarPainter(stats: stats),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: LayoutBuilder(
                      builder: (context, inner) {
                        final center = Offset(
                          inner.maxWidth / 2,
                          inner.maxHeight / 2,
                        );
                        final radius =
                            (inner.maxWidth < inner.maxHeight
                                    ? inner.maxWidth
                                    : inner.maxHeight) /
                                2 -
                            18;
                        final labels = stats.entries.toList();
                        return Stack(
                          children: [
                            for (var i = 0; i < labels.length; i++)
                              _RadarStatLabel(
                                label:
                                    statLabelsZh[labels[i].key] ?? labels[i].key,
                                value: labels[i].value,
                                center: center,
                                radius: radius + 16,
                                index: i,
                                total: labels.length,
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RadarStatLabel extends StatelessWidget {
  const _RadarStatLabel({
    required this.label,
    required this.value,
    required this.center,
    required this.radius,
    required this.index,
    required this.total,
  });

  final String label;
  final int value;
  final Offset center;
  final double radius;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final angle = -math.pi / 2 + (2 * math.pi * index / total);
    final x = center.dx + radius * math.cos(angle);
    final y = center.dy + radius * math.sin(angle);
    return Positioned(
      left: x - 20,
      top: y - 10,
      width: 40,
      child: Text(
        '$label\n$value',
        textAlign: TextAlign.center,
        style: SecondaryTypography.onCard.small12.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    );
  }
}

class _BaseStatsRadarPainter extends CustomPainter {
  _BaseStatsRadarPainter({required this.stats});

  final PokemonBaseStats stats;

  static const _gridLevels = [0.25, 0.5, 0.75, 1.0];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 24;
    final values = stats.entries.map((e) => e.value).toList();
    final count = values.length;
    if (count == 0) {
      return;
    }

    final gridPaint = Paint()
      ..color = TitoColors.mutedInk.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final axisPaint = Paint()
      ..color = TitoColors.mutedInk.withValues(alpha: 0.35)
      ..strokeWidth = 1;

    for (final level in _gridLevels) {
      final path = Path();
      for (var i = 0; i < count; i++) {
        final angle = -math.pi / 2 + (2 * math.pi * i / count);
        final point = Offset(
          center.dx + radius * level * math.cos(angle),
          center.dy + radius * level * math.sin(angle),
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / count);
      canvas.drawLine(
        center,
        Offset(
          center.dx + radius * math.cos(angle),
          center.dy + radius * math.sin(angle),
        ),
        axisPaint,
      );
    }

    final fillPath = Path();
    for (var i = 0; i < count; i++) {
      final ratio = (values[i] / maxBaseStatValue).clamp(0.0, 1.0);
      final angle = -math.pi / 2 + (2 * math.pi * i / count);
      final point = Offset(
        center.dx + radius * ratio * math.cos(angle),
        center.dy + radius * ratio * math.sin(angle),
      );
      if (i == 0) {
        fillPath.moveTo(point.dx, point.dy);
      } else {
        fillPath.lineTo(point.dx, point.dy);
      }
    }
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..color = TitoColors.coral.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      fillPath,
      Paint()
        ..color = TitoColors.coral
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _BaseStatsRadarPainter oldDelegate) {
    return oldDelegate.stats != stats;
  }
}

/// Bar chart + radar layout; on square handheld, toggle between views.
class BaseStatsSection extends StatefulWidget {
  const BaseStatsSection({super.key, required this.stats});

  final PokemonBaseStats stats;

  @override
  State<BaseStatsSection> createState() => _BaseStatsSectionState();
}

class _BaseStatsSectionState extends State<BaseStatsSection> {
  bool _showRadar = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatsViewChip(
                label: AppZh.dexBaseStatsBars,
                selected: !_showRadar,
                onTap: () => setState(() => _showRadar = false),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _StatsViewChip(
                label: AppZh.dexBaseStatsRadar,
                selected: _showRadar,
                onTap: () => setState(() => _showRadar = true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            layoutBuilder: (current, previous) =>
                current ?? const SizedBox.shrink(),
            child: _showRadar
                ? SizedBox(
                    key: const ValueKey('radar'),
                    height: 280,
                    child: BaseStatsRadarChart(stats: widget.stats),
                  )
                : BaseStatsCard(
                    key: const ValueKey('bars'),
                    stats: widget.stats,
                  ),
          ),
        ),
      ],
    );
  }
}

class _StatsViewChip extends StatelessWidget {
  const _StatsViewChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TitoRadii.sm),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: selected ? TitoColors.softYellow : TitoColors.card,
            borderRadius: BorderRadius.circular(TitoRadii.sm),
            border: Border.all(color: TitoColors.ink, width: 2),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: SecondaryTypography.onCard.small12.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class TypeEffectivenessGrid extends StatelessWidget {
  const TypeEffectivenessGrid({
    super.key,
    required this.multipliers,
    this.weaknesses,
    this.resistances,
    this.immunities,
  });

  final Map<String, double> multipliers;
  final List<String>? weaknesses;
  final List<String>? resistances;
  final List<String>? immunities;

  bool get _hasSummary =>
      weaknesses != null && resistances != null && immunities != null;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_hasSummary) ...[
            Text(
              AppZh.companionTypeSummaryTitle,
              style: SecondaryTypography.onCard.h15,
            ),
            const SizedBox(height: 8),
            Text(
              profileLine(AppZh.dexWeaknesses, weaknesses!),
              style: SecondaryTypography.onCard.body14,
            ),
            const SizedBox(height: 4),
            Text(
              profileLine(AppZh.dexResistances, resistances!),
              style: SecondaryTypography.onCard.body14,
            ),
            const SizedBox(height: 4),
            Text(
              profileLine(AppZh.dexImmunities, immunities!),
              style: SecondaryTypography.onCard.body14,
            ),
            const SizedBox(height: 16),
            Text(
              AppZh.dexTypeGridTitle,
              style: SecondaryTypography.onCard.h15,
            ),
            const SizedBox(height: 12),
          ] else ...[
            Text(
              AppZh.dexTypeGridTitle,
              style: SecondaryTypography.onCard.h15,
            ),
            const SizedBox(height: 12),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              const crossAxisCount = 6;
              const crossAxisSpacing = 6.0;
              const mainAxisSpacing = 8.0;
              const tileHeight = 68.0;
              final tileWidth = (constraints.maxWidth -
                      crossAxisSpacing * (crossAxisCount - 1)) /
                  crossAxisCount;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: crossAxisSpacing,
                  mainAxisSpacing: mainAxisSpacing,
                  childAspectRatio: tileWidth / tileHeight,
                ),
                itemCount: typeGridOrder.length,
                itemBuilder: (context, index) {
                  final type = typeGridOrder[index];
                  final multiplier = multipliers[type] ?? 1;
                  final label = formatTypeMultiplier(multiplier);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: tileWidth.clamp(32, 56),
                        height: tileWidth.clamp(32, 56),
                        decoration: BoxDecoration(
                          color: typeTileColor(type),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: TitoColors.ink, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          typeIconData(type),
                          size: (tileWidth * 0.55).clamp(18, 28),
                          color: TitoColors.ink,
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
                },
              );
            },
          ),
        ],
      ),
    );
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

class AbilitiesCard extends StatelessWidget {
  const AbilitiesCard({
    super.key,
    required this.abilities,
  });

  final List<PokemonAbility> abilities;

  @override
  Widget build(BuildContext context) {
    if (abilities.isEmpty) {
      return StickerCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppZh.dexAbilities,
              style: SecondaryTypography.onCard.h15,
            ),
            const SizedBox(height: 8),
            Text(
              AppZh.dexAbilityEmptyPending,
              style: SecondaryTypography.onCard.body14.copyWith(
                color: TitoColors.mutedInk,
              ),
            ),
          ],
        ),
      );
    }

    return StickerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppZh.dexAbilities,
            style: SecondaryTypography.onCard.h15,
          ),
          const SizedBox(height: 10),
          ...abilities.map(
            (ability) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ability.displayNameZh,
                          style: SecondaryTypography.onCard.body14.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (ability.isHidden)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: TitoColors.skyBlue.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: TitoColors.ink, width: 1),
                          ),
                          child: Text(
                            AppZh.dexAbilityHidden,
                            style: SecondaryTypography.onCard.small12.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (ability.descriptionZh.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      ability.descriptionZh,
                      style: SecondaryTypography.onCard.small12.copyWith(
                        color: TitoColors.mutedInk,
                        height: 1.35,
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

class ObtainLocationsCard extends StatelessWidget {
  const ObtainLocationsCard({
    super.key,
    required this.locations,
    this.gameLabel,
  });

  final List<ObtainLocationEntry> locations;
  final String? gameLabel;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            gameLabel == null
                ? AppZh.dexObtainHgss
                : AppZh.dexObtainForGame(gameLabel!),
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
          Align(
            alignment: Alignment.centerLeft,
            child: TitoTypeBadge(
              typeEn: entry.move.type,
              size: TypeBadgeSize.small,
            ),
          ),
        ],
      ),
    );
  }
}

/// UI shell for species abilities — data wiring lands with a later bundle.
class AbilityPlaceholderCard extends StatelessWidget {
  const AbilityPlaceholderCard({super.key});

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppZh.dexAbilities,
            style: SecondaryTypography.onCard.h15,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: TitoColors.skyBlue,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: TitoColors.ink, width: 2),
                ),
                child: Text(
                  AppZh.dexAbilityUnknownName,
                  style: SecondaryTypography.onCard.small12.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppZh.dexAbilityPlaceholder,
                  style: SecondaryTypography.onCard.small12.copyWith(
                    color: TitoColors.mutedInk,
                  ),
                ),
              ),
            ],
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
                  style: SecondaryTypography.onCard.team12.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  AppZh.dexGenderFemale(female),
                  style: SecondaryTypography.onCard.meta14,
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
                  style: SecondaryTypography.onCard.team12.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  detail.eggGroups.join(' / '),
                  style: SecondaryTypography.onCard.meta14,
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
                  style: SecondaryTypography.onCard.team12.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  '${detail.hatchCounter} (${detail.hatchSteps})',
                  style: SecondaryTypography.onCard.meta14,
                ),
              ],
            ),
          ],
          if (detail.baseHappiness != null) ...[
            const Divider(height: 20),
            _MetaRow(
              label: AppZh.dexBaseHappiness,
              value: '${detail.baseHappiness}',
            ),
          ],
          if (detail.captureRate != null) ...[
            const Divider(height: 20),
            _MetaRow(
              label: AppZh.dexCaptureRate,
              value: '${detail.captureRate}',
            ),
          ],
          if (detail.evYieldLabel != null) ...[
            const Divider(height: 20),
            _MetaRow(
              label: AppZh.dexEvYield,
              value: detail.evYieldLabel!,
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: SecondaryTypography.onCard.team12.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: SecondaryTypography.onCard.meta14,
          ),
        ),
      ],
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
          style: SecondaryTypography.onCard.team12.copyWith(
            color: TitoColors.mutedInk,
          ),
        ),
        Text(value, style: SecondaryTypography.onCard.h15),
      ],
    );
  }
}

class InteractiveTypeEffectivenessCard extends StatefulWidget {
  const InteractiveTypeEffectivenessCard({
    super.key,
    required this.types,
    required this.abilities,
    required this.generation,
    this.abilityPickerLabel = AppZh.companionDefenderAbilityPick,
  });

  final List<String> types;
  final List<PokemonAbility> abilities;
  final int generation;
  final String abilityPickerLabel;

  @override
  State<InteractiveTypeEffectivenessCard> createState() =>
      _InteractiveTypeEffectivenessCardState();
}

class _InteractiveTypeEffectivenessCardState
    extends State<InteractiveTypeEffectivenessCard> {
  Map<String, TypeDamageRelations>? _relations;
  String? _abilitySlug;
  bool _defenderTerastallized = false;
  String? _defenderTeraType;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _syncDefaultAbility();
    _load();
  }

  @override
  void didUpdateWidget(covariant InteractiveTypeEffectivenessCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.generation != widget.generation ||
        oldWidget.types != widget.types ||
        oldWidget.abilities != widget.abilities) {
      setState(() {
        _defenderTeraType =
            defaultTeraTypeFor(widget.types, widget.generation);
        _syncDefaultAbility(force: oldWidget.abilities != widget.abilities);
      });
    }
  }

  void _syncDefaultAbility({bool force = false}) {
    final options = defensiveAbilityOptionsFrom(widget.abilities);
    final defaultSlug = defaultAbilitySlugForOptions(options);
    if (defaultSlug != null && (_abilitySlug == null || force)) {
      _abilitySlug = defaultSlug;
    }
  }

  Future<void> _load() async {
    try {
      final relations = await battleToolsService.loadTypeRelations();
      if (!mounted) {
        return;
      }
      setState(() {
        _relations = relations;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const StickerCard(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final relations = _relations;
    if (relations == null) {
      return const SizedBox.shrink();
    }

    final options = defensiveAbilityOptionsFrom(widget.abilities);

    final input = BattleEffectivenessInput(
      defenderTypes: widget.types,
      relationsByType: relations,
      defenderAbilitySlug: _abilitySlug,
      generation: widget.generation,
      defenderTerastallized: _defenderTerastallized,
      defenderTeraType: _defenderTeraType ??
          defaultTeraTypeFor(widget.types, widget.generation),
    );
    final profile = computeBattleDefensiveProfile(input);
    final multipliers = computeBattleTypeMultipliers(input);
    final normalized =
        normalizeTypesForGeneration(widget.types, widget.generation);

    return Column(
      children: [
        if (options.isNotEmpty) ...[
          StickerCard(
            child: AbilityChipPicker(
              label: widget.abilityPickerLabel,
              selectedSlug: _abilitySlug,
              options: options,
              onChanged: (slug) => setState(() => _abilitySlug = slug),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (widget.generation >= 9) ...[
          StickerCard(
            child: TerastalPicker(
              label: AppZh.companionDefenderTerastal,
              enabled: true,
              terastallized: _defenderTerastallized,
              teraType: _defenderTeraType,
              fallbackTypes: widget.types,
              generation: widget.generation,
              onTerastallizedChanged: (value) =>
                  setState(() => _defenderTerastallized = value),
              onTeraTypeChanged: (type) =>
                  setState(() => _defenderTeraType = type),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (widget.generation < 6)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '世代修正：${normalized.map(typeNameZh).join('/')}',
                style: SecondaryTypography.onCard.small12.copyWith(
                  color: TitoColors.mutedInk,
                ),
              ),
            ),
          ),
        TypeEffectivenessGrid(
          multipliers: multipliers,
          weaknesses: profile.weaknesses,
          resistances: profile.resistances,
          immunities: profile.immunities,
        ),
      ],
    );
  }
}
