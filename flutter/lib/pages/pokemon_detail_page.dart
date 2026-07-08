import 'package:flutter/material.dart';

import '../features/dex/dex_models.dart';
import '../features/dex/dex_repository.dart';
import '../features/dex/type_chart.dart';
import '../l10n/app_zh.dart';
import '../theme/tito_colors.dart';
import '../widgets/app_header.dart';
import '../widgets/pokemon_card.dart';
import '../widgets/sticker_card.dart';

class PokemonDetailPage extends StatefulWidget {
  const PokemonDetailPage({super.key, required this.pokemonId});

  final int pokemonId;

  @override
  State<PokemonDetailPage> createState() => _PokemonDetailPageState();
}

class _PokemonDetailPageState extends State<PokemonDetailPage> {
  late Future<PokemonDetail> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = dexRepository.getDetail(widget.pokemonId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PokemonDetail>(
      future: _detailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              AppHeader(showSettings: true),
              SizedBox(height: 24),
              Center(child: CircularProgressIndicator()),
              SizedBox(height: 12),
              Center(
                child: Text(
                  AppZh.dexLoadingDetail,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const AppHeader(showSettings: true),
              StickerCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppZh.dexLoadFailed,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(snapshot.error.toString()),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _detailFuture =
                              dexRepository.getDetail(widget.pokemonId);
                        });
                      },
                      child: const Text(AppZh.dexRetry),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        final detail = snapshot.data!;
        final summary = detail.summary;
        final heightM = detail.heightDm / 10;
        final weightKg = detail.weightHg / 10;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const AppHeader(showSettings: true),
            StickerCard(
              variant: StickerVariant.deep,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${summary.id.toString().padLeft(3, '0')}',
                          style: const TextStyle(
                            color: TitoColors.skyBlue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          summary.nameZh,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: TitoColors.card,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        if (detail.genusZh.isNotEmpty)
                          Text(
                            detail.genusZh,
                            style: const TextStyle(
                              color: TitoColors.skyBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const SizedBox(height: 8),
                        TypeChipRow(
                          types: summary.types.map(typeNameZh).toList(),
                        ),
                      ],
                    ),
                  ),
                  if (summary.spriteUrl != null)
                    Image.network(
                      summary.spriteUrl!,
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            StickerCard(
              child: Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: AppZh.dexHeight,
                      value: '${heightM.toStringAsFixed(1)} m',
                    ),
                  ),
                  Expanded(
                    child: _StatTile(
                      label: AppZh.dexWeight,
                      value: '${weightKg.toStringAsFixed(1)} kg',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: AppZh.dexWeaknesses,
              types: detail.weaknesses,
              tone: TypeChipTone.weak,
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: AppZh.dexResistances,
              types: detail.resistances,
              tone: TypeChipTone.resist,
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: AppZh.dexImmunities,
              types: detail.immunities,
              tone: TypeChipTone.immune,
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: AppZh.dexStabEffective,
              types: detail.stabSuperEffective,
              tone: TypeChipTone.neutral,
            ),
            if (detail.evolutionChain != null) ...[
              const SizedBox(height: 12),
              StickerCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppZh.dexEvolution,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    EvolutionChainView(
                      root: detail.evolutionChain!,
                      highlightId: summary.id,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            StickerCard(
              child: Text(
                AppZh.dexApiNote,
                style: const TextStyle(
                  color: TitoColors.mutedInk,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.types,
    required this.tone,
  });

  final String title;
  final List<String> types;
  final TypeChipTone tone;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 8),
          TypeChipRow(types: types, tone: tone),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: TitoColors.mutedInk,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ],
    );
  }
}
