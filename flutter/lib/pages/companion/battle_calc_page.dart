import '../../widgets/battle_content_fade.dart';
import 'package:flutter/material.dart';

import '../../features/game/game_edition_repository.dart';
import '../../features/companion/battle_session.dart';
import '../../features/companion/battle_game_scope.dart';
import '../../l10n/app_zh.dart';
import '../../models/journey.dart';
import '../../theme/device_layout.dart';
import '../../widgets/battle_tool_panels.dart';
import '../../widgets/secondary_page_scaffold.dart';
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
  late final _session = BattleSession(
    level: battleScopeForEdition(gameEditionRepository.edition).defaultLevel,
  );
  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

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
                child: BattleContentFade(
                  changeKey: _mode,
                  child: IndexedStack(
                    index: _mode.index,
                    sizing: StackFit.expand,
                    children: [
                      _modeBody(
                        BattleCalcMode.matchup,
                        TypeMatchupPage(
                          journey: widget.journey,
                          embedded: true,
                          session: _session,
                        ),
                      ),
                      _modeBody(
                        BattleCalcMode.stats,
                        StatCalcPage(
                          journey: widget.journey,
                          embedded: true,
                          session: _session,
                          onHandoffToDamage: () =>
                              _selectMode(BattleCalcMode.damage),
                        ),
                      ),
                      _modeBody(
                        BattleCalcMode.damage,
                        QuickDamagePage(
                          journey: widget.journey,
                          embedded: true,
                          session: _session,
                        ),
                      ),
                      _modeBody(
                        BattleCalcMode.blind,
                        BlindSpotPage(
                          journey: widget.journey,
                          embedded: true,
                          session: _session,
                        ),
                      ),
                    ],
                  ),
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
  Widget build(BuildContext context) => BattleSegmentedControl<BattleCalcMode>(
    key: const ValueKey('battle-mode-rail'),
    value: mode,
    onChanged: onChanged,
    options: {
      BattleCalcMode.matchup: AppZh.battleCalcModeMatchup,
      BattleCalcMode.stats: AppZh.battleCalcModeStats,
      BattleCalcMode.damage: AppZh.battleCalcModeDamage,
      BattleCalcMode.blind: AppZh.battleCalcModeBlind,
    },
  );
}
