import 'package:flutter/material.dart';

import '../features/dex/dex_game_scope.dart';
import '../features/dex/dex_models.dart';
import '../features/dex/dex_repository.dart';
import '../l10n/app_zh.dart';
import '../navigation/back_navigation.dart';
import '../navigation/tito_page_transition.dart';
import '../theme/device_layout.dart';
import '../theme/tito_colors.dart';
import '../theme/error_text.dart';
import '../theme/tito_typography.dart';
import '../widgets/dex_sprite_image.dart';
import '../widgets/pokemon_card.dart';
import '../widgets/pokemon_detail_sections.dart';
import '../widgets/sticker_card.dart';
import '../widgets/tito_skeleton.dart';
import '../widgets/tito_skeleton_gate.dart';

class PokemonDetailPage extends StatefulWidget {
  const PokemonDetailPage({super.key, required this.pokemonId});

  final int pokemonId;

  @override
  State<PokemonDetailPage> createState() => _PokemonDetailPageState();
}

class _PokemonDetailPageState extends State<PokemonDetailPage> {
  PokemonDetail? _detail;
  (String, String)? _errorCopy;
  bool _loading = true;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _errorCopy = null;
    });
    try {
      final detail = await dexRepository.getDetail(widget.pokemonId);
      if (!mounted) {
        return;
      }
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorCopy = splitUserFacingError(error);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final errorCopy = _errorCopy;
    final contentReady = !_loading && detail != null && errorCopy == null;

    return Column(
      children: [
        Padding(
          padding: DeviceLayout.pagePadding(context).copyWith(bottom: 0),
          child: Column(
            children: [
              _DexBackBar(path: '/dex/${widget.pokemonId}'),
              const SizedBox(height: 8),
              TitoSkeletonGate(
                loading: _loading,
                skeleton: const TitoDetailHeaderSkeleton(),
                child: detail != null
                    ? _CompactPokemonHeader(detail: detail)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        Expanded(
          child: TitoSkeletonGate(
            loading: _loading,
            skeleton: ListView(
              padding: DeviceLayout.pagePadding(context),
              children: const [
                TitoCardSkeleton(height: 140),
                SizedBox(height: 12),
                TitoCardSkeleton(height: 88),
              ],
            ),
            child: errorCopy != null
                ? _ErrorBody(
                    copy: errorCopy,
                    onRetry: _loadDetail,
                  )
                : contentReady
                    ? AnimatedSwitcher(
                        duration: TitoMotion.tabFadeDuration,
                        switchInCurve: TitoMotion.standardCurve,
                        switchOutCurve: TitoMotion.standardCurve,
                        layoutBuilder: (currentChild, previousChildren) {
                          return Stack(
                            alignment: Alignment.topCenter,
                            children: [
                              ...previousChildren,
                              if (currentChild != null) currentChild,
                            ],
                          );
                        },
                        child: KeyedSubtree(
                          key: ValueKey(
                            'tab-$_currentTabIndex-${detail!.summary.id}',
                          ),
                          child: _DetailTabBody(
                            detail: detail,
                            tabIndex: _currentTabIndex,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
          ),
        ),
        _DetailBottomTabs(
          currentIndex: _currentTabIndex,
          onSelected: (index) {
            if (_currentTabIndex != index) {
              setState(() => _currentTabIndex = index);
            }
          },
        ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.copy, required this.onRetry});

  final (String, String) copy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: DeviceLayout.pagePadding(context),
      children: [
        StickerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(copy.$1, style: context.tito.cardBodyEmphasis),
              const SizedBox(height: 8),
              Text(copy.$2, style: context.tito.errorDetail),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onRetry,
                child: const Text(AppZh.dexRetry),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailTabBody extends StatelessWidget {
  const _DetailTabBody({
    required this.detail,
    required this.tabIndex,
  });

  final PokemonDetail detail;
  final int tabIndex;

  @override
  Widget build(BuildContext context) {
    return switch (tabIndex) {
      0 => _IntroTab(detail: detail),
      1 => _BasicTab(detail: detail),
      2 => _ObtainTab(detail: detail),
      _ => _MovesTab(detail: detail),
    };
  }
}

class _DexBackBar extends StatelessWidget {
  const _DexBackBar({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () => TitoBackNavigation.navigateBack(context, path),
        style: TextButton.styleFrom(
          foregroundColor: TitoColors.card,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          visualDensity: VisualDensity.compact,
        ),
        child: Text(
          '← 图鉴',
          style: context.tito.cardBodyStrong.copyWith(color: TitoColors.card),
        ),
      ),
    );
  }
}

class _CompactPokemonHeader extends StatelessWidget {
  const _CompactPokemonHeader({required this.detail});

  final PokemonDetail detail;

  @override
  Widget build(BuildContext context) {
    final summary = detail.summary;
    final square = DeviceLayout.useSquareDashboard(context);
    final compactTitle = '${summary.nameZh} · ${detail.nationalDexLabel}';

    return StickerCard(
      variant: StickerVariant.deep,
      padding: EdgeInsets.symmetric(
        horizontal: square ? 10 : 12,
        vertical: square ? 8 : 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              compactTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.tito.onDeepHeading.copyWith(
                fontSize: square ? 13 : 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          DexSpriteImage(
            source: summary.displaySpritePath,
            width: square ? 50 : 58,
            height: square ? 50 : 58,
          ),
        ],
      ),
    );
  }
}

class _DetailBottomTabs extends StatelessWidget {
  const _DetailBottomTabs({
    required this.currentIndex,
    required this.onSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  static const _tabs = [
    AppZh.dexTabIntro,
    '基本',
    AppZh.dexTabObtain,
    AppZh.dexTabMoves,
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: TitoColors.deepBlue,
            borderRadius: BorderRadius.circular(TitoRadii.md),
            border: Border.all(color: TitoColors.ink, width: 2),
          ),
          child: Row(
            children: List.generate(_tabs.length, (index) {
              final selected = index == currentIndex;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Material(
                    color: selected
                        ? TitoColors.softYellow
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(TitoRadii.sm),
                    child: InkWell(
                      onTap: () => onSelected(index),
                      borderRadius: BorderRadius.circular(TitoRadii.sm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          _tabs[index],
                          textAlign: TextAlign.center,
                          style: context.tito.chip.copyWith(
                            color: selected
                                ? TitoColors.deepBlue
                                : TitoColors.card,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
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
            style: context.tito.cardMuted.copyWith(height: 1.4),
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
                style: context.tito.cardSectionTitle,
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
        padding: DeviceLayout.pagePadding(context),
        children: [
          StickerCard(
            child: Text(
              AppZh.dexNoEvolution,
              style: context.tito.cardBodyStrong,
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
              Text(AppZh.dexEvolution, style: context.tito.cardSectionTitle),
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
        Text(AppZh.dexMovesHgssScope, style: context.tito.pageNoteOnGradient),
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
        MoveCategoryPanel(title: moveMethodLabelZh('egg'), moves: moveSet.egg),
      ],
    );
  }
}
