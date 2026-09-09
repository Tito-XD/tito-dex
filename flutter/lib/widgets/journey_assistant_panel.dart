import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/journey/journey_assistant.dart';
import '../features/dex/dex_filter.dart';
import '../features/dex/version_availability.dart';
import '../l10n/app_zh.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import 'dex_sprite_image.dart';
import 'sticker_card.dart';
import 'tito_loading_panel.dart';
import 'tito_fact_grid.dart';

class JourneyAssistantPanel extends StatelessWidget {
  const JourneyAssistantPanel({super.key, required this.future});

  final Future<JourneyAssistantSnapshot> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<JourneyAssistantSnapshot>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState != ConnectionState.done) {
          return TitoLoadingPanel(
            message: AppZh.journeyAssistantLoading,
            compact: true,
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return StickerCard(child: Text(AppZh.journeyAssistantLoadFailed));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _NearbyCard(data: data),
            if (data.pairedVersionLabel != null) ...[
              const SizedBox(height: 12),
              _VersionCard(data: data),
            ],
            if (data.evolutionOrTradeMissing.isNotEmpty) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const Key('journey-remaining-dex'),
                  icon: const Icon(Icons.catching_pokemon_rounded, size: 18),
                  label: Text(
                    AppZh.journeyRemainingDex(
                      data.evolutionOrTradeMissingCount,
                    ),
                  ),
                  onPressed: () {
                    dexFilterController.setFilter(
                      DexFilter(
                        speciesIds: data.evolutionOrTradeMissing
                            .map((pokemon) => pokemon.id)
                            .toSet(),
                        speciesLabelZh: AppZh.journeyRemainingDex(
                          data.evolutionOrTradeMissingCount,
                        ),
                        labelZh: AppZh.journeyRemainingDex(
                          data.evolutionOrTradeMissingCount,
                        ),
                      ),
                    );
                    context.push('/dex');
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _NearbyCard extends StatelessWidget {
  const _NearbyCard({required this.data});

  final JourneyAssistantSnapshot data;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.near_me_rounded,
            title: AppZh.journeyAssistantNearbyTitle,
            trailing: data.locationMatched ? data.locationLabel : null,
          ),
          const SizedBox(height: 8),
          if (!data.locationMatched)
            Text(
              AppZh.journeyAssistantLocationUnknown,
              style: SecondaryTypography.onCard.body14,
            )
          else if (data.nearbyUncaught.isEmpty)
            Text(
              AppZh.journeyAssistantNearbyComplete,
              style: SecondaryTypography.onCard.body14,
            )
          else ...[
            Text(
              AppZh.journeyAssistantNearbyCount(data.nearbyUncaughtCount),
              style: SecondaryTypography.onCard.body14.copyWith(
                color: TitoColors.mutedInk,
              ),
            ),
            const SizedBox(height: 4),
            for (final pokemon in data.nearbyUncaught)
              _PokemonRow(pokemon: pokemon, exactVersion: data.exactVersion),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/dex/locations'),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: Text(AppZh.journeyAssistantLocationDex),
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionCard extends StatelessWidget {
  const _VersionCard({required this.data});

  final JourneyAssistantSnapshot data;

  @override
  Widget build(BuildContext context) {
    final exact = data.exactVersionLabel;
    final paired = data.pairedVersionLabel;
    return StickerCard(
      variant: StickerVariant.softYellow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.route_outlined,
            title: AppZh.journeyAssistantVersionTitle,
          ),
          const SizedBox(height: 8),
          if (exact == null)
            Text(
              AppZh.journeyAssistantPickVersion,
              style: SecondaryTypography.onCard.body14,
            )
          else ...[
            if (paired != null)
              Text(
                AppZh.journeyAssistantEncounterGap(
                  exact,
                  paired,
                  data.versionEncounterGapCount,
                ),
                style: SecondaryTypography.onCard.body14,
              ),
            if (data.versionEncounterGaps.isNotEmpty) ...[
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) => TitoFactGrid(
                  columns: constraints.maxWidth < 320 ? 2 : 3,
                  children: [
                    for (final pokemon in data.versionEncounterGaps)
                      TitoFactTile(
                        title: pokemon.nameZh,
                        onTap: () => _openPokemon(
                          context,
                          pokemon.id,
                          formKey: pokemon.formKey,
                          exactVersion: pairedEncounterVersion(
                            data.exactVersion!,
                          ),
                        ),
                        child: Row(
                          children: [
                            DexSpriteImage(
                              source: pokemon.spritePath,
                              width: 28,
                              height: 28,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '#${pokemon.id.toString().padLeft(3, '0')}',
                                style: SecondaryTypography.onCard.small12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title, this.trailing});

  final IconData icon;
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 21, color: TitoColors.deepBlue),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: SecondaryTypography.onCard.h15)),
        if (trailing != null)
          Flexible(
            child: Text(
              trailing!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SecondaryTypography.onCard.small12.copyWith(
                color: TitoColors.mutedInk,
              ),
            ),
          ),
      ],
    );
  }
}

class _PokemonRow extends StatelessWidget {
  const _PokemonRow({required this.pokemon, required this.exactVersion});

  final JourneyAssistantPokemon pokemon;
  final String? exactVersion;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: DexSpriteImage(
          source: pokemon.spritePath,
          width: 38,
          height: 38,
        ),
        title: Text(
          pokemon.nameZh,
          style: SecondaryTypography.onCard.body14.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _openPokemon(
          context,
          pokemon.id,
          formKey: pokemon.formKey,
          exactVersion: exactVersion,
        ),
      ),
    );
  }
}

void _openPokemon(
  BuildContext context,
  int id, {
  String? formKey,
  String? exactVersion,
}) {
  context.push(
    Uri(
      path: '/dex/$id',
      queryParameters: {
        if (formKey != null) 'form': formKey,
        if (exactVersion != null) 'version': exactVersion,
      },
    ).toString(),
  );
}
