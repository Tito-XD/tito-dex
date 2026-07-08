import 'dart:async';

import 'package:flutter/material.dart';

import '../features/dex/dex_models.dart';
import '../features/dex/dex_repository.dart';
import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/device_layout.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
import '../widgets/app_header.dart';
import '../widgets/pokemon_card.dart';
import '../widgets/sticker_card.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.journey});

  final CurrentJourney journey;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _searching = false;
  String? _error;
  List<PokemonSummary> _results = const [];
  Set<int> _caughtIds = const {};

  @override
  void initState() {
    super.initState();
    _loadCaughtIds();
  }

  Future<void> _loadCaughtIds() async {
    final caught = await dexRepository.journeyCaughtIds(widget.journey);
    if (!mounted) {
      return;
    }
    setState(() => _caughtIds = caught);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _runSearch(value);
    });
  }

  Future<void> _runSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      final results = await dexRepository.search(trimmed);
      if (!mounted || _controller.text.trim() != trimmed) {
        return;
      }
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();

    return ListView(
      padding: DeviceLayout.pagePadding(context),
      children: [
        const AppHeader(showSettings: true),
        Text(
          '${AppZh.navSearch} · ${localizeGame(widget.journey.game)}',
          style: context.tito.pageTitleOnGradient,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          onChanged: _onQueryChanged,
          decoration: InputDecoration(
            hintText: AppZh.searchPlaceholder,
            filled: true,
            fillColor: TitoColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(TitoRadii.md),
              borderSide: const BorderSide(color: TitoColors.ink, width: 3),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(TitoRadii.md),
              borderSide: const BorderSide(color: TitoColors.ink, width: 3),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(TitoRadii.md),
              borderSide:
                  const BorderSide(color: TitoColors.softYellow, width: 3),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (query.isEmpty)
          StickerCard(
            child: Text(
              AppZh.searchEmptyHint,
              style: context.tito.cardBodyStrong,
            ),
          )
        else if (_searching)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          StickerCard(
            child: Text(
              _error!,
              style: context.tito.cardBodyStrong,
            ),
          )
        else if (_results.isEmpty)
          StickerCard(
            child: Text(
              AppZh.searchNoResults,
              style: context.tito.cardBodyStrong,
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: DeviceLayout.gridMaxExtent(context),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: DeviceLayout.isCompact(context) ? 0.72 : 0.78,
            ),
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final entry = _results[index];
              final status = dexRepository.statusFor(entry.id, _caughtIds);
              return PokemonMiniCard(
                summary: entry,
                status: status,
              );
            },
          ),
      ],
    );
  }
}
