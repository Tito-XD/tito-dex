import 'package:flutter/material.dart';

import '../features/dex/type_chart.dart';
import '../l10n/app_zh.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
import 'sticker_card.dart';
import 'tito_loading_panel.dart';
import 'tito_segmented_control.dart';
import 'type_badge.dart';

String battleMatchupCompactLabel(Map<String, double> multipliers) {
  final counts = <double, int>{};
  for (final value in multipliers.values) {
    counts.update(value, (n) => n + 1, ifAbsent: () => 1);
  }
  final values = counts.keys.toList()..sort((a, b) => b.compareTo(a));
  return values
      .map((v) => '${formatTypeMultiplier(v)}×: ${counts[v]}')
      .join(' · ');
}

/// Text roles on battle result cards. The deep "display" card carries one
/// computed value; every list or table result sits on a cream card.
abstract final class BattleResultText {
  /// Small label above a display value.
  static TextStyle get eyebrow =>
      SecondaryTypography.onGradient.small12.copyWith(
        fontWeight: TitoTypography.weight(FontWeight.w800),
        color: TitoColors.skyBlue,
      );

  /// The one large number on a display card.
  static TextStyle get hero =>
      SecondaryTypography.onGradient.h34.copyWith(color: TitoColors.softYellow);

  /// Secondary facts beside or below the hero value.
  static TextStyle get meta => SecondaryTypography.onGradient.small12.copyWith(
    fontWeight: TitoTypography.weight(FontWeight.w700),
    color: TitoColors.skyBlue,
  );

  /// Body copy on a display card.
  static TextStyle get displayBody => SecondaryTypography.onGradient.body14;

  /// Title of a list/table result card.
  static TextStyle get title => SecondaryTypography.onCard.h15;
}

/// One result surface for every battle tool: the same padding, title style
/// and spacing. [display] picks the deep card for a single computed value.
class BattleResultCard extends StatelessWidget {
  const BattleResultCard({
    super.key,
    required this.child,
    this.title,
    this.display = false,
  });

  final String? title;
  final bool display;
  final Widget child;

  @override
  Widget build(BuildContext context) => StickerCard(
    variant: display ? StickerVariant.deep : StickerVariant.cream,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Text(
            title!,
            style: display ? BattleResultText.eyebrow : BattleResultText.title,
          ),
          SizedBox(height: display ? 10 : 8),
        ],
        child,
      ],
    ),
  );
}

/// Result slot while type data loads. Keeps the page in its result layout so
/// nothing jumps when the real result arrives.
class BattleResultLoading extends StatelessWidget {
  const BattleResultLoading({super.key});

  @override
  Widget build(BuildContext context) =>
      TitoLoadingPanel(message: AppZh.companionLoading, compact: true);
}

/// Result slot when type data failed to load.
class BattleResultError extends StatelessWidget {
  const BattleResultError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => BattleResultCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: SecondaryTypography.onCard.small12.copyWith(
            color: TitoTypography.mutedColor,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(AppZh.dexRetry),
        ),
      ],
    ),
  );
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
    return BattleResultCard(
      title: AppZh.battleMatchupSummary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, value) in values.indexed) ...[
            // Same theme divider as the blind-spot summary.
            if (index > 0) const Divider(height: 1),
            Padding(
              key: ValueKey('matchup-multiplier-$value'),
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      '${formatTypeMultiplier(value)}×',
                      style: SecondaryTypography.onCard.body14.copyWith(
                        fontWeight: TitoTypography.weight(FontWeight.w800),
                        color: typeMultiplierColor(value),
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
          ],
          if (note != null && note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(note!, style: SecondaryTypography.onCard.small12),
          ],
        ],
      ),
    );
  }
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
  Widget build(BuildContext context) => BattleResultCard(
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
      Text(label, style: BattleResultText.title),
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
