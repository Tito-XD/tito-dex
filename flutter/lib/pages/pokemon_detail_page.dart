import 'package:flutter/material.dart';

import '../features/dex/dex_game_scope.dart';
import '../features/dex/dex_models.dart';
import '../features/dex/dex_repository.dart';
import '../theme/device_layout.dart';
import '../l10n/app_zh.dart';
import '../theme/tito_colors.dart';
import '../widgets/app_header.dart';
import '../widgets/pokemon_card.dart';
import '../widgets/pokemon_detail_sections.dart';
import '../widgets/sticker_card.dart';

class PokemonDetailPage extends StatefulWidget {
  const PokemonDetailPage({super.key, required this.pokemonId});

  final int pokemonId;

  @override
  State<PokemonDetailPage> createState() => _PokemonDetailPageState();
}

class _PokemonDetailPageState extends State<PokemonDetailPage>
    with SingleTickerProviderStateMixin {
  late Future<PokemonDetail> _detailFuture;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _detailFuture = dexRepository.getDetail(widget.pokemonId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

        return Column(
          children: [
            Padding(
              padding: DeviceLayout.pagePadding(context).copyWith(bottom: 0),
              child: Column(
                children: [
                  if (!DeviceLayout.isCompact(context))
                    const AppHeader(showSettings: true),
                  PokemonDetailHeader(detail: detail),
                  const SizedBox(height: 4),
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: TitoColors.coral,
                    unselectedLabelColor: TitoColors.card,
                    indicatorColor: TitoColors.coral,
                    dividerColor: Colors.transparent,
                    labelStyle: TextStyle(
                      fontSize: DeviceLayout.useSquareDashboard(context)
                          ? 11
                          : (DeviceLayout.isCompact(context) ? 12 : 14),
                      fontWeight: FontWeight.w800,
                    ),
                    tabs: const [
                      Tab(text: AppZh.dexTabIntro),
                      Tab(text: AppZh.dexTabBasic),
                      Tab(text: AppZh.dexTabObtain),
                      Tab(text: AppZh.dexTabMoves),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _IntroTab(detail: detail),
                  _BasicTab(detail: detail),
                  _ObtainTab(detail: detail),
                  _MovesTab(detail: detail),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _IntroTab extends StatelessWidget {
  const _IntroTab({required this.detail});

  final PokemonDetail detail;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: DeviceLayout.pagePadding(context),
      children: [
        FlavorTextCarousel(entries: detail.flavorEntries),
        const SizedBox(height: 12),
        IntroMetaCard(detail: detail),
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
  }
}

class _BasicTab extends StatelessWidget {
  const _BasicTab({required this.detail});

  final PokemonDetail detail;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: DeviceLayout.pagePadding(context),
      children: [
        if (detail.baseStats != null) ...[
          BaseStatsCard(stats: detail.baseStats!),
          const SizedBox(height: 12),
        ],
        if (detail.typeMultipliers.isNotEmpty)
          TypeEffectivenessGrid(multipliers: detail.typeMultipliers),
        const SizedBox(height: 12),
        StickerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppZh.dexStabEffective,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TypeChipRow(
                types: detail.stabSuperEffective,
                tone: TypeChipTone.neutral,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ObtainTab extends StatelessWidget {
  const _ObtainTab({required this.detail});

  final PokemonDetail detail;

  @override
  Widget build(BuildContext context) {
    if (detail.evolutionChain == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StickerCard(
            child: Text(
              AppZh.dexNoEvolution,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: DeviceLayout.pagePadding(context),
      children: [
        StickerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppZh.dexEvolution,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 12),
              EvolutionChainView(
                root: detail.evolutionChain!,
                highlightId: detail.summary.id,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MovesTab extends StatelessWidget {
  const _MovesTab({required this.detail});

  final PokemonDetail detail;

  @override
  Widget build(BuildContext context) {
    final moveSet = detail.moveSet;

    return ListView(
      padding: DeviceLayout.pagePadding(context),
      children: [
        Text(
          AppZh.dexMovesHgssScope,
          style: const TextStyle(
            color: TitoColors.card,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        MoveCategoryPanel(
          title: moveMethodLabelZh('level-up'),
          moves: moveSet.levelUp,
          showLevel: true,
        ),
        const SizedBox(height: 12),
        MoveCategoryPanel(
          title: moveMethodLabelZh('machine'),
          moves: moveSet.machine,
        ),
        const SizedBox(height: 12),
        MoveCategoryPanel(
          title: moveMethodLabelZh('egg'),
          moves: moveSet.egg,
        ),
      ],
    );
  }
}
