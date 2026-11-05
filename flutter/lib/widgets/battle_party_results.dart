import '../features/companion/battle_move_rules.dart';
import '../l10n/app_locale.dart';
import '../features/dex/dex_models.dart';
import '../features/companion/battle_learnset.dart';
import '../features/game/game_edition_repository.dart';
import 'package:flutter/material.dart';

import '../features/companion/battle_math.dart';
import '../features/companion/battle_party_damage.dart';
import '../features/companion/battle_session.dart';
import '../features/dex/type_chart.dart';
import '../l10n/app_zh.dart';
import '../l10n/localized_names.dart';
import '../models/journey.dart';
import '../theme/secondary_typography.dart';
import 'battle_tool_panels.dart';
import 'tito_loading_panel.dart';
import 'tito_animated_number.dart';
import 'tito_sprite_sticker.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_motion.dart';
import '../theme/tito_surface_tokens.dart';
import '../theme/tito_typography.dart';

class BattlePartyResults extends StatelessWidget {
  const BattlePartyResults({
    super.key,
    required this.session,
    required this.party,
    this.relations,
    this.generation = 9,
    this.weatherSlug,
    this.terrainSlug,
    this.critical = false,
    this.screened = false,
    this.spread = false,
    this.compact = false,
  });

  final BattleSession session;
  final List<PartyMember> party;

  /// Null selects the six-stat comparison.
  final Map<String, TypeDamageRelations>? relations;
  final int generation;
  final String? weatherSlug;
  final String? terrainSlug;
  final bool critical;
  final bool screened;
  final bool spread;
  final bool compact;

  List<CachedMove> _legalMoves(BattlePartyEntry entry) {
    final legal = {
      for (final m in battleLearnset(
        entry.combatant.detail,
        gameEditionRepository.edition.dataVersionGroupKey,
      ))
        m.id: m,
    };
    return [
      for (final id in entry.moves.keys)
        if (legal.containsKey(id)) legal[id]!,
    ];
  }

  Widget _compactResult() => FutureBuilder<List<BattlePartyEntry>>(
    future: session.partyEntries(party),
    builder: (context, snapshot) {
      DamageEstimate? best;
      String? bestName;
      for (final entry in snapshot.data ?? <BattlePartyEntry>[]) {
        for (final move in _legalMoves(entry)) {
          final value = estimatePartyMove(
            attacker: entry.combatant,
            defender: session.defender,
            move: move,
            relations: relations!,
            generation: generation,
            weatherSlug: weatherSlug,
            terrainSlug: terrainSlug,
            critical: critical,
            screened: screened,
            spread: spread,
          );
          if (value != null &&
              (best == null || value.maxDamage > best.maxDamage)) {
            best = value;
            bestName = '${entry.name} · ${move.displayName}';
          }
        }
      }
      return Text(
        best == null
            ? AppZh.battleTeamSummary(session.teamCount(party))
            : '$bestName · ${best.minPercent.toStringAsFixed(1)}–${best.maxPercent.toStringAsFixed(1)}%',
      );
    },
  );

