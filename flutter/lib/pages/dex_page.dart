import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/dex/dex_models.dart';
import '../features/dex/dex_repository.dart';
import '../theme/error_text.dart';
import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../navigation/back_navigation.dart';
import '../theme/device_layout.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
import '../widgets/pokemon_card.dart';
import '../widgets/sticker_card.dart';

class DexPage extends StatefulWidget {
  const DexPage({super.key, required this.journey});

  final CurrentJourney journey;

  @override
  State<DexPage> createState() => _DexPageState();
}

class _DexPageState extends State<DexPage> {
  static const _chunkSize = 12;

  int _loadedThrough = 0;
  bool _loadingChunk = false;
  bool _showJourneyOnly = false;
  List<PokemonSummary> _summaries = const [];
  Set<int> _caughtIds = const {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final caught = await dexRepository.journeyCaughtIds(widget.journey);
      if (!mounted) {
        return;
      }
      setState(() => _caughtIds = caught);
      await _loadMore();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = _formatDexError(error));
    }
  }

  String _formatDexError(Object error) => formatUserFacingError(error);

  Future<void> _loadMore() async {
    if (_loadingChunk || _loadedThrough >= hgssMaxNationalDexId) {
      return;
    }

    setState(() => _loadingChunk = true);
    try {
      final start = _loadedThrough + 1;
      final end = (_loadedThrough + _chunkSize).clamp(1, hgssMaxNationalDexId);
      final chunk = await dexRepository.getSummaryRange(start, end);
      if (!mounted) {
        return;
      }
      setState(() {
        _summaries = [..._summaries, ...chunk];
        _loadedThrough = end;
        _loadingChunk = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _formatDexError(error);
        _loadingChunk = false;
      });
    }
  }

  List<PokemonSummary> get _visibleEntries {
    if (!_showJourneyOnly) {
      return _summaries;
    }
    return _summaries.where((entry) => _caughtIds.contains(entry.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final caughtCount = _caughtIds.length;
    final seenCount = _loadedThrough > caughtCount
        ? _loadedThrough
        : caughtCount;
    final visible = _visibleEntries;
    final wideGrid = _useWideGrid(context);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 240 &&
            !_showJourneyOnly) {
          _loadMore();
        }
        return false;
      },
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: DeviceLayout.pagePadding(context).copyWith(bottom: 8),
              children: [
                const _DexBackBar(),
                const SizedBox(height: 8),
                Text(
                  '${AppZh.navDex} · ${localizeGame(widget.journey.game)}',
                  style: context.tito.pageTitleOnGradient,
                ),
                const SizedBox(height: 8),
                Text(
                  AppZh.dexScopeNote,
                  style: context.tito.pageSubtitleOnGradient,
                ),
                const SizedBox(height: 12),
                _DexStatsRow(seenCount: seenCount, caughtCount: caughtCount),
                const SizedBox(height: 12),
                if (_error != null)
                  StickerCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          AppZh.dexLoadFailed,
                          style: context.tito.cardBodyEmphasis,
                        ),
                        const SizedBox(height: 8),
                        Text(_error!, style: context.tito.errorDetail),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () {
                            setState(() => _error = null);
                            _loadMore();
                          },
                          child: const Text(AppZh.dexRetry),
                        ),
                      ],
                    ),
                  )
                else if (visible.isEmpty && _loadingChunk)
                  const Center(child: CircularProgressIndicator())
                else if (visible.isEmpty)
                  StickerCard(
                    child: Text(
                      AppZh.dexJourneyEmpty,
                      style: context.tito.cardBodyStrong,
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: wideGrid ? 3 : 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: DeviceLayout.isCompact(context)
                          ? 0.72
                          : 0.78,
                    ),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final entry = visible[index];
                      final status = dexRepository.statusFor(
                        entry.id,
                        _caughtIds,
                      );
                      return PokemonMiniCard(summary: entry, status: status);
                    },
                  ),
                if (_loadingChunk && visible.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
                if (!_showJourneyOnly && _loadedThrough < hgssMaxNationalDexId)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      AppZh.dexLoadingProgress(
                        _loadedThrough,
                        hgssMaxNationalDexId,
                      ),
                      textAlign: TextAlign.center,
                      style: context.tito.pageSubtitleOnGradient,
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: DeviceLayout.pagePadding(
                context,
              ).copyWith(top: 8, bottom: 8),
              child: StickerCard(
                variant: StickerVariant.deep,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilterChip(
                      label: Text(
                        AppZh.dexTabJourney,
                        style: context.tito.chip.copyWith(
                          color: _showJourneyOnly
                              ? TitoColors.deepBlue
                              : TitoColors.ink,
                        ),
                      ),
                      selected: _showJourneyOnly,
                      onSelected: (value) {
                        setState(() => _showJourneyOnly = value);
                      },
                      selectedColor: TitoColors.softYellow,
                      backgroundColor: TitoColors.card,
                      side: const BorderSide(color: TitoColors.ink, width: 2),
                      checkmarkColor: TitoColors.deepBlue,
                    ),
                    ActionChip(
                      onPressed: () => context.push('/search'),
                      avatar: const Icon(Icons.search_rounded, size: 18),
                      label: Text(AppZh.navSearch, style: context.tito.chip),
                      backgroundColor: TitoColors.card,
                      side: const BorderSide(color: TitoColors.ink, width: 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _useWideGrid(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width >= 680 || (size.width > size.height && size.width >= 520);
  }
}

class _DexBackBar extends StatelessWidget {
  const _DexBackBar();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () => TitoBackNavigation.navigateBack(context, '/dex'),
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

class _DexStatsRow extends StatelessWidget {
  const _DexStatsRow({required this.seenCount, required this.caughtCount});

  final int seenCount;
  final int caughtCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DexStatCard(
            label: AppZh.dexSeen,
            value: '$seenCount',
            variant: StickerVariant.sky,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DexStatCard(
            label: AppZh.dexCaught,
            value: '$caughtCount',
            variant: StickerVariant.mint,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DexStatCard(
            label: '全国',
            value: '$hgssMaxNationalDexId',
            variant: StickerVariant.cream,
          ),
        ),
      ],
    );
  }
}

class _DexStatCard extends StatelessWidget {
  const _DexStatCard({
    required this.label,
    required this.value,
    required this.variant,
  });

  final String label;
  final String value;
  final StickerVariant variant;

  @override
  Widget build(BuildContext context) {
    return StickerCard(
      variant: variant,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: context.tito.captionStrong,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: context.tito.cardValueLarge.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
