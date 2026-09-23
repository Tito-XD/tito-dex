import 'package:flutter/material.dart';

import '../features/dex/type_chart.dart';
import '../l10n/app_zh.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import 'tito_segmented_control.dart';
import 'sticker_card.dart';
import 'type_badge.dart';

String battleMatchupCompactLabel(Map<String, double> multipliers) {
  final counts = <double, int>{};
  for (final value in multipliers.values) {
    counts.update(value, (n) => n + 1, ifAbsent: () => 1);
  }
  final values = counts.keys.toList()..sort((a, b) => b.compareTo(a));
  return values
      .map((v) => '${v == v.roundToDouble() ? v.toInt() : v}×: ${counts[v]}')
      .join(' · ');
}

/// The tool rail and scope selector use the shared capsule geometry.
class BattleSegmentedControl<T> extends TitoSegmentedControl<T> {
  const BattleSegmentedControl({
    super.key,
    required super.value,
    required super.options,
    required super.onChanged,
  }) : super(
         indicatorKey: const ValueKey('battle-segment-indicator'),
         railKey: const ValueKey('battle-segment-rail'),
       );
}

/// One reading order in every battle tool: attacker left, defender right.
class BattleCombatants extends StatelessWidget {
  const BattleCombatants({
    super.key,
    required this.attacker,
    required this.defender,
    this.showAttacker = true,
  });

  final Widget attacker;
  final Widget defender;
  final bool showAttacker;

  @override
  Widget build(BuildContext context) => !showAttacker
      ? defender
      : Row(
          key: const ValueKey('battle-combatants'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: attacker),
            const SizedBox(width: 10),
            Expanded(child: defender),
          ],
        );
}

/// Less frequently adjusted fields stay available without filling the page.
class BattleMoreOptions extends StatelessWidget {
  const BattleMoreOptions({
    super.key,
    required this.children,
    this.title,
    this.storageId = 'general',
  });

  final List<Widget> children;
  final String? title;
  final String storageId;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: PageStorageKey('battle-more-$storageId'),
    title: Text(title ?? AppZh.battleMoreOptions),
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(bottom: 8),
    maintainState: true,
    shape: const Border(),
    collapsedShape: const Border(),
    children: children,
  );
}

/// Group actual calculated values, including ability-specific multipliers.
/// Never round a 1.5x or 0.75x modifier into a standard type-chart bucket.
class BattleMatchupSummary extends StatelessWidget {
  const BattleMatchupSummary({super.key, required this.multipliers, this.note});

  final Map<String, double> multipliers;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final groups = <double, List<String>>{};
    for (final entry in multipliers.entries) {
      groups.putIfAbsent(entry.value, () => []).add(entry.key);
    }
    final values = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    return StickerCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppZh.battleMatchupSummary,
            style: SecondaryTypography.onCard.h15,
          ),
          const SizedBox(height: 8),
          for (final value in values)
            Container(
              key: ValueKey('matchup-multiplier-$value'),
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: TitoColors.deepBlue.withValues(alpha: .10),
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      '${_multiplierLabel(value)}×',
                      style: SecondaryTypography.onCard.body14.copyWith(
                        fontWeight: FontWeight.w800,
                        color: value > 1
                            ? TitoColors.danger
                            : value > 0 && value < 1
                            ? TitoColors.success
                            : TitoColors.deepBlue,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        for (final type in groups[value]!)
                          TitoTypeBadge(
                            typeEn: type,
                            size: TypeBadgeSize.small,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (note != null && note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(note!, style: SecondaryTypography.onCard.small12),
          ],
        ],
      ),
    );
  }

  String _multiplierLabel(double value) => switch (value) {
    .5 => '½',
    .25 => '¼',
    _ =>
      value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toString(),
  };
}

class BattleBlindSpotSummary extends StatelessWidget {
  const BattleBlindSpotSummary({
    super.key,
    required this.offensive,
    required this.defensive,
    this.note,
  });

  final List<String> offensive;
  final List<String> defensive;
  final String? note;

  @override
  Widget build(BuildContext context) => StickerCard(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row(AppZh.companionOffensiveBlindSpots, offensive),
        const Divider(height: 16),
        _row(AppZh.companionDefensiveBlindSpots, defensive),
        if (note != null && note!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(note!, style: SecondaryTypography.onCard.small12),
        ],
      ],
    ),
  );

  Widget _row(String label, List<String> types) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: SecondaryTypography.onCard.h15),
      const SizedBox(height: 6),
      if (types.isEmpty)
        Text(AppZh.dexNone, style: SecondaryTypography.onCard.body14)
      else
        Wrap(
          spacing: 5,
          runSpacing: 4,
          children: [
            for (final type in typeGridOrder)
              if (types.contains(typeNameZh(type)))
                TitoTypeBadge(typeEn: type, size: TypeBadgeSize.small),
          ],
        ),
    ],
  );
}
