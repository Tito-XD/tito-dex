import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/dex/dex_models.dart';
import '../features/dex/dex_repository.dart';
import '../features/dex/ability_type_modifiers.dart';
import '../features/dex/type_chart.dart';
import '../features/companion/battle_handoff.dart';
import '../features/game/game_edition_repository.dart';
import '../features/game/journey_capability.dart';
import '../l10n/app_zh.dart';
import '../models/journey.dart';
import '../navigation/tito_route_work.dart';
import '../theme/device_layout.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_motion.dart';
import '../widgets/companion_picker_sheet.dart';
import '../widgets/companion_tool_fields.dart';
import '../widgets/party_team_list.dart';
import '../widgets/retro_forms.dart';
import '../widgets/secondary_page_scaffold.dart';
import '../widgets/sticker_card.dart';
import '../widgets/sticker_pressable.dart';
import '../widgets/tito_sprite_sticker.dart';
import '../widgets/tito_list_reveal.dart';
import '../widgets/tito_skeleton.dart';
import '../widgets/team_summary_card.dart';
import 'dex/dex_reference_list.dart';

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
  bool _routeSettleScheduled = false;
  bool _contentReady = false;
  bool _richContentReady = false;
  Timer? _richContentTimer;
  Future<Map<int, PokemonDetail>>? _partyDetailsFuture;

  /// Fingerprint of the current manual-party vs save-party divergence — the
  /// dismissal only holds while the divergence stays the same.
  String get _diffSig {
    String encode(List<PartyMember> members) =>
        members.map((m) => '${m.speciesId ?? m.species}:${m.level}').join(',');
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeSettleScheduled) return;
    _routeSettleScheduled = true;
    unawaited(_prepareContentAfterRoute());
  }

  Future<void> _prepareContentAfterRoute() async {
    if (!await waitForIncomingRouteSettled(context) || !mounted) return;
    setState(() => _contentReady = true);
    unawaited(_loadDiffBannerDismissal());
    final delay = TitoMotion.duration(
      context,
      TitoMotion.listReveal + const Duration(milliseconds: 40),
    );
    if (delay == Duration.zero) {
      _enableRichContent();
      return;
    }
    _richContentTimer = Timer(delay, _enableRichContent);
  }

  void _enableRichContent() {
    if (!mounted || _richContentReady) return;
    setState(() {
      _richContentReady = true;
      _partyDetailsFuture = _loadPartyDetails(_party);
    });
  }

  Future<Map<int, PokemonDetail>> _loadPartyDetails(
    List<PartyMember> party,
  ) async {
    final ids = party
        .map((member) => member.speciesId)
        .whereType<int>()
        .toSet()
        .toList(growable: false);
    final entries = await Future.wait(
      ids.map((id) async {
        try {
          return MapEntry(id, await dexRepository.getDetail(id));
        } catch (_) {
          return null;
        }
      }),
    );
    return Map<int, PokemonDetail>.unmodifiable(
      Map.fromEntries(entries.whereType<MapEntry<int, PokemonDetail>>()),
    );
  }

  @override
  void dispose() {
    _richContentTimer?.cancel();
    super.dispose();
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
      if (_richContentReady) {
        _partyDetailsFuture = _loadPartyDetails(_party);
      }
    }
  }

  void _saveParty(List<PartyMember> party, {bool userOverride = true}) {
    setState(() {
      _party = party;
      if (_richContentReady) {
        _partyDetailsFuture = _loadPartyDetails(party);
      }
    });
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

  /// v0.6.7: the member editor expands inline at the tapped slot (team
  /// template) instead of a modal bottom sheet — context stays visible.
  int? _editingIndex;

  void _toggleEditor(int index) {
    setState(() => _editingIndex = _editingIndex == index ? null : index);
  }

  void _handleEditorSave(
    int index, {
    required int? level,
    required String nickname,
    required List<String> types,
    required String? abilitySlug,
    required List<int> moveIds,
  }) {
    final member = _party[index];
    final updated = List<PartyMember>.from(_party);
    updated[index] = member.copyWith(
      level: level,
      nickname: nickname.isEmpty ? null : nickname,
      types: types,
      abilitySlug: abilitySlug,
      moveIds: moveIds,
      userEdited: true,
      clearNickname: nickname.isEmpty,
      clearAbilitySlug: abilitySlug == null,
    );
    _editingIndex = null;
    _saveParty(updated);
  }

  void _handleEditorDelete(int index) {
    final updated = List<PartyMember>.from(_party)..removeAt(index);
    _editingIndex = null;
    _saveParty(updated);
  }

  void _handleEditorSwap(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _party.length) {
      return;
    }
    final updated = List<PartyMember>.from(_party);
    final temp = updated[target];
    updated[target] = updated[index];
    updated[index] = temp;
    // Keep the editor open on the moved member so repeat swaps are easy.
    _editingIndex = target;
    _saveParty(updated);
  }

  Future<void> _addMember() async {
    // Full-dex grid with search (id / 中文名 / 英文名) — same picker UX as
    // the companion sheet, instead of the old 1–30 starter-only dialog.
    final summary = await showSpeciesPickerSheet(
      context,
      title: AppZh.teamAddTitle,
    );
    if (summary == null || !mounted || _party.length >= 6) {
      return;
    }

    try {
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
      if (!mounted) {
        return;
      }
      _saveParty([..._party, member]);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppZh.teamAddInvalidId)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SecondaryPageScaffold(
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
                '${AppZh.navTeam} · ${gameEditionRepository.edition.selectedLabelZh}',
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
        if (!_contentReady) ...[
          const SizedBox(height: 14),
          const TitoCardSkeleton(height: 156),
        ] else ...[
          const SizedBox(height: 14),
          TitoListReveal(
            key: const ValueKey('team-content-reveal'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_richContentReady)
                  TeamSummaryCard(
                    party: _party,
                    detailsFuture: _partyDetailsFuture!,
                  )
                else
                  const TitoCardSkeleton(height: 44),
                const SizedBox(height: 14),
                PartyTeamList(
                  party: _party,
                  detailsFuture: _partyDetailsFuture,
                  showEmptySlots: true,
                  onMemberTap: _toggleEditor,
                  onEmptySlotTap: _party.length < 6 ? _addMember : null,
                  expandedIndex: _editingIndex,
                  editorBuilder: (context, index) => _InlineTeamEditor(
                    key: ValueKey('team-editor-$index'),
                    member: _party[index],
                    index: index,
                    canSwapPrev: index > 0,
                    canSwapNext: index < _party.length - 1,
                    onSave: _handleEditorSave,
                    onDelete: _handleEditorDelete,
                    onSwap: _handleEditorSwap,
                    onClose: () => setState(() => _editingIndex = null),
                  ),
                ),
                const SizedBox(height: 14),
                if (_richContentReady)
                  _TeamAssistCard(
                    party: _party,
                    detailsFuture: _partyDetailsFuture!,
                  )
                else
                  const TitoCardSkeleton(height: 72),
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
          ),
        ],
      ],
    );
  }
}