  @override
  Widget build(BuildContext context) => compact
      ? _compactResult()
      : BattleResultCard(
          child: DefaultTextStyle(
            style: SecondaryTypography.onCard.small12,
            child: FutureBuilder<List<BattlePartyEntry>>(
              future: session.partyEntries(party),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const TitoInlineLoading(height: 64);
                }
                final entries = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      relations == null
                          ? AppZh.battleTeamStats
                          : AppZh.battleTeamDamage,
                      style: BattleResultText.title,
                    ),
                    const SizedBox(height: 8),
                    if (entries.isEmpty)
                      Text(AppZh.battlePartyEmpty)
                    else if (relations == null)
                      _stats(entries)
                    else ...[
                      _damageList(entries),
                      const SizedBox(height: 4),
                    ],
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      minTileHeight: 44,
                      shape: const Border(),
                      collapsedShape: const Border(),
                      title: Text(
                        entries.any((e) => e.combatant.partyDefaults)
                            ? AppLocale.pick(
                                zh: '计算说明 · 含默认配置',
                                en: 'Notes · includes defaults',
                              )
                            : AppLocale.pick(
                                zh: '计算说明',
                                en: 'Calculation notes',
                              ),
                        style: SecondaryTypography.onCard.small12,
                      ),
                      children: [
                        Text(
                          relations == null
                              ? AppZh.battleTeamStatsHint
                              : AppZh.battleTeamDamageHint,
                        ),
                        if (entries.any((e) => e.combatant.selectionFailed))
                          Text(AppZh.battleTeamMemberFailed),
                        if (entries.any((e) => e.combatant.partyDefaults))
                          Text(AppZh.battlePartyDefaults),
                        if (entries.any((e) => e.combatant.unsupportedItem))
                          Text(AppZh.battleTeamItemsExcluded),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );

  /// Members side by side once two rows of sprite, move and HP bar still fit;
  /// narrower cards keep the single column.
  static const twoColumnWidth = 680.0;

  Widget _damageList(List<BattlePartyEntry> entries) => LayoutBuilder(
    builder: (context, constraints) {
      final rows = [
        for (var i = 0; i < entries.length; i++) _damage(entries[i], i),
      ];
      if (constraints.maxWidth < twoColumnWidth) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              rows[i],
            ],
          ],
        );
      }
      return Column(
        key: const ValueKey('party-damage-two-column'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i += 2) ...[
            if (i > 0) const Divider(height: 1),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: rows[i]),
                const SizedBox(width: 16),
                // An odd last member keeps half the width.
                Expanded(
                  child: i + 1 < rows.length
                      ? rows[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ],
        ],
      );
    },
  );

  /// Highest value per stat among readable members; ties all count. Empty
  /// when fewer than two members can be compared.
  Map<BattleStat, int> _statLeaders(List<BattlePartyEntry> entries) {
    final readable = [
      for (final entry in entries)
        if (!entry.combatant.selectionFailed) entry,
    ];
    if (readable.length < 2) return const {};
    return {
      for (final stat in BattleStat.values)
        stat: readable
            .map((e) => e.combatant.effectiveStat(stat, generation: generation))
            .reduce((a, b) => a > b ? a : b),
    };
  }

  Widget _stats(List<BattlePartyEntry> entries) {
    final leaders = _statLeaders(entries);
    final leaderStyle = SecondaryTypography.onCard.small12.copyWith(
      fontWeight: TitoTypography.weight(FontWeight.w800),
      color: TitoColors.success,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(44),
        columnWidths: const {0: FixedColumnWidth(84)},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            children: [
              _cell(''),
              for (final stat in BattleStat.values) _cell(stat.label),
            ],
          ),
          for (final entry in entries)
            TableRow(
              children: [
                _cell(entry.name),
                for (final stat in BattleStat.values)
                  entry.combatant.selectionFailed
                      ? _cell('—')
                      : Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 4,
                          ),
                          child: Center(
                            child: _statNumber(
                              entry,
                              stat,
                              key: ValueKey(
                                'party-stat-${entries.indexOf(entry)}-'
                                '${stat.name}',
                              ),
                              leaders: leaders,
                              leaderStyle: leaderStyle,
                            ),
                          ),
                        ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _statNumber(
    BattlePartyEntry entry,
    BattleStat stat, {
    required Key key,
    required Map<BattleStat, int> leaders,
    required TextStyle leaderStyle,
  }) {
    final value = entry.combatant.effectiveStat(stat, generation: generation);
    return TitoAnimatedNumber(
      key: key,
      value: value,
      identity: (entry.combatant, stat),
      countUp: true,
      style: leaders[stat] == value ? leaderStyle : null,
    );
  }

  Widget _cell(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
    child: Text(
      text,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );

  /// One member: sprite, best move, a percentage that counts up and the
  /// defender's HP after that hit. Expanding lists every assigned move on the
  /// same grid so nothing shifts between the summary and the details.
  Widget _damage(BattlePartyEntry entry, int index) {
    final name = entry.name;
    final legal = _legalMoves(entry);
    final sprite = TitoSpriteSticker(
      source: entry.combatant.detail?.summary.displaySpritePath,
      size: 36,
    );
    final nameStyle = SecondaryTypography.onCard.body14.copyWith(
      fontWeight: TitoTypography.weight(FontWeight.w800),
    );
    final small = SecondaryTypography.onCard.small12;
    final muted = small.copyWith(color: TitoTypography.mutedColor);
    final title = Row(
      children: [
        Flexible(
          child: Text(
            name,
            style: nameStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (entry.combatant.partyDefaults) ...[
          const SizedBox(width: 6),
          _DefaultsTag(key: ValueKey('party-defaults-$index')),
        ],
      ],
    );
    if (entry.combatant.selectionFailed || legal.isEmpty) {
      return _MemberRow(
        key: ValueKey('party-damage-$index'),
        leading: sprite,
        title: title,
        subtitle: Text(
          entry.combatant.selectionFailed
              ? AppZh.battleTeamMemberFailed
              : AppZh.battleTeamNoMoves,
          style: muted,
        ),
      );
    }
    final results =
        [
          for (final move in legal)
            (
              move: move,
              estimate: estimatePartyMove(
                attacker: entry.combatant,
                defender: session.defender,
                move: move,
                relations: relations!,
                generation: generation,
                weatherSlug: weatherSlug,
                terrainSlug: terrainSlug,
                critical: critical,
                screened: screened,
                spread: spread,
              ),
            ),
        ]..sort(
          (a, b) => (b.estimate?.maxDamage ?? -1).compareTo(
            a.estimate?.maxDamage ?? -1,
          ),
        );
    String issue(CachedMove move) =>
        battleMoveIssue(entry.combatant, session.defender, move, generation) ??
        AppZh.battleTeamMoveUnsupported;
    final identity = entry.combatant;

    Widget moveLine(
      ({CachedMove move, DamageEstimate? estimate}) row, {
      required bool lead,
    }) {
      final estimate = row.estimate;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  estimate == null
                      ? '${row.move.displayName} · ${issue(row.move)}'
                      : '${row.move.displayName} · ${estimate.minDamage}–${estimate.maxDamage} HP',
                  style: estimate == null ? muted : small,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (estimate != null) ...[
                const SizedBox(width: 8),
                TitoAnimatedNumber(
                  value: estimate.maxPercent,
                  fractionDigits: 1,
                  suffix: '%',
                  countUp: true,
                  // The lead line tracks "best hit", whichever move it is, so
                  // a reshuffle rolls the number instead of restarting it.
                  identity: (identity, lead ? 'best' : row.move.id),
                  style: (lead ? nameStyle : small).copyWith(
                    fontWeight: TitoTypography.weight(FontWeight.w800),
                  ),
                ),
              ],
            ],
          ),
          if (estimate != null) ...[
            const SizedBox(height: 4),
            BattleHpBar(
              damageFraction: estimate.maxPercent / 100,
              height: lead ? 8 : 6,
              onDisplay: false,
            ),
          ],
        ],
      );
    }

    return _MemberRow(
      key: ValueKey('party-damage-$index'),
      leading: sprite,
      title: title,
      subtitle: moveLine(results.first, lead: true),
      details: results.length < 2
          ? null
          : [
              for (final row in results.skip(1))
                Padding(
                  key: ValueKey('party-move-${row.move.id}'),
                  padding: const EdgeInsets.only(top: 8),
                  child: moveLine(row, lead: false),
                ),
            ],
    );
  }
}

