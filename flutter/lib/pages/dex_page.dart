import 'package:flutter/material.dart';

import '../features/dex/dex_models.dart';
import '../features/dex/dex_repository.dart';
import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/tito_colors.dart';
import '../widgets/app_header.dart';
import '../widgets/pokemon_card.dart';
import '../widgets/sticker_card.dart';

class DexPage extends StatefulWidget {
  const DexPage({super.key, required this.journey});

  final CurrentJourney journey;

  @override
  State<DexPage> createState() => _DexPageState();
}

class _DexPageState extends State<DexPage> {
  static const _chunkSize = 40;

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
      setState(() => _error = error.toString());
    }
  }

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
        _error = error.toString();
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
    final visible = _visibleEntries;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 240 &&
            !_showJourneyOnly) {
          _loadMore();
        }
        return false;
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AppHeader(showSettings: true),
          Text(
            '${AppZh.navDex} · ${localizeGame(widget.journey.game)} ($caughtCount/$hgssMaxNationalDexId)',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: TitoColors.card,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            AppZh.dexScopeNote,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: TitoColors.card,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text(AppZh.dexTabNational)),
              ButtonSegment(value: true, label: Text(AppZh.dexTabJourney)),
            ],
            selected: {_showJourneyOnly},
            onSelectionChanged: (selection) {
              setState(() => _showJourneyOnly = selection.first);
            },
          ),
          const SizedBox(height: 16),
          if (_error != null)
            StickerCard(
              child: Text(
                _error!,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          else if (visible.isEmpty && _loadingChunk)
            const Center(child: CircularProgressIndicator())
          else if (visible.isEmpty)
            StickerCard(
              child: Text(
                AppZh.dexJourneyEmpty,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final entry = visible[index];
                final status = dexRepository.statusFor(entry.id, _caughtIds);
                return PokemonMiniCard(
                  summary: entry,
                  status: status,
                );
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
                AppZh.dexLoadingProgress(_loadedThrough, hgssMaxNationalDexId),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: TitoColors.card,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
