import 'package:flutter/material.dart';

import '../features/companion/battle_session.dart';
import '../features/dex/dex_models.dart';
import '../features/dex/dex_repository.dart';
import '../l10n/app_zh.dart';
import '../models/journey.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_surface_tokens.dart';
import 'party_team_list.dart';

class BattlePartyPicker extends StatelessWidget {
  const BattlePartyPicker({
    super.key,
    required this.journey,
    required this.combatant,
  });
  final CurrentJourney journey;
  final BattleCombatant combatant;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    style: TextButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    ),
    onPressed: journey.party.isEmpty
        ? null
        : () async {
            final member = await showModalBottomSheet<PartyMember>(
              context: context,
              isScrollControlled: true,
              backgroundColor: TitoSurfaceTokens.of(context).cardFill,
              builder: (context) => SafeArea(
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * .6,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        AppZh.battleChooseParty,
                        style: SecondaryTypography.onCard.h15,
                      ),
                      const SizedBox(height: 12),
                      BattlePartyBoard(
                        party: journey.party,
                        onSelect: (index) =>
                            Navigator.pop(context, journey.party[index]),
                      ),
                    ],
                  ),
                ),
              ),
            );
            if (member == null || !context.mounted) return;
            await combatant.selectParty(member);
          },
    icon: const Icon(Icons.groups_rounded, size: 16),
    label: Text(
      journey.party.isEmpty ? AppZh.battlePartyEmpty : AppZh.battleChooseParty,
      textAlign: TextAlign.center,
    ),
  );
}

/// Same roster as Party, including cached sprites when offline.
class BattlePartyBoard extends StatefulWidget {
  const BattlePartyBoard({super.key, required this.party, this.onSelect});
  final List<PartyMember> party;
  final ValueChanged<int>? onSelect;

  @override
  State<BattlePartyBoard> createState() => _BattlePartyBoardState();
}

class _BattlePartyBoardState extends State<BattlePartyBoard> {
  late Future<Map<int, PokemonDetail>> _details = _load();

  Future<Map<int, PokemonDetail>> _load() async {
    final ids = widget.party.map((m) => m.speciesId).whereType<int>().toSet();
    final entries = await Future.wait(
      ids.map((id) async {
        try {
          return MapEntry(id, await dexRepository.getDetail(id));
        } catch (_) {
          return null;
        }
      }),
    );
    return Map.fromEntries(entries.whereType<MapEntry<int, PokemonDetail>>());
  }

  @override
  void didUpdateWidget(covariant BattlePartyBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.party != widget.party) _details = _load();
  }

  @override
  Widget build(BuildContext context) => PartyTeamBoard(
    party: widget.party,
    detailsFuture: _details,
    adaptiveHeight: true,
    onSelect: widget.onSelect,
  );
}

class BattleDraftNotice extends StatelessWidget {
  const BattleDraftNotice({super.key, required this.combatant});
  final BattleCombatant combatant;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (combatant.loading) const LinearProgressIndicator(),
      if (combatant.selectionFailed)
        Text(
          AppZh.battleSelectionFailed,
          style: SecondaryTypography.onCard.small12,
        ),
      if (combatant.partyDefaults)
        Text(
          AppZh.battlePartyDefaults,
          style: SecondaryTypography.onCard.small12,
        ),
      if (combatant.unsupportedItem)
        Text(
          AppZh.battleUnsupportedItem,
          style: SecondaryTypography.onCard.small12,
        ),
      if (combatant.overrides.isNotEmpty)
        TextButton(
          onPressed: combatant.restoreStats,
          child: Text(AppZh.battleRestoreStats),
        ),
    ],
  );
}
