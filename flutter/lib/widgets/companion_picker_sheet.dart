import 'package:flutter/material.dart';

import '../features/companion/companion_repository.dart';
import '../features/dex/dex_models.dart';
import '../features/dex/dex_repository.dart';
import '../l10n/app_zh.dart';
import '../navigation/tito_page_transition.dart';
import '../theme/device_layout.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import 'dex_sprite_image.dart';

/// Pick the standby companion from the full national dex. The selection is
/// saved to [companionRepository]; only its animated sprite is fetched later,
/// on demand.
Future<CompanionChoice?> showCompanionPickerSheet(BuildContext context) {
  return showTitoModalBottomSheet<CompanionChoice>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _CompanionPickerSheet(),
  );
}

class _CompanionPickerSheet extends StatefulWidget {
  const _CompanionPickerSheet();

  @override
  State<_CompanionPickerSheet> createState() => _CompanionPickerSheetState();
}

class _CompanionPickerSheetState extends State<_CompanionPickerSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<PokemonSummary> _filtered(List<PokemonSummary> all) {
    final query = _query.trim();
    if (query.isEmpty) {
      return all;
    }
    final lower = query.toLowerCase();
    final numeric = int.tryParse(query);
    return [
      for (final entry in all)
        if ((numeric != null && entry.id == numeric) ||
            entry.nameZh.contains(query) ||
            entry.nameEn.toLowerCase().contains(lower))
          entry,
    ];
  }

  Future<void> _select(PokemonSummary summary) async {
    final choice = CompanionChoice(
      pokemonId: summary.id,
      nameZh: summary.nameZh,
    );
    await companionRepository.save(choice);
    if (mounted) {
      Navigator.of(context).pop(choice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.72;

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppZh.companionPickerTitle,
              style: SecondaryTypography.onCard.h15,
            ),
            const SizedBox(height: 4),
            Text(
              AppZh.companionPickerHint,
              style: SecondaryTypography.onCard.small12.copyWith(
                color: TitoColors.mutedInk,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              onChanged: (value) => setState(() => _query = value),
              spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
              decoration: InputDecoration(
                hintText: AppZh.companionPickerSearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(TitoRadii.md),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<List<PokemonSummary>>(
                future: dexRepository.getAllSummaries(),
                builder: (context, snapshot) {
                  final all = snapshot.data;
                  if (all == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final entries = _filtered(all);
                  if (entries.isEmpty) {
                    return Center(
                      child: Text(
                        AppZh.searchNoResults,
                        style: SecondaryTypography.onCard.body14,
                      ),
                    );
                  }
                  return GridView.builder(
                    itemCount: entries.length,
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: DeviceLayout.isCompact(context)
                          ? 84
                          : 96,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.8,
                    ),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _CompanionPickTile(
                        summary: entry,
                        onTap: () => _select(entry),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanionPickTile extends StatelessWidget {
  const _CompanionPickTile({required this.summary, required this.onTap});

  final PokemonSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TitoColors.cream,
      borderRadius: BorderRadius.circular(TitoRadii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TitoRadii.md),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TitoRadii.md),
            border: Border.all(
              color: TitoColors.ink.withValues(alpha: 0.35),
              width: 2,
            ),
          ),
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: DexSpriteImage(
                  source: summary.displaySpritePath,
                  height: null,
                  width: null,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                summary.nameZh,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: SecondaryTypography.onCard.small12.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
