import 'package:flutter/material.dart';
import '../features/companion/battle_learnset.dart';
import '../features/dex/dex_models.dart';
import '../features/dex/type_chart.dart';
import '../l10n/app_locale.dart';
import '../l10n/localized_names.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_surface_tokens.dart';

class BattleMovePicker extends StatelessWidget {
  const BattleMovePicker({
    super.key,
    required this.detail,
    required this.versionGroup,
    required this.onChanged,
    this.value,
    this.excluded = const {},
    this.label,
  });
  final PokemonDetail? detail;
  final String versionGroup;
  final CachedMove? value;
  final Set<int> excluded;
  final String? label;
  final ValueChanged<CachedMove?> onChanged;

  @override
  Widget build(BuildContext context) {
    final moves = battleLearnset(detail, versionGroup);
    final valid = moves.any((m) => m.id == value?.id);
    return OutlinedButton(
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
      onPressed: detail == null
          ? null
          : () async {
              final picked = await showModalBottomSheet<CachedMove>(
                context: context,
                isScrollControlled: true,
                backgroundColor: TitoSurfaceTokens.of(context).cardFill,
                builder: (context) => _MoveSheet(
                  moves: moves
                      .where(
                        (m) => !excluded.contains(m.id) || m.id == value?.id,
                      )
                      .toList(),
                ),
              );
              if (picked != null && context.mounted) onChanged(picked);
            },
      child: Text(
        label ??
            (valid
                ? value!.displayName
                : detail == null
                ? AppLocale.pick(zh: '先选择宝可梦', en: 'Choose a Pokémon first')
                : AppLocale.pick(zh: '选择可学招式', en: 'Choose a learnable move')),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _MoveSheet extends StatefulWidget {
  const _MoveSheet({required this.moves});
  final List<CachedMove> moves;
  @override
  State<_MoveSheet> createState() => _MoveSheetState();
}

class _MoveSheetState extends State<_MoveSheet> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final moves = widget.moves
        .where(
          (m) => '${m.nameZh} ${m.nameEn}'.toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: Column(
            children: [
              Text(
                AppLocale.pick(zh: '当前游戏可学招式', en: 'Learnable in this game'),
                style: SecondaryTypography.onCard.h15,
              ),
              TextField(
                onChanged: (v) => setState(() => query = v),
                decoration: InputDecoration(
                  hintText: AppLocale.pick(zh: '搜索招式', en: 'Search moves'),
                ),
              ),
              Expanded(
                child: moves.isEmpty
                    ? Center(
                        child: Text(
                          AppLocale.pick(
                            zh: '没有当前游戏的可用招式资料',
                            en: 'No matching move data for this game',
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: moves.length,
                        itemBuilder: (context, i) {
                          final m = moves[i];
                          return ListTile(
                            title: Text(
                              m.displayName,
                              style: SecondaryTypography.onCard.body14,
                            ),
                            subtitle: Text(
                              '${typeNameZh(m.type)} · ${m.category == 'physical'
                                  ? AppLocale.pick(zh: '物理', en: 'Physical')
                                  : m.category == 'special'
                                  ? AppLocale.pick(zh: '特殊', en: 'Special')
                                  : AppLocale.pick(zh: '变化', en: 'Status')} · ${m.power ?? '—'}',
                              style: SecondaryTypography.onCard.small12,
                            ),
                            onTap: () => Navigator.pop(context, m),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
