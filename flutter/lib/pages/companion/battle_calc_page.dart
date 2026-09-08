import 'package:flutter/material.dart';

import '../../features/game/game_edition_repository.dart';
import '../../l10n/app_zh.dart';
import '../../models/journey.dart';
import '../../theme/device_layout.dart';
import '../../theme/secondary_typography.dart';
import '../../theme/tito_colors.dart';
import '../../widgets/handheld_input.dart';
import '../../widgets/secondary_page_scaffold.dart';
import '../../widgets/sticker_card.dart';
import '../../widgets/sticker_pressable.dart';
import 'blind_spot_page.dart';
import 'quick_damage_page.dart';
import 'stat_calc_page.dart';
import 'type_matchup_page.dart';

enum BattleCalcMode { matchup, stats, damage, blind }

class BattleCalcPage extends StatefulWidget {
  const BattleCalcPage({
    super.key,
    required this.journey,
    this.initialMode = BattleCalcMode.matchup,
  });

  final CurrentJourney journey;
  final BattleCalcMode initialMode;

  @override
  State<BattleCalcPage> createState() => _BattleCalcPageState();
}

class _BattleCalcPageState extends State<BattleCalcPage> {
  late BattleCalcMode _mode = widget.initialMode;
  late final Set<BattleCalcMode> _visited = {widget.initialMode};

  void _selectMode(BattleCalcMode mode) => setState(() {
    _mode = mode;
    _visited.add(mode);
  });

  @override
  Widget build(BuildContext context) {
    final pagePadding = DeviceLayout.pagePadding(context);
    return ListenableBuilder(
      listenable: gameEditionRepository,
      builder: (context, _) {
        final edition = gameEditionRepository.edition;
        return Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: pagePadding.copyWith(bottom: 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SecondaryPageAppBar(title: AppZh.battleCalcTitle),
                    const SizedBox(height: 6),
                    SecondaryPageSubtitle(text: edition.label),
                    const SizedBox(height: 10),
                    _BattleCalcModeBar(mode: _mode, onChanged: _selectMode),
                  ],
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: _mode.index,
                  sizing: StackFit.expand,
                  children: [
                    _modeBody(
                      BattleCalcMode.matchup,
                      TypeMatchupPage(journey: widget.journey, embedded: true),
                    ),
                    _modeBody(
                      BattleCalcMode.stats,
                      StatCalcPage(
                        journey: widget.journey,
                        embedded: true,
                        onHandoffToDamage: () =>
                            _selectMode(BattleCalcMode.damage),
                      ),
                    ),
                    _modeBody(
                      BattleCalcMode.damage,
                      QuickDamagePage(journey: widget.journey, embedded: true),
                    ),
                    _modeBody(
                      BattleCalcMode.blind,
                      BlindSpotPage(journey: widget.journey, embedded: true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _modeBody(BattleCalcMode mode, Widget child) => TickerMode(
    enabled: _mode == mode,
    child: _visited.contains(mode) ? child : const SizedBox.shrink(),
  );
}

class _BattleCalcModeBar extends StatelessWidget {
  const _BattleCalcModeBar({required this.mode, required this.onChanged});

  final BattleCalcMode mode;
  final ValueChanged<BattleCalcMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final entry in BattleCalcMode.values) ...[
          if (entry.index > 0) const SizedBox(width: 6),
          Expanded(
            child: _ModeChip(
              label: switch (entry) {
                BattleCalcMode.matchup => AppZh.battleCalcModeMatchup,
                BattleCalcMode.stats => AppZh.battleCalcModeStats,
                BattleCalcMode.damage => AppZh.battleCalcModeDamage,
                BattleCalcMode.blind => AppZh.battleCalcModeBlind,
              },
              selected: mode == entry,
              onTap: () => onChanged(entry),
            ),
          ),
        ],
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(TitoRadii.md);
    final labelStyle = selected
        ? SecondaryTypography.onGradient.small12.copyWith(
            fontWeight: FontWeight.w800,
          )
        : SecondaryTypography.onCard.small12.copyWith(
            fontWeight: FontWeight.w800,
          );
    return HandheldFocusDecorator(
      onActivate: onTap,
      borderRadius: radius,
      child: StickerPressable(
        borderRadius: radius,
        ownShadow: false,
        child: StickerCard(
          variant: selected ? StickerVariant.deep : StickerVariant.cream,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
