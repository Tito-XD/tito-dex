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
import '../widgets/companion_picker_sheet.dart';
import '../widgets/companion_tool_fields.dart';
import '../widgets/party_team_list.dart';
import '../widgets/retro_forms.dart';
import '../widgets/secondary_page_scaffold.dart';
import '../widgets/sticker_card.dart';
import '../widgets/sticker_pressable.dart';
import '../widgets/tito_sprite_sticker.dart';
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
  }) {
    final member = _party[index];
    final updated = List<PartyMember>.from(_party);
    updated[index] = member.copyWith(
      level: level,
      nickname: nickname.isEmpty ? null : nickname,
      types: types,
      abilitySlug: abilitySlug,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppZh.teamAddInvalidId)),
      );
    }
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
  List<PokemonAbility> _abilities = const [];
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
      if (!mounted) {
        return;
      }
      setState(() {
        if (_selectedTypes.isEmpty) {
          _selectedTypes = List<String>.from(summary.types);
        }
        _speciesLinked = true;
        _abilities = abilities;
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
            ),
          ),
        ],
      ),
    );
  }
}

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
