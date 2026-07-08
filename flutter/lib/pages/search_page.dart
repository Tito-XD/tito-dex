import 'package:flutter/material.dart';

import '../features/dex/dex_mock_data.dart';
import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/tito_colors.dart';
import '../widgets/app_header.dart';
import '../widgets/sticker_card.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.journey});

  final CurrentJourney journey;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<DexEntry> get _results {
    final query = _controller.text.trim().toLowerCase();
    if (query.isEmpty) {
      return const [];
    }
    return dexMockData
        .where(
          (entry) =>
              entry.name.toLowerCase().contains(query) ||
              entry.type.toLowerCase().contains(query) ||
              entry.id.toString().contains(query) ||
              localizeSpecies(entry.name).toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AppHeader(showSettings: true),
        Text(
          '${AppZh.navSearch} · ${localizeGame(widget.journey.game)}',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: TitoColors.card,
              ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          onChanged: (_) => setState(() {}),
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
              borderSide: const BorderSide(color: TitoColors.softYellow, width: 3),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_controller.text.isEmpty)
          StickerCard(
            child: Text(
              AppZh.searchEmptyHint,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          )
        else if (results.isEmpty)
          StickerCard(
            child: Text(
              AppZh.searchNoResults,
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
              childAspectRatio: 0.9,
            ),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final entry = results[index];
              return StickerCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '#${entry.id.toString().padLeft(3, '0')}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: TitoColors.mutedInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      localizeSpecies(entry.name),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      entry.type,
                      style: const TextStyle(
                        fontSize: 11,
                        color: TitoColors.mutedInk,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