/// Inline member editor (team template): expands in place of the tapped
/// slot. Two-column name/level fields, linked-or-manual types, ability
/// chips, and sticker action buttons (swap warm / delete warn / save coral).
class _InlineTeamEditor extends StatefulWidget {
  const _InlineTeamEditor({
    super.key,
    required this.member,
    required this.index,
    required this.canSwapPrev,
    required this.canSwapNext,
    required this.onSave,
    required this.onDelete,
    required this.onSwap,
    required this.onClose,
  });

  final PartyMember member;
  final int index;
  final bool canSwapPrev;
  final bool canSwapNext;
  final void Function(
    int index, {
    required int? level,
    required String nickname,
    required List<String> types,
    required String? abilitySlug,
    required List<int> moveIds,
  })
  onSave;
  final ValueChanged<int> onDelete;
  final void Function(int index, int delta) onSwap;
  final VoidCallback onClose;

  @override
  State<_InlineTeamEditor> createState() => _InlineTeamEditorState();
}

class _InlineTeamEditorState extends State<_InlineTeamEditor> {
  late final TextEditingController _levelController;
  late final TextEditingController _nicknameController;
  late List<String> _selectedTypes;
  String? _selectedAbility;
  late Set<int> _selectedMoveIds;
  List<PokemonAbility> _abilities = const [];
  List<CachedMove> _availableMoves = const [];
  var _speciesLinked = false;

  @override
  void initState() {
    super.initState();
    _levelController = TextEditingController(
      text: widget.member.level?.toString() ?? '',
    );
    _nicknameController = TextEditingController(
      text: widget.member.nickname ?? '',
    );
    _selectedTypes = List<String>.from(widget.member.types);
    _selectedAbility = widget.member.abilitySlug;
    _selectedMoveIds = widget.member.moveIds.toSet();
    _loadDexData();
  }

