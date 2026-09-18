import '../features/dex/battle_effectiveness.dart';
import 'package:flutter/material.dart';
import '../features/companion/battle_math.dart';
import '../features/companion/battle_session.dart';
import '../features/dex/ability_type_modifiers.dart';
import '../features/dex/dex_models.dart';
import '../features/dex/dex_repository.dart';
import '../features/game/game_edition_repository.dart';
import '../l10n/app_locale.dart';
import '../l10n/app_zh.dart';
import '../l10n/localized_names.dart';
import '../models/journey.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_surface_tokens.dart';
import 'battle_move_picker.dart';
import 'battle_party_picker.dart';
import 'companion_tool_fields.dart';
import 'tito_sprite_sticker.dart';

/// A compact calculation roster; editing never changes the saved journey.
class BattleTeamEditor extends StatelessWidget {
  const BattleTeamEditor({
    super.key,
    required this.session,
    required this.party,
  });
  final BattleSession session;
  final List<PartyMember> party;

  Future<void> _edit(BuildContext context, BattlePartyEntry? entry) async {
    final draft =
        entry ??
        BattlePartyEntry(
          const PartyMember(species: ''),
          BattleCombatant(level: 50),
          {},
        );
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TitoSurfaceTokens.of(context).cardFill,
      builder: (context) => _TeamMemberEditor(
        entry: draft,
        session: session,
        party: party,
        isNew: entry == null,
      ),
    );
    if (entry == null) {
      if (accepted == true && draft.combatant.pokemonId != null) {
        await session.addTeamMember(party, draft);
      } else {
        draft.combatant.dispose();
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => FutureBuilder<List<BattlePartyEntry>>(
      future: session.partyEntries(party),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final entries = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppLocale.pick(
                zh: '点选成员可替换、改数值和招式，仅用于本次计算',
                en: 'Tap a member to edit this calculation team',
              ),
              style: SecondaryTypography.onGradient.small12,
            ),
            const SizedBox(height: 6),
            for (var row = 0; row < 2; row++) ...[
              if (row > 0) const SizedBox(height: 6),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var col = 0; col < 3; col++) ...[
                      if (col > 0) const SizedBox(width: 6),
                      Expanded(
                        child: _tile(
                          context,
                          row * 3 + col < entries.length
                              ? entries[row * 3 + col]
                              : null,
                          row * 3 + col,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    ),
  );

  Widget _tile(BuildContext context, BattlePartyEntry? entry, int index) {
    final draft = entry?.combatant;
    final ability = draft?.abilities
        .where((a) => abilitySlugFromNameEn(a.nameEn) == draft.abilitySlug)
        .firstOrNull;
    final small = SecondaryTypography.onCard.small12.copyWith(height: 1.25);
    return Semantics(
      button: true,
      label: entry?.name ?? AppLocale.pick(zh: '添加成员', en: 'Add member'),
      child: InkWell(
        key: ValueKey('battle-team-slot-$index'),
        borderRadius: BorderRadius.circular(TitoRadii.md),
        onTap: () => _edit(context, entry),
        child: Container(
          decoration: TitoSurfaceTokens.of(context)
              .surface(TitoSurfaceRole.fact)
              .decoration()
              .copyWith(borderRadius: BorderRadius.circular(TitoRadii.md)),
          padding: const EdgeInsets.all(6),
          child: entry == null
              ? ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 90),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add_rounded,
                          size: 24,
                          color: TitoColors.deepBlue,
                        ),
                        Text(
                          AppLocale.pick(zh: '添加', en: 'Add'),
                          style: small,
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        TitoSpriteSticker(
                          source: draft!.detail?.summary.displaySpritePath,
                          size: 30,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            entry.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: small.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Lv.${draft.level.text} · ${draft.nature.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: small,
                    ),
                    Text(
                      ability?.displayName ??
                          AppLocale.pick(zh: '特性：未选', en: 'Ability: none'),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: small,
                    ),
                    Text(
                      'IV ${draft.iv.values.map((c) => c.text).toSet().length == 1 ? draft.iv.values.first.text : AppLocale.pick(zh: '自定', en: 'custom')} · EV ${draft.ev.values.fold<int>(0, (n, c) => n + (int.tryParse(c.text) ?? 0))}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: small,
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      entry.moves.isEmpty
                          ? AppLocale.pick(
                              zh: '点击选择招式',
                              en: 'Tap to choose moves',
                            )
                          : entry.moves.values
                                .map((m) => m?.displayName ?? '—')
                                .join(' / '),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: small,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TeamMemberEditor extends StatefulWidget {
  const _TeamMemberEditor({
    required this.entry,
    required this.session,
    required this.party,
    required this.isNew,
  });
  final BattlePartyEntry entry;
  final BattleSession session;
  final List<PartyMember> party;
  final bool isNew;
  @override
  State<_TeamMemberEditor> createState() => _TeamMemberEditorState();
}

class _TeamMemberEditorState extends State<_TeamMemberEditor> {
  BattleCombatant get draft => widget.entry.combatant;
  List<PokemonSummary> suggestions = [];
  final query = TextEditingController();
  int revision = 0;
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  void change(VoidCallback fn) {
    setState(fn);
    draft.refreshStats();
    widget.session.teamChanged();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: ListenableBuilder(
          listenable: draft,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.isNew
                          ? AppLocale.pick(zh: '添加计算成员', en: 'Add team member')
                          : widget.entry.name,
                      style: SecondaryTypography.onCard.h15,
                    ),
                  ),
                  TextButton(
                    onPressed: draft.pokemonId == null || draft.loading
                        ? null
                        : () => Navigator.pop(context, true),
                    child: Text(AppLocale.pick(zh: '完成', en: 'Done')),
                  ),
                ],
              ),
              PokemonSearchField(
                compact: true,
                controller: query,
                hintText: AppLocale.pick(
                  zh: '搜索 / 替换宝可梦',
                  en: 'Search / replace Pokémon',
                ),
                suggestions: suggestions,
                onQueryChanged: (value) async {
                  final request = ++revision;
                  final found = value.trim().isEmpty
                      ? <PokemonSummary>[]
                      : await dexRepository.search(value.trim());
                  if (mounted && request == revision) {
                    setState(() => suggestions = found.take(6).toList());
                  }
                },
                onPokemonSelected: (pokemon) async {
                  revision++;
                  setState(() => suggestions = []);
                  await draft.selectPokemon(pokemon);
                  if (!mounted || draft.selectionFailed) return;
                  change(() {
                    widget.entry.moves.clear();
                    query.clear();
                  });
                },
              ),
              BattleDraftNotice(combatant: draft),
              if (draft.pokemonId != null) ...[
                const SizedBox(height: 8),
                CompanionNumberField(
                  label: AppZh.companionStatLevel,
                  controller: draft.level,
                  max: 100,
                  min: 1,
                  inline: true,
                ),
                const SizedBox(height: 8),
                NaturePicker(
                  selected: draft.nature,
                  onChanged: (v) => change(() => draft.nature = v),
                ),
                const SizedBox(height: 8),
                CompanionAbilitySection(
                  compact: true,
                  pokemonLabel: AppZh.battleAbility,
                  manualLabel: AppZh.battleAbility,
                  manualOptions: kManualAttackerAbilityOptions,
                  pokemonOptions: defensiveAbilityOptionsFrom(draft.abilities),
                  linkedPokemonId: draft.pokemonId,
                  selectedSlug: draft.abilitySlug,
                  onChanged: (v) => change(() => draft.abilitySlug = v),
                ),
                const SizedBox(height: 8),
                for (final stat in BattleStat.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 44,
                          child: Text(
                            stat.label,
                            style: SecondaryTypography.onCard.small12,
                          ),
                        ),
                        Expanded(
                          child: CompanionNumberField(
                            label: AppZh.companionStatBase,
                            controller: draft.base[stat]!,
                            max: 255,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: CompanionNumberField(
                            label: 'IV',
                            controller: draft.iv[stat]!,
                            max: 31,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: CompanionNumberField(
                            label: 'EV',
                            controller: draft.ev[stat]!,
                            max: 252,
                          ),
                        ),
                      ],
                    ),
                  ),
                HeldItemPicker(
                  compact: true,
                  selected: draft.heldItem,
                  onChanged: (v) => change(() {
                    draft.heldItem = v;
                    draft.unsupportedItem = false;
                  }),
                  typeBoostItemType: draft.typeBoostItemType,
                  onTypeBoostChanged: (v) =>
                      change(() => draft.typeBoostItemType = v),
                ),
                const SizedBox(height: 8),
                StatusConditionPicker(
                  compact: true,
                  selected: draft.status,
                  onChanged: (v) => change(() => draft.status = v),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocale.pick(zh: '招式（最多四个）', en: 'Moves (up to four)'),
                  style: SecondaryTypography.onCard.h15,
                ),
                for (final move in widget.entry.moves.entries.toList())
                  Row(
                    children: [
                      Expanded(
                        child: BattleMovePicker(
                          detail: draft.detail,
                          versionGroup:
                              gameEditionRepository.edition.dataVersionGroupKey,
                          value: move.value,
                          excluded: widget.entry.moves.keys.toSet(),
                          onChanged: (v) => change(() {
                            widget.entry.moves.remove(move.key);
                            if (v != null) widget.entry.moves[v.id] = v;
                          }),
                        ),
                      ),
                      IconButton(
                        tooltip: AppLocale.pick(zh: '移除招式', en: 'Remove move'),
                        onPressed: () =>
                            change(() => widget.entry.moves.remove(move.key)),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                if (widget.entry.moves.length < 4)
                  BattleMovePicker(
                    detail: draft.detail,
                    versionGroup:
                        gameEditionRepository.edition.dataVersionGroupKey,
                    excluded: widget.entry.moves.keys.toSet(),
                    onChanged: (v) => change(() {
                      if (v != null) widget.entry.moves[v.id] = v;
                    }),
                  ),
                if (!widget.isNew)
                  TextButton(
                    onPressed: () async {
                      await widget.session.removeTeamMember(
                        widget.party,
                        widget.entry,
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Text(
                      AppLocale.pick(
                        zh: '移出计算队伍',
                        en: 'Remove from calculation team',
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