/// Muted label after a member name whose missing values use defaults.
class _DefaultsTag extends StatelessWidget {
  const _DefaultsTag({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(TitoRadii.sm),
      border: Border.fromBorderSide(
        TitoSurfaceTokens.of(context).elementOutline,
      ),
    ),
    child: Text(
      AppZh.battlePartyDefaultTag,
      maxLines: 1,
      style: SecondaryTypography.onCard.small12.copyWith(
        color: TitoTypography.mutedColor,
      ),
    ),
  );
}

/// A member line with an optional "other moves" disclosure. Avoids
/// ExpansionTile so the title, numbers and bar keep the card's typography and
/// the whole row is one D-pad stop.
class _MemberRow extends StatefulWidget {
  const _MemberRow({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.details,
  });

  final Widget leading;
  final Widget title;
  final Widget subtitle;
  final List<Widget>? details;

  @override
  State<_MemberRow> createState() => _MemberRowState();
}

class _MemberRowState extends State<_MemberRow> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final details = widget.details;
    final body = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.leading,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: widget.title),
                    if (details != null)
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: TitoMotion.duration(context, TitoMotion.fast),
                        child: Icon(
                          Icons.expand_more_rounded,
                          size: 20,
                          color: TitoTypography.mutedColor,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                widget.subtitle,
                if (details != null)
                  AnimatedSize(
                    duration: TitoMotion.duration(context, TitoMotion.standard),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _open
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: details,
                          )
                        : const SizedBox(width: double.infinity),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (details == null) return body;
    return Semantics(
      button: true,
      expanded: _open,
      child: InkWell(
        borderRadius: BorderRadius.circular(TitoRadii.md),
        onTap: () => setState(() => _open = !_open),
        child: body,
      ),
    );
  }
}
