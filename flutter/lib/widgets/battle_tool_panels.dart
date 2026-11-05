import 'package:flutter/material.dart';

import '../features/dex/type_chart.dart';
import '../l10n/app_zh.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_motion.dart';
import '../theme/tito_surface_tokens.dart';
import '../theme/tito_typography.dart';
import 'sticker_card.dart';
import 'tito_loading_panel.dart';
import 'tito_segmented_control.dart';
import 'type_badge.dart';
import 'tito_state_panel.dart';

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

/// Translucent rail on the deep display card (HP bar track, verdict pill).
final Color _displayRailFill = Colors.white.withValues(alpha: 0.16);

/// One result surface for every battle tool: the same padding, title style
/// and spacing. [display] picks the deep card for a single computed value.
/// [trailing] sits at the end of the title row (for example a verdict pill).
class BattleResultCard extends StatelessWidget {
  const BattleResultCard({
    super.key,
    required this.child,
    this.title,
    this.display = false,
    this.trailing,
  });

  final String? title;
  final bool display;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final titleStyle = display
        ? BattleResultText.eyebrow
        : BattleResultText.title;
    return StickerCard(
      variant: display ? StickerVariant.deep : StickerVariant.cream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null || trailing != null) ...[
            if (trailing == null)
              Text(title!, style: titleStyle)
            else
              Row(
                children: [
                  Expanded(child: Text(title ?? '', style: titleStyle)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: trailing,
                    ),
                  ),
                ],
              ),
            SizedBox(height: display ? 10 : 8),
          ],
          child,
        ],
      ),
    );
  }
}

/// A short status label on the deep display card, such as the damage
/// verdict. Shares the HP bar's translucent rail fill and outline.
class BattleDisplayPill extends StatelessWidget {
  const BattleDisplayPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: _displayRailFill,
      borderRadius: BorderRadius.circular(999),
      border: Border.fromBorderSide(
        TitoSurfaceTokens.of(context).elementOutline,
      ),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: BattleResultText.eyebrow.copyWith(
        fontWeight: TitoTypography.weight(FontWeight.w800),
      ),
    ),
  );
}

/// Defender HP after one hit: mint for what is left, coral for the damage.
/// It drains from full when a result first appears and glides between
/// results afterwards. [onDisplay] picks the translucent rail used on the
/// deep result card; list rows on cream cards use the party surface.
class BattleHpBar extends StatelessWidget {
  const BattleHpBar({
    super.key,
    required this.damageFraction,
    this.height = 20,
    this.onDisplay = true,
  });

  final double damageFraction;
  final double height;
  final bool onDisplay;

  @override
  Widget build(BuildContext context) {
    final tokens = TitoSurfaceTokens.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: damageFraction.clamp(0.0, 1.0)),
      duration: TitoMotion.duration(context, TitoMotion.countUp),
      curve: Curves.easeOutQuart,
      builder: (context, fraction, _) => Container(
        height: height,
        decoration: BoxDecoration(
          color: onDisplay
              ? _displayRailFill
              : tokens.surface(TitoSurfaceRole.party).fill,
          borderRadius: BorderRadius.circular(999),
          border: Border.fromBorderSide(tokens.elementOutline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: ((1 - fraction) * 1000).round(),
              child: const ColoredBox(color: TitoColors.mint),
            ),
            Expanded(
              flex: (fraction * 1000).round(),
              child: const ColoredBox(color: TitoColors.coral),
            ),
          ],
        ),
      ),
    );
  }
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
    child: TitoErrorPanel(message: message, onRetry: onRetry, framed: false),
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
    final weak = [
      for (final v in values)
        if (v > 1) v,
    ];
    final resist = [
      for (final v in values)
        if (v > 0 && v < 1) v,
    ];
    final immune = [
      for (final v in values)
        if (v <= 0) v,
    ];
    final neutral = [
      for (final v in values)
        if (v == 1) v,
    ];
    int typeCount(List<double> section) =>
        section.fold(0, (n, v) => n + groups[v]!.length);

    Widget row(double value) => Padding(
      key: ValueKey('matchup-multiplier-$value'),
      padding: const EdgeInsets.symmetric(vertical: 4),
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
                  TitoTypeBadge(typeEn: type, size: TypeBadgeSize.small),
              ],
            ),
          ),
        ],
      ),
    );

    final sections = [
      for (final (label, tone, section) in [
        (AppZh.battleMatchupWeak, 2.0, weak),
        (AppZh.battleMatchupResist, 0.5, resist),
        (AppZh.battleMatchupImmune, 0.0, immune),
      ])
        if (section.isNotEmpty)
          Column(
            key: ValueKey('matchup-section-$tone'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '$label ${typeCount(section)}',
                  style: SecondaryTypography.onCard.small12.copyWith(
                    fontWeight: TitoTypography.weight(FontWeight.w800),
                    color: typeMultiplierColor(tone),
                  ),
                ),
              ),
              for (final value in section) row(value),
            ],
          ),
      if (neutral.isNotEmpty)
        // Neutral hits are the longest and least useful list: folded by
        // default, one D-pad stop like the other battle disclosures.
        ExpansionTile(
          key: const PageStorageKey('battle-matchup-neutral'),
          title: Text(
            AppZh.battleMatchupNeutral(typeCount(neutral)),
            style: SecondaryTypography.onCard.small12.copyWith(
              fontWeight: TitoTypography.weight(FontWeight.w800),
              color: TitoTypography.mutedColor,
            ),
          ),
          tilePadding: EdgeInsets.zero,
          minTileHeight: 44,
          childrenPadding: const EdgeInsets.only(bottom: 4),
          shape: const Border(),
          collapsedShape: const Border(),
          children: [for (final value in neutral) row(value)],
        ),
    ];
    return BattleResultCard(
      title: AppZh.battleMatchupSummary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, section) in sections.indexed) ...[
            // Same theme divider as the blind-spot summary.
            if (index > 0) const Divider(height: 16),
            section,
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

  /// Offensive and defensive holes sit side by side once each column still
  /// has room for a few badges per line.
  static const sideBySideWidth = 560.0;

  @override
  Widget build(BuildContext context) => BattleResultCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final attack = _row(AppZh.companionOffensiveBlindSpots, offensive);
            final defend = _row(AppZh.companionDefensiveBlindSpots, defensive);
            if (constraints.maxWidth >= sideBySideWidth) {
              return Row(
                key: const ValueKey('blind-spots-side-by-side'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: attack),
                  const SizedBox(width: 16),
                  Expanded(child: defend),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [attack, const Divider(height: 16), defend],
            );
          },
        ),
        if (note != null && note!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(note!, style: SecondaryTypography.onCard.small12),
        ],
      ],
    ),
  );

  Widget _row(String label, List<String> types) {
    final shown = [
      for (final type in typeGridOrder)
        if (types.contains(typeNameZh(type))) type,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label · ${shown.length}', style: BattleResultText.title),
        const SizedBox(height: 6),
        if (shown.isEmpty)
          Text(AppZh.dexNone, style: SecondaryTypography.onCard.body14)
        else
          Wrap(
            spacing: 5,
            runSpacing: 4,
            children: [
              for (final type in shown)
                TitoTypeBadge(typeEn: type, size: TypeBadgeSize.small),
            ],
          ),
      ],
    );
  }
}