  Future<void> _loadDexData() async {
    final speciesId = widget.member.speciesId;
    if (speciesId == null) {
      return;
    }
    try {
      final summary = await dexRepository.getSummary(speciesId);
      final abilities = await dexRepository.abilitiesForPokemon(speciesId);
      final detail = await dexRepository.getDetail(speciesId);
      final moveSet = detail.moveSetForKey(
        gameEditionRepository.edition.dataVersionGroupKey,
      );
      String? parsedAbilitySlug;
      if (_selectedAbility == null && widget.member.abilityId != null) {
        final catalog = await dexRepository.getAllAbilities();
        for (final ability in catalog) {
          if (ability.id == widget.member.abilityId) {
            parsedAbilitySlug = abilitySlugFromNameEn(ability.nameEn);
            break;
          }
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        if (_selectedTypes.isEmpty) {
          _selectedTypes = List<String>.from(summary.types);
        }
        _speciesLinked = true;
        _abilities = abilities;
        _availableMoves = List<CachedMove>.from(moveSet.allMoves)
          ..sort((a, b) => a.nameZh.compareTo(b.nameZh));
        _selectedAbility ??= parsedAbilitySlug;
        _selectedAbility ??= defaultAbilitySlugForOptions(
          defensiveAbilityOptionsFrom(abilities),
        );
      });
    } catch (_) {
      // Keep manual edits when dex data is unavailable.
    }
  }

