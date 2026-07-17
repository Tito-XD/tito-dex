import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/dex/dex_models.dart';
import '../features/dex/dex_repository.dart';
import '../features/game/game_edition_repository.dart';
import '../features/game/journey_capability.dart';
import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/device_layout.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_font_scale.dart';
import '../widgets/companion_tool_fields.dart';
import '../widgets/party_team_list.dart';
import '../widgets/secondary_page_scaffold.dart';
import '../widgets/sticker_card.dart';
import '../widgets/team_summary_card.dart';

class TeamPage extends StatefulWidget {
  const TeamPage({
    super.key,
    required this.journey,
    required this.onSaveJourney,
  });

  final CurrentJourney journey;
  final ValueChanged<CurrentJourney> onSaveJourney;

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  static const _diffBannerDismissedKey = 'team.saveDiffBannerDismissedSig';

  late List<PartyMember> _party;
  String? _dismissedDiffSig;

  /// Fingerprint of the current manual-party vs save-party divergence — the
  /// dismissal only holds while the divergence stays the same.
  String get _diffSig {
    String encode(List<PartyMember> members) => members
        .map((m) => '${m.speciesId ?? m.species}:${m.level}')
        .join(',');
    return '${encode(widget.journey.party)}|'
        '${encode(widget.journey.saveSyncedParty)}';
  }

  bool get _showSaveDiffBanner =>
      gameEditionRepository.edition.isSaveLinked &&
      widget.journey.partyDiffersFromSave &&
      _dismissedDiffSig != _diffSig;

  @override
  void initState() {
    super.initState();
    _party = List<PartyMember>.from(widget.journey.party);
    _loadDiffBannerDismissal();
  }

  Future<void> _loadDiffBannerDismissal() async {
    final prefs = await SharedPreferences.getInstance();
    final sig = prefs.getString(_diffBannerDismissedKey);
    if (mounted && sig != null) {
      setState(() => _dismissedDiffSig = sig);
    }
  }