  @override
  void dispose() {
    _levelController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _pickMoves() async {
    var query = '';
    final working = Set<int>.from(_selectedMoveIds);
    final picked = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final normalized = query.trim().toLowerCase();
          final visible = normalized.isEmpty
              ? _availableMoves
              : _availableMoves
                    .where(
                      (move) =>
                          move.nameZh.contains(query.trim()) ||
                          move.nameEn.toLowerCase().contains(normalized) ||
                          move.id.toString() == normalized,
                    )
                    .toList(growable: false);
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.76,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '选择招式 · ${working.length}/4',
                            style: SecondaryTypography.onCard.h15,
                          ),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(sheetContext, working),
                          child: const Text(AppZh.confirm),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      autofocus: true,
                      decoration: retroInsetDecoration(labelText: '搜索招式名称或编号'),
                      onChanged: (value) => setSheetState(() => query = value),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final move = visible[index];
                          final selected = working.contains(move.id);
                          return CheckboxListTile(
                            dense: true,
                            value: selected,
                            title: Text(move.nameZh),
                            subtitle: Text(
                              '#${move.id} · ${typeNameZh(move.type)} · ${_moveCategoryLabelZh(move.category)}',
                            ),
                            onChanged: !selected && working.length >= 4
                                ? null
                                : (checked) => setSheetState(() {
                                    if (checked == true) {
                                      working.add(move.id);
                                    } else {
                                      working.remove(move.id);
                                    }
                                  }),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedMoveIds = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final abilityOptions = defensiveAbilityOptionsFrom(_abilities);
    final radius = BorderRadius.circular(TitoRadii.sm);
    return StickerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (widget.member.speciesId != null)
                FutureBuilder(
                  future: dexRepository.getSummary(widget.member.speciesId!),
                  builder: (context, snapshot) => TitoSpriteSticker(
                    source: snapshot.data?.displaySpritePath,
                    size: 40,
                    radius: 12,
                  ),
                )
              else
                const TitoSpriteSticker(source: null, size: 40, radius: 12),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${AppZh.teamEditTitle} · 槽位 ${widget.index + 1}',
                  style: SecondaryTypography.onCard.h15.copyWith(
                    color: TitoColors.deepBlue,
                  ),
                ),
              ),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: AppZh.cancel,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _nicknameController,
                  decoration: retroInsetDecoration(
                    labelText: AppZh.teamEditNickname,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _levelController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: retroInsetDecoration(
                    labelText: AppZh.teamEditLevel,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_speciesLinked)
            LinkedPokemonTypesRow(types: _selectedTypes)
          else
            TypeChipPicker(
              label: AppZh.teamEditTypes,
              selected: _selectedTypes,
              onChanged: (types) => setState(() => _selectedTypes = types),
            ),
          if (abilityOptions.isNotEmpty) ...[
            const SizedBox(height: 12),
            AbilityChipPicker(
              label: AppZh.teamEditAbility,
              selectedSlug: _selectedAbility,
              options: abilityOptions,
              onChanged: (slug) => setState(() => _selectedAbility = slug),
            ),
          ],
          if (_availableMoves.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '当前招式（最多 4 个）',
              style: SecondaryTypography.onCard.small12.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final move in _availableMoves)
                  if (_selectedMoveIds.contains(move.id))
                    InputChip(
                      label: Text(move.nameZh),
                      onDeleted: () =>
                          setState(() => _selectedMoveIds.remove(move.id)),
                    ),
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: Text(_selectedMoveIds.isEmpty ? '选择招式' : '调整招式'),
                  onPressed: _pickMoves,
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              if (widget.canSwapPrev) ...[
                Expanded(
                  child: _EditorActionButton(
                    label: AppZh.teamEditSwapPrev,
                    background: TitoColors.cardWarm,
                    foreground: TitoColors.deepBlue,
                    radius: radius,
                    onTap: () => widget.onSwap(widget.index, -1),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (widget.canSwapNext) ...[
                Expanded(
                  child: _EditorActionButton(
                    label: AppZh.teamEditSwapNext,
                    background: TitoColors.cardWarm,
                    foreground: TitoColors.deepBlue,
                    radius: radius,
                    onTap: () => widget.onSwap(widget.index, 1),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _EditorActionButton(
                  label: AppZh.teamEditDelete,
                  background: const Color(0xFFFDE0D6),
                  foreground: const Color(0xFF7A2A12),
                  radius: radius,
                  onTap: () => widget.onDelete(widget.index),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _EditorActionButton(
            label: AppZh.confirm,
            background: TitoColors.coral,
            foreground: const Color(0xFF4A1B0C),
            radius: radius,
            onTap: () => widget.onSave(
              widget.index,
              level: int.tryParse(_levelController.text.trim()),
              nickname: _nicknameController.text.trim(),
              types: _selectedTypes,
              abilitySlug: _selectedAbility,
              moveIds: _selectedMoveIds.toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamAssistCard extends StatefulWidget {
  const _TeamAssistCard({required this.party, required this.detailsFuture});

  final List<PartyMember> party;
  final Future<Map<int, PokemonDetail>> detailsFuture;

  @override
  State<_TeamAssistCard> createState() => _TeamAssistCardState();
}

class _TeamAssistCardState extends State<_TeamAssistCard> {
  late Future<List<_TeamAssistEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _TeamAssistCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.party != widget.party ||
        oldWidget.detailsFuture != widget.detailsFuture) {
      _future = _load();
    }
  }

  Future<List<_TeamAssistEntry>> _load() async {
    final details = await widget.detailsFuture;
    final moves = {
      for (final move in await dexRepository.getAllMoves()) move.id: move,
    };
    final abilities = {
      for (final ability in await dexRepository.getAllAbilities())
        ability.id: ability,
    };
    final abilitiesBySlug = {
      for (final ability in abilities.values)
        abilitySlugFromNameEn(ability.nameEn): ability,
    };
    Map<int, Map<String, dynamic>> items = const {};
    try {
      items = {
        for (final item in await dexRepository.getReferenceEntries(
          'items.json',
        ))
          if (item['id'] is num) (item['id'] as num).toInt(): item,
      };
    } catch (_) {
      // Rich save details remain useful when the optional item catalog is not
      // installed yet; show the numeric held-item ID as a transparent fallback.
    }
    final result = <_TeamAssistEntry>[];
    for (final member in widget.party) {
      final id = member.speciesId;
      final detail = id == null ? null : details[id];
      final node = id == null
          ? null
          : _findEvolutionNode(detail?.evolutionChain, id);
      result.add(
        _TeamAssistEntry(
          member: member,
          moves: [
            for (final moveId in member.moveIds)
              if (moves[moveId] != null) moves[moveId]!,
          ],
          ability: member.abilityId == null
              ? abilitiesBySlug[member.abilitySlug]
              : abilities[member.abilityId],
          heldItemName: member.heldItemId == null
              ? null
              : items[member.heldItemId]?['nameZh'] as String?,
          evolutions: node?.children ?? const [],
        ),
      );
    }
    return result;
  }

  EvolutionNode? _findEvolutionNode(EvolutionNode? node, int id) {
    if (node == null) return null;
    if (node.id == id) return node;
    for (final child in node.children) {
      final found = _findEvolutionNode(child, id);
      if (found != null) return found;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('队伍与进化', style: SecondaryTypography.onCard.h15),
          const SizedBox(height: 4),
          Text(
            '存档可读取的特性与招式会自动带入；手动队伍可在上方点成员补充。',
            style: SecondaryTypography.onCard.small12.copyWith(
              color: TitoColors.mutedInk,
            ),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<_TeamAssistEntry>>(
            future: _future,
            builder: (context, snapshot) {
              final entries = snapshot.data;
              if (entries == null) {
                return const LinearProgressIndicator();
              }
              if (entries.isEmpty) return const Text('添加队伍成员后可查看辅助信息');
              return Column(
                children: [
                  for (final entry in entries)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 10),
                      title: Text(
                        entry.member.nickname ?? entry.member.species,
                        style: SecondaryTypography.onCard.body14.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        entry.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      children: [
                        if (entry.saveFacts.isNotEmpty) ...[
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final fact in entry.saveFacts)
                                Chip(label: Text(fact)),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (entry.moves.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (
                                var index = 0;
                                index < entry.moves.length;
                                index++
                              )
                                ActionChip(
                                  label: Text(entry.moveLabel(index)),
                                  onPressed: () => showMoveDetailSheet(
                                    context,
                                    entry.moves[index],
                                  ),
                                ),
                            ],
                          ),
                        if (entry.evolutions.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final evolution in entry.evolutions)
                                ActionChip(
                                  avatar: const Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    evolution.triggerZh == null
                                        ? evolution.nameZh
                                        : '${evolution.nameZh} · ${evolution.triggerZh}',
                                  ),
                                  onPressed: () =>
                                      context.push('/dex/${evolution.id}'),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: entry.member.speciesId == null
                                ? null
                                : () {
                                    battlePartyHandoff.set(
                                      entry.member,
                                      selectedMoveId:
                                          entry.preferredDamageMove?.id,
                                    );
                                    context.push(
                                      '/search/companion/quick-damage',
                                    );
                                  },
                            icon: const Icon(Icons.calculate_rounded, size: 18),
                            label: const Text('带入伤害速算'),
                          ),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TeamAssistEntry {
  const _TeamAssistEntry({
    required this.member,
    required this.moves,
    required this.ability,
    required this.heldItemName,
    required this.evolutions,
  });

  final PartyMember member;
  final List<CachedMove> moves;
  final CachedAbility? ability;
  final String? heldItemName;
  final List<EvolutionNode> evolutions;

  CachedMove? get preferredDamageMove {
    for (final move in moves) {
      if (move.category != 'status' && (move.power ?? 0) > 0) return move;
    }
    return null;
  }

  String moveLabel(int index) {
    final move = moves[index];
    if (index >= member.movePp.length) return move.nameZh;
    final ppUp = index < member.movePpUps.length ? member.movePpUps[index] : 0;
    return '${move.nameZh} · PP ${member.movePp[index]}'
        '${ppUp > 0 ? ' · 增强 $ppUp' : ''}';
  }

  List<String> get saveFacts {
    final stats = member.battleStats;
    return [
      if (member.nature != null) '${member.nature}性格',
      if (member.gender != null) member.gender!,
      if (member.isShiny) '闪光',
      if (member.isEgg) '蛋',
      if (member.formIndex != 0) '形态索引 ${member.formIndex}',
      if (member.status != null) member.status!,
      if (member.currentHp != null && member.maxHp != null)
        'HP ${member.currentHp}/${member.maxHp}',
      if (member.experience != null) '经验 ${member.experience}',
      if (member.friendship != null) '亲密度 ${member.friendship}',
      if (member.heldItemId != null)
        '携带 ${heldItemName ?? '道具 #${member.heldItemId}'}',
      if (stats.isNotEmpty)
        '能力 ${stats.entries.map((entry) => '${entry.key}${entry.value}').join(' / ')}',
      if (member.ivs.length == 6) 'IV（HP/攻/防/速/特攻/特防）${member.ivs.join('/')}',
      if (member.evs.length == 6) 'EV（HP/攻/防/速/特攻/特防）${member.evs.join('/')}',
    ];
  }

  String get subtitle {
    final parts = [
      if (ability != null) '特性：${ability!.nameZh}',
      if (member.nature != null) '性格：${member.nature}',
      if (member.heldItemId != null)
        '携带：${heldItemName ?? '#${member.heldItemId}'}',
      if (moves.isNotEmpty) '招式 ${moves.length}/4',
      if (evolutions.isNotEmpty)
        '可进化：${evolutions.map((entry) => entry.nameZh).join(' / ')}',
    ];
    return parts.isEmpty ? '点击成员可补充招式与特性' : parts.join(' · ');
  }
}

String _moveCategoryLabelZh(String category) => switch (category) {
  'physical' => '物理',
  'special' => '特殊',
  'status' => '变化',
  _ => category,
};

/// Sticker action button for the inline editor (small solid drop shadow,
/// sinks on press like every other sticker).
class _EditorActionButton extends StatelessWidget {
  const _EditorActionButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.radius,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final BorderRadius radius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StickerPressable(
      borderRadius: radius,
      child: Material(
        color: background,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: TitoColors.ink,
                width: TitoBorders.element,
              ),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SecondaryTypography.onCard.small12.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