  Future<void> _dismissDiffBanner() async {
    final sig = _diffSig;
    setState(() => _dismissedDiffSig = sig);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_diffBannerDismissedKey, sig);
  }

  @override
  void didUpdateWidget(TeamPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.journey != widget.journey) {
      _party = List<PartyMember>.from(widget.journey.party);
    }
  }

  void _saveParty(List<PartyMember> party, {bool userOverride = true}) {
    setState(() => _party = party);
    widget.onSaveJourney(
      widget.journey.copyWith(
        party: party,
        partyUserOverride: userOverride ? true : false,
      ),
    );
  }

  Future<void> _confirmSyncFromSave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppZh.partySaveSyncConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppZh.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppZh.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    widget.onSaveJourney(
      widget.journey.copyWith(
        party: List<PartyMember>.from(widget.journey.saveSyncedParty),
        partyUserOverride: false,
      ),
    );
  }

  Future<void> _editMember(int index) async {
    final member = _party[index];
    final levelController = TextEditingController(
      text: member.level?.toString() ?? '',
    );
    final nicknameController = TextEditingController(
      text: member.nickname ?? '',
    );
    var selectedTypes = List<String>.from(
      member.types.isNotEmpty ? member.types : const <String>[],
    );
    String? selectedAbility = member.abilitySlug;
    List<PokemonAbility> abilities = const [];
    var speciesLinked = false;
    if (member.speciesId != null) {
      try {
        final summary = await dexRepository.getSummary(member.speciesId!);
        if (selectedTypes.isEmpty) {
          selectedTypes = List<String>.from(summary.types);
        }
        speciesLinked = true;
        abilities = await dexRepository.abilitiesForPokemon(member.speciesId!);
        selectedAbility ??= defaultAbilitySlugForOptions(
          defensiveAbilityOptionsFrom(abilities),
        );
      } catch (_) {
        // Keep manual edits when dex data is unavailable.
      }
    }
    if (!mounted) {
      return;
    }

    final abilityOptions = defensiveAbilityOptionsFrom(abilities);
    final editResult = await showModalBottomSheet<_TeamEditResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppZh.teamEditTitle,
                      style: SecondaryTypography.onCard.h15,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: levelController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: AppZh.teamEditLevel,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nicknameController,
                      decoration: const InputDecoration(
                        labelText: AppZh.teamEditNickname,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Same rule as the battle tools: a species-linked member
                    // keeps its own types; only fully manual members pick
                    // from the full grid.
                    if (speciesLinked)
                      LinkedPokemonTypesRow(types: selectedTypes)
                    else
                      TypeChipPicker(
                        label: AppZh.teamEditTypes,
                        selected: selectedTypes,
                        onChanged: (types) =>
                            setSheetState(() => selectedTypes = types),
                      ),
                    if (abilityOptions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      AbilityChipPicker(
                        label: AppZh.teamEditAbility,
                        selectedSlug: selectedAbility,
                        options: abilityOptions,
                        onChanged: (slug) =>
                            setSheetState(() => selectedAbility = slug),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (index > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(
                                context,
                                _TeamEditResult.swapPrev,
                              ),
                              child: const Text(AppZh.teamEditSwapPrev),
                            ),
                          ),
                        if (index > 0 && index < _party.length - 1)
                          const SizedBox(width: 8),
                        if (index < _party.length - 1)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(
                                context,
                                _TeamEditResult.swapNext,
                              ),
                              child: const Text(AppZh.teamEditSwapNext),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () =>
                          Navigator.pop(context, _TeamEditResult.delete),
                      child: const Text(AppZh.teamEditDelete),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, _TeamEditResult.save),
                      child: const Text(AppZh.confirm),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    final level = int.tryParse(levelController.text.trim());
    final nickname = nicknameController.text.trim();
    levelController.dispose();
    nicknameController.dispose();

    if (!mounted || editResult == null) {
      return;
    }

    if (editResult == _TeamEditResult.delete) {
      final updated = List<PartyMember>.from(_party)..removeAt(index);
      _saveParty(updated);
      return;
    }

    if (editResult == _TeamEditResult.swapPrev && index > 0) {
      final updated = List<PartyMember>.from(_party);
      final temp = updated[index - 1];
      updated[index - 1] = updated[index];
      updated[index] = temp;
      _saveParty(updated);
      return;
    }

    if (editResult == _TeamEditResult.swapNext && index < _party.length - 1) {
      final updated = List<PartyMember>.from(_party);
      final temp = updated[index + 1];
      updated[index + 1] = updated[index];
      updated[index] = temp;
      _saveParty(updated);
      return;
    }

    final updated = List<PartyMember>.from(_party);
    updated[index] = member.copyWith(
      level: level,
      nickname: nickname.isEmpty ? null : nickname,
      types: selectedTypes,
      abilitySlug: selectedAbility,
      userEdited: true,
      clearNickname: nickname.isEmpty,
      clearAbilitySlug: selectedAbility == null,
    );
    _saveParty(updated);
  }

  Future<void> _addMember() async {
    final idController = TextEditingController();
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppZh.teamAddTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: AppZh.teamAddByIdHint,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () async {
                final id = await _pickSpeciesFromList(context);
                if (context.mounted && id != null) {
                  Navigator.pop(context, id);
                }
              },
              child: const Text(AppZh.teamAddPick),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppZh.cancel),
          ),
          FilledButton(
            onPressed: () {
              final id = int.tryParse(idController.text.trim());
              if (id == null || id < 1 || id > titodexMaxNationalDexId) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text(AppZh.teamAddInvalidId)),
                );
                return;
              }
              Navigator.pop(context, id);
            },
            child: const Text(AppZh.confirm),
          ),
        ],
      ),
    );
    idController.dispose();

    if (picked == null || _party.length >= 6) {
      return;
    }

    try {
      final summary = await dexRepository.getSummary(picked);
      if (!mounted) {
        return;
      }
      final member = PartyMember(
        species: summary.nameZh,
        speciesId: summary.id,
        level: 5,
        nickname: summary.nameZh,
        types: summary.types,
        abilitySlug: defaultAbilitySlugForOptions(
          defensiveAbilityOptionsFrom(
            await dexRepository.abilitiesForPokemon(summary.id),
          ),
        ),
        userEdited: true,
      );
      _saveParty([..._party, member]);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppZh.teamAddInvalidId)),
      );
    }
  }

  Future<int?> _pickSpeciesFromList(BuildContext context) async {
    List<PokemonSummary> starters;
    try {
      starters = await dexRepository.getSummaryRange(1, 30);
    } catch (_) {
      return null;
    }
    if (!context.mounted) {
      return null;
    }

    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppZh.teamAddPick),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: starters.length,
            itemBuilder: (context, index) {
              final entry = starters[index];
              return ListTile(
                title: Text('#${entry.id} ${entry.nameZh}'),
                onTap: () => Navigator.pop(context, entry.id),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final journey = widget.journey;

    return TitoFontScale(
      multiplier: 1.0,
      child: SecondaryPageScaffold(
        title: AppZh.navTeam,
        padding: DeviceLayout.pagePadding(context),
        children: [
          if (_showSaveDiffBanner)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Material(
                color: TitoColors.softYellow,
                borderRadius: BorderRadius.circular(DeviceLayout.rMd(context)),
                child: InkWell(
                  onTap: _confirmSyncFromSave,
                  borderRadius: BorderRadius.circular(DeviceLayout.rMd(context)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                    child: Row(
                      children: [
                        const Icon(Icons.sync_rounded, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppZh.partySaveDiffBanner,
                            style: SecondaryTypography.onCard.body14.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _dismissDiffBanner,
                          tooltip: AppZh.partySaveDiffDismiss,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          StickerCard(
            variant: StickerVariant.deep,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppZh.navTeam} · ${localizeGame(journey.game)}',
                  style: SecondaryTypography.onGradient.h15,
                ),
                const SizedBox(height: 4),
                Text(
                  AppZh.teamSubtitle(_party.length),
                  style: SecondaryTypography.onGradient.meta14.copyWith(
                    color: TitoColors.skyBlue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TeamSummaryCard(party: _party),
          const SizedBox(height: 14),
          PartyTeamList(
            party: _party,
            showEmptySlots: true,
            onMemberTap: _editMember,
            onEmptySlotTap: _party.length < 6 ? _addMember : null,
          ),
          const SizedBox(height: 14),
          StickerCard(
            variant: StickerVariant.cream,
            child: Text(
              AppZh.teamNote,
              style: SecondaryTypography.onCard.body14.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _TeamEditResult { save, delete, swapPrev, swapNext }
